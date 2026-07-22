#include "translation_xz_extract.h"

#include <CryptoArchitectureKit/crypto_digest.h>
#include <lzma.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cerrno>
#include <cctype>
#include <climits>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fcntl.h>
#include <memory>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

namespace {
constexpr uint64_t kMaxCompressedBytes = 152 * 1024 * 1024;
constexpr uint64_t kMaxOutputBytes = 208 * 1024 * 1024;
constexpr uint64_t kLzmaMemoryLimit = 68 * 1024 * 1024;
constexpr bool FitsOutputAddition(uint64_t accumulated, uint64_t member) noexcept
{
    return member != 0 && member <= kMaxOutputBytes && accumulated <= kMaxOutputBytes &&
        member <= kMaxOutputBytes - accumulated;
}
static_assert(!FitsOutputAddition(0, kMaxOutputBytes + 1));
static_assert(!FitsOutputAddition(kMaxOutputBytes - 1, 2));
static_assert(!FitsOutputAddition(0, 9007199254740991ULL));
static_assert(FitsOutputAddition(0, kMaxOutputBytes));
static_assert(FitsOutputAddition(0, 1) && FitsOutputAddition(1, 1) &&
    FitsOutputAddition(2, kMaxOutputBytes - 2));
static_assert(!FitsOutputAddition(kMaxOutputBytes, 1));
constexpr size_t kTarBlockSize = 512;
constexpr size_t kIoBufferSize = 64 * 1024;
constexpr std::array<const char*, 7> kAllowedMembers = {
    "zh-en/encoder.ms",
    "zh-en/decoder_full.ms",
    "zh-en/tokenizer.ttok",
    "en-zh/encoder.ms",
    "en-zh/decoder_full.ms",
    "en-zh/source.ttok",
    "en-zh/target.ttok"
};
constexpr std::array<const char*, 2> kAllowedDirectories = {"zh-en", "en-zh"};
std::atomic<uint64_t> g_partialCounter{0};

std::string ErrnoMessage(const std::string& action)
{
    return action + ": " + std::strerror(errno);
}

std::string LowerHex(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
        return static_cast<char>(std::tolower(character));
    });
    return value;
}

bool IsSha256(const std::string& value)
{
    return value.size() == 64 && std::all_of(value.begin(), value.end(), [](unsigned char character) {
        return std::isxdigit(character) != 0;
    });
}

class Sha256 final {
public:
    Sha256()
    {
        if (OH_CryptoDigest_Create("SHA256", &context_) != CRYPTO_SUCCESS || context_ == nullptr) {
            throw std::runtime_error("Cannot create SHA-256 context.");
        }
    }

    ~Sha256()
    {
        if (context_ != nullptr) {
            OH_DigestCrypto_Destroy(context_);
        }
    }

    Sha256(const Sha256&) = delete;
    Sha256& operator=(const Sha256&) = delete;

    void Update(const uint8_t* data, size_t size)
    {
        if (finished_ || (data == nullptr && size != 0)) {
            throw std::runtime_error("Invalid SHA-256 update.");
        }
        Crypto_DataBlob input{const_cast<uint8_t*>(data), size};
        if (size != 0 && OH_CryptoDigest_Update(context_, &input) != CRYPTO_SUCCESS) {
            throw std::runtime_error("SHA-256 update failed.");
        }
    }

    std::string Final()
    {
        if (finished_) {
            throw std::runtime_error("SHA-256 was finalized twice.");
        }
        std::array<uint8_t, 32> digest{};
        Crypto_DataBlob output{nullptr, 0};
        if (OH_CryptoDigest_Final(context_, &output) != CRYPTO_SUCCESS || output.data == nullptr ||
            output.len != digest.size()) {
            OH_Crypto_FreeDataBlob(&output);
            throw std::runtime_error("SHA-256 finalization failed.");
        }
        std::copy_n(output.data, digest.size(), digest.begin());
        OH_Crypto_FreeDataBlob(&output);
        finished_ = true;
        static constexpr char hex[] = "0123456789abcdef";
        std::string result(digest.size() * 2, '0');
        for (size_t index = 0; index < digest.size(); ++index) {
            result[index * 2] = hex[digest[index] >> 4];
            result[index * 2 + 1] = hex[digest[index] & 0x0F];
        }
        return result;
    }

private:
    OH_CryptoDigest* context_ = nullptr;
    bool finished_ = false;
};

void WriteAll(int descriptor, const uint8_t* data, size_t size)
{
    while (size != 0) {
        const ssize_t written = write(descriptor, data, size);
        if (written < 0) {
            if (errno == EINTR) { continue; }
            throw std::runtime_error(ErrnoMessage("Cannot write extracted model"));
        }
        if (written == 0) { throw std::runtime_error("Model write made no progress."); }
        data += static_cast<size_t>(written);
        size -= static_cast<size_t>(written);
    }
}

uint64_t ParseOctal(const uint8_t* data, size_t size, const char* field)
{
    size_t index = 0;
    while (index < size && data[index] == ' ') { ++index; }
    uint64_t value = 0;
    bool found = false;
    for (; index < size && data[index] >= '0' && data[index] <= '7'; ++index) {
        found = true;
        if (value > (UINT64_MAX - static_cast<uint64_t>(data[index] - '0')) / 8) {
            throw std::runtime_error(std::string("TAR ") + field + " overflows.");
        }
        value = value * 8 + static_cast<uint64_t>(data[index] - '0');
    }
    if (!found) { throw std::runtime_error(std::string("TAR ") + field + " is not octal."); }
    for (; index < size; ++index) {
        if (data[index] != 0 && data[index] != ' ') {
            throw std::runtime_error(std::string("TAR ") + field + " has invalid bytes.");
        }
    }
    return value;
}

std::string FieldString(const uint8_t* data, size_t size)
{
    size_t length = 0;
    while (length < size && data[length] != 0) { ++length; }
    if (length == size) { throw std::runtime_error("TAR string field is not terminated."); }
    return std::string(reinterpret_cast<const char*>(data), length);
}

bool IsZeroBlock(const std::array<uint8_t, kTarBlockSize>& block)
{
    return std::all_of(block.begin(), block.end(), [](uint8_t value) { return value == 0; });
}

class TarExtractor final {
public:
    TarExtractor(const std::filesystem::path& directory, const std::vector<TranslationArchiveMember>& expected)
        : directory_(directory), expected_(expected)
    {
    }

    ~TarExtractor()
    {
        if (outputFd_ >= 0) { close(outputFd_); }
    }

    void Consume(const uint8_t* data, size_t size)
    {
        while (size != 0) {
            if (memberRemaining_ != 0) {
                const size_t count = static_cast<size_t>(std::min<uint64_t>(memberRemaining_, size));
                WriteAll(outputFd_, data, count);
                memberDigest_->Update(data, count);
                memberRemaining_ -= count;
                data += count;
                size -= count;
                if (memberRemaining_ == 0) { FinishMember(); }
                continue;
            }
            if (paddingRemaining_ != 0) {
                const size_t count = static_cast<size_t>(std::min<uint64_t>(paddingRemaining_, size));
                if (std::any_of(data, data + count, [](uint8_t value) { return value != 0; })) {
                    throw std::runtime_error("TAR member padding is not zero.");
                }
                paddingRemaining_ -= count;
                data += count;
                size -= count;
                continue;
            }

            const size_t count = std::min(size, block_.size() - blockFill_);
            std::memcpy(block_.data() + blockFill_, data, count);
            blockFill_ += count;
            data += count;
            size -= count;
            if (blockFill_ != block_.size()) { continue; }
            blockFill_ = 0;
            if (IsZeroBlock(block_)) {
                trailerStarted_ = true;
                ++zeroBlocks_;
                continue;
            }
            if (trailerStarted_) { throw std::runtime_error("TAR has non-zero trailing data."); }
            BeginMember();
        }
    }

    void Finish()
    {
        if (blockFill_ != 0 || memberRemaining_ != 0 || paddingRemaining_ != 0 || outputFd_ >= 0) {
            throw std::runtime_error("TAR stream is truncated.");
        }
        if (memberIndex_ != expected_.size()) {
            throw std::runtime_error("TAR is missing required model members.");
        }
        if (zeroBlocks_ < 2) { throw std::runtime_error("TAR end marker is missing."); }
    }

private:
    void BeginMember()
    {
        if (memberIndex_ >= expected_.size()) { throw std::runtime_error("TAR contains an extra member."); }

        uint64_t checksum = 0;
        for (size_t index = 0; index < block_.size(); ++index) {
            checksum += (index >= 148 && index < 156) ? static_cast<uint8_t>(' ') : block_[index];
        }
        if (checksum != ParseOctal(block_.data() + 148, 8, "checksum")) {
            throw std::runtime_error("TAR header checksum mismatch.");
        }
        const char typeFlag = static_cast<char>(block_[156]);
        if (typeFlag != '0' && typeFlag != '\0') {
            throw std::runtime_error("TAR member is not a regular file.");
        }
        if (FieldString(block_.data() + 157, 100) != "" || FieldString(block_.data() + 345, 155) != "") {
            throw std::runtime_error("TAR links and paths are forbidden.");
        }
        if (std::memcmp(block_.data() + 257, "ustar\0", 6) != 0 ||
            std::memcmp(block_.data() + 263, "00", 2) != 0) {
            throw std::runtime_error("TAR must use canonical USTAR headers.");
        }

        const std::string name = FieldString(block_.data(), 100);
        const auto& wanted = expected_[memberIndex_];
        if (name != wanted.name) {
            throw std::runtime_error("TAR member order/name mismatch or duplicate member: " + name);
        }
        const uint64_t size = ParseOctal(block_.data() + 124, 12, "size");
        if (size != wanted.size) { throw std::runtime_error("TAR member size mismatch: " + name); }
        if (ParseOctal(block_.data() + 100, 8, "mode") != 0644 ||
            ParseOctal(block_.data() + 108, 8, "uid") != 0 ||
            ParseOctal(block_.data() + 116, 8, "gid") != 0 ||
            ParseOctal(block_.data() + 136, 12, "mtime") != 0 ||
            FieldString(block_.data() + 265, 32) != "" || FieldString(block_.data() + 297, 32) != "") {
            throw std::runtime_error("TAR member metadata is not canonical.");
        }

        const std::filesystem::path output = directory_ / name;
        const std::filesystem::path parent = output.parent_path();
        std::error_code error;
        std::filesystem::create_directories(parent, error);
        const auto parentStatus = std::filesystem::symlink_status(parent, error);
        if (error || !std::filesystem::is_directory(parentStatus) || std::filesystem::is_symlink(parentStatus)) {
            throw std::runtime_error("Cannot create safe translation member directory.");
        }
        outputFd_ = open(output.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
        if (outputFd_ < 0) { throw std::runtime_error(ErrnoMessage("Cannot create extracted model")); }
        memberDigest_ = std::make_unique<Sha256>();
        memberRemaining_ = size;
        memberSize_ = size;
        if (memberRemaining_ == 0) { FinishMember(); }
    }

    void FinishMember()
    {
        if (outputFd_ < 0 || memberDigest_ == nullptr) { throw std::runtime_error("Invalid TAR member state."); }
        if (close(outputFd_) != 0) {
            outputFd_ = -1;
            throw std::runtime_error(ErrnoMessage("Cannot close extracted model"));
        }
        outputFd_ = -1;
        const std::string actual = memberDigest_->Final();
        memberDigest_.reset();
        if (actual != LowerHex(expected_[memberIndex_].sha256)) {
            throw std::runtime_error("TAR member SHA-256 mismatch: " + expected_[memberIndex_].name);
        }
        paddingRemaining_ = (kTarBlockSize - (memberSize_ % kTarBlockSize)) % kTarBlockSize;
        ++memberIndex_;
    }

    std::filesystem::path directory_;
    const std::vector<TranslationArchiveMember>& expected_;
    std::array<uint8_t, kTarBlockSize> block_{};
    size_t blockFill_ = 0;
    size_t memberIndex_ = 0;
    uint64_t memberRemaining_ = 0;
    uint64_t memberSize_ = 0;
    uint64_t paddingRemaining_ = 0;
    size_t zeroBlocks_ = 0;
    bool trailerStarted_ = false;
    int outputFd_ = -1;
    std::unique_ptr<Sha256> memberDigest_;
};

std::string HashFile(const std::filesystem::path& path)
{
    const int descriptor = open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0) { throw std::runtime_error(ErrnoMessage("Cannot open cached model")); }
    Sha256 digest;
    std::array<uint8_t, kIoBufferSize> buffer{};
    try {
        while (true) {
            const ssize_t count = read(descriptor, buffer.data(), buffer.size());
            if (count < 0) {
                if (errno == EINTR) { continue; }
                throw std::runtime_error(ErrnoMessage("Cannot read cached model"));
            }
            if (count == 0) { break; }
            digest.Update(buffer.data(), static_cast<size_t>(count));
        }
    } catch (...) {
        close(descriptor);
        throw;
    }
    if (close(descriptor) != 0) { throw std::runtime_error(ErrnoMessage("Cannot close cached model")); }
    return digest.Final();
}

bool VerifyCache(const std::filesystem::path& directory, const std::vector<TranslationArchiveMember>& expected)
{
    std::error_code error;
    const auto status = std::filesystem::symlink_status(directory, error);
    if (error || !std::filesystem::is_directory(status) || std::filesystem::is_symlink(status)) { return false; }
    size_t count = 0;
    std::filesystem::recursive_directory_iterator iterator(directory, error);
    const std::filesystem::recursive_directory_iterator end;
    if (error) { return false; }
    for (; iterator != end; iterator.increment(error)) {
        if (error) { return false; }
        const auto& entry = *iterator;
        const auto entryStatus = entry.symlink_status(error);
        if (error || std::filesystem::is_symlink(entryStatus)) { return false; }
        const std::string name = entry.path().lexically_relative(directory).generic_string();
        if (std::filesystem::is_directory(entryStatus)) {
            if (std::find(kAllowedDirectories.begin(), kAllowedDirectories.end(), name) ==
                kAllowedDirectories.end()) {
                return false;
            }
            continue;
        }
        if (!std::filesystem::is_regular_file(entryStatus)) { return false; }
        ++count;
        if (std::find(kAllowedMembers.begin(), kAllowedMembers.end(), name) == kAllowedMembers.end()) { return false; }
    }
    if (error) { return false; }
    if (count != expected.size()) { return false; }
    for (const auto& member : expected) {
        const auto path = directory / member.name;
        const auto fileStatus = std::filesystem::symlink_status(path, error);
        if (error || !std::filesystem::is_regular_file(fileStatus) || std::filesystem::is_symlink(fileStatus) ||
            std::filesystem::file_size(path, error) != member.size || error ||
            HashFile(path) != LowerHex(member.sha256)) {
            return false;
        }
    }
    return true;
}

class PartialDirectory final {
public:
    explicit PartialDirectory(std::filesystem::path path) : path_(std::move(path)) {}
    ~PartialDirectory()
    {
        if (armed_) {
            std::error_code ignored;
            std::filesystem::remove_all(path_, ignored);
        }
    }
    void Release() { armed_ = false; }

private:
    std::filesystem::path path_;
    bool armed_ = true;
};

void ValidateRequest(const TranslationArchiveRequest& request)
{
    if (request.archiveFd < 0 || request.archiveLength == 0 || request.archiveLength > kMaxCompressedBytes ||
        request.archiveOffset > static_cast<uint64_t>(INT64_MAX) ||
        request.archiveLength > static_cast<uint64_t>(INT64_MAX) - request.archiveOffset) {
        throw std::invalid_argument("Invalid or oversized compressed archive FD range.");
    }
    if (!IsSha256(request.archiveSha256)) { throw std::invalid_argument("archiveSha256 must be 64 hexadecimal characters."); }
    if (request.members.size() != kAllowedMembers.size()) {
        throw std::invalid_argument("Exactly seven translation model/tokenizer members are required.");
    }
    uint64_t memberBytes = 0;
    for (size_t index = 0; index < request.members.size(); ++index) {
        const auto& member = request.members[index];
        if (member.name != kAllowedMembers[index] || !IsSha256(member.sha256) ||
            !FitsOutputAddition(memberBytes, member.size)) {
            throw std::invalid_argument("Invalid model member contract.");
        }
        memberBytes += member.size;
    }
    const std::filesystem::path root(request.cacheRoot);
    if (request.cacheRoot.empty() || request.cacheRoot.find('\0') != std::string::npos || !root.is_absolute() ||
        root.lexically_normal() != root) {
        throw std::invalid_argument("cacheRoot must be a normalized absolute app-private path.");
    }
}

void DecodeArchive(const TranslationArchiveRequest& request, const std::filesystem::path& outputDirectory)
{
    lzma_stream stream = LZMA_STREAM_INIT;
    lzma_ret result = lzma_stream_decoder(&stream, kLzmaMemoryLimit, LZMA_TELL_ANY_CHECK);
    if (result != LZMA_OK) { throw std::runtime_error("Cannot initialize bounded XZ decoder."); }

    TarExtractor tar(outputDirectory, request.members);
    Sha256 archiveDigest;
    std::array<uint8_t, kIoBufferSize> input{};
    std::array<uint8_t, kIoBufferSize> output{};
    uint64_t inputRemaining = request.archiveLength;
    uint64_t inputOffset = request.archiveOffset;
    uint64_t outputBytes = 0;
    bool sawCrc64 = false;
    bool ended = false;
    try {
        while (!ended) {
            if (stream.avail_in == 0 && inputRemaining != 0) {
                const size_t wanted = static_cast<size_t>(std::min<uint64_t>(input.size(), inputRemaining));
                ssize_t count;
                do {
                    count = pread(request.archiveFd, input.data(), wanted, static_cast<off_t>(inputOffset));
                } while (count < 0 && errno == EINTR);
                if (count < 0) { throw std::runtime_error(ErrnoMessage("Cannot read translation archive")); }
                if (count == 0) { throw std::runtime_error("Translation archive FD range is truncated."); }
                stream.next_in = input.data();
                stream.avail_in = static_cast<size_t>(count);
                archiveDigest.Update(input.data(), static_cast<size_t>(count));
                inputOffset += static_cast<uint64_t>(count);
                inputRemaining -= static_cast<uint64_t>(count);
            }

            stream.next_out = output.data();
            stream.avail_out = output.size();
            result = lzma_code(&stream, inputRemaining == 0 ? LZMA_FINISH : LZMA_RUN);
            const size_t produced = output.size() - stream.avail_out;
            if (outputBytes > kMaxOutputBytes - produced) { throw std::runtime_error("XZ output exceeds 208 MiB."); }
            outputBytes += produced;
            tar.Consume(output.data(), produced);

            if (result == LZMA_GET_CHECK) {
                if (lzma_get_check(&stream) != LZMA_CHECK_CRC64) { throw std::runtime_error("XZ stream must use CRC64."); }
                sawCrc64 = true;
                continue;
            }
            if (result == LZMA_STREAM_END) {
                if (stream.avail_in != 0 || inputRemaining != 0) {
                    throw std::runtime_error("XZ concatenated stream or trailing data is forbidden.");
                }
                ended = true;
                continue;
            }
            if (result != LZMA_OK) {
                throw std::runtime_error(result == LZMA_MEMLIMIT_ERROR ?
                    "XZ stream exceeds the 68 MiB liblzma memory limit." : "Invalid XZ stream.");
            }
            if (inputRemaining == 0 && stream.avail_in == 0 && produced == 0) {
                throw std::runtime_error("XZ stream ended without a footer.");
            }
        }
        if (!sawCrc64 || lzma_get_check(&stream) != LZMA_CHECK_CRC64) {
            throw std::runtime_error("XZ stream must use CRC64.");
        }
        tar.Finish();
        if (archiveDigest.Final() != LowerHex(request.archiveSha256)) {
            throw std::runtime_error("Translation archive SHA-256 mismatch.");
        }
    } catch (...) {
        lzma_end(&stream);
        throw;
    }
    lzma_end(&stream);
}
} // namespace

TranslationArchiveResult ExtractTranslationArchive(const TranslationArchiveRequest& request)
{
    ValidateRequest(request);
    std::error_code error;
    const std::filesystem::path root(request.cacheRoot);
    std::filesystem::create_directories(root, error);
    if (error) { throw std::runtime_error("Cannot create translation cache root: " + error.message()); }
    const auto rootStatus = std::filesystem::symlink_status(root, error);
    if (error || !std::filesystem::is_directory(rootStatus) || std::filesystem::is_symlink(rootStatus)) {
        throw std::runtime_error("Translation cache root is not a safe directory.");
    }

    const std::string key = LowerHex(request.archiveSha256);
    const std::filesystem::path finalDirectory = root / key;
    if (std::filesystem::exists(finalDirectory, error)) {
        if (!error && VerifyCache(finalDirectory, request.members)) {
            return {finalDirectory.string(), true};
        }
        throw std::runtime_error("Existing SHA-keyed translation cache is invalid.");
    }
    if (error) { throw std::runtime_error("Cannot inspect translation cache."); }

    const uint64_t counter = g_partialCounter.fetch_add(1, std::memory_order_relaxed);
    const std::filesystem::path partial = root /
        ("." + key + ".partial." + std::to_string(getpid()) + "." + std::to_string(counter));
    if (partial.parent_path() != root || partial.lexically_normal() != partial ||
        !std::filesystem::create_directory(partial, error) || error) {
        throw std::runtime_error("Cannot create safe translation partial directory.");
    }
    PartialDirectory cleanup(partial);
    DecodeArchive(request, partial);
    if (!VerifyCache(partial, request.members)) { throw std::runtime_error("Extracted translation cache verification failed."); }

    if (::rename(partial.c_str(), finalDirectory.c_str()) != 0) {
        if (errno == EEXIST || errno == ENOTEMPTY) {
            if (VerifyCache(finalDirectory, request.members)) {
                return {finalDirectory.string(), true};
            }
        }
        throw std::runtime_error(ErrnoMessage("Cannot atomically publish translation cache"));
    }
    cleanup.Release();
    return {finalDirectory.string(), false};
}
