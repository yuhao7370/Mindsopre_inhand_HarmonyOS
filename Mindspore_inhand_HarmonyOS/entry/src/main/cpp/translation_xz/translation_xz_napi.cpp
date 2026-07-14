#include "translation_xz_extract.h"

#include <napi/native_api.h>

#include <cerrno>
#include <climits>
#include <cmath>
#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>
#include <unistd.h>

namespace {
constexpr uint64_t kMaxSafeInteger = 9007199254740991ULL;
constexpr size_t kMaxPathBytes = 4096;
constexpr const char* kUnknownError = "Unknown translation archive error.";

[[noreturn]] void Fatal(const char* message) noexcept
{
    napi_fatal_error("translation_archive", NAPI_AUTO_LENGTH, message, NAPI_AUTO_LENGTH);
}

void Check(napi_env env, napi_status status, const char* operation)
{
    if (status == napi_ok) { return; }
    const napi_extended_error_info* info = nullptr;
    napi_get_last_error_info(env, &info);
    std::string message(operation);
    if (info != nullptr && info->error_message != nullptr) {
        message += ": ";
        message += info->error_message;
    }
    throw std::runtime_error(message);
}

void ThrowOrFatal(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok) { Fatal("Cannot inspect exception state."); }
    if (!pending && napi_throw_error(env, nullptr, message) != napi_ok) { Fatal("Cannot establish NAPI exception."); }
}

napi_value RequiredProperty(napi_env env, napi_value object, const char* name)
{
    bool present = false;
    Check(env, napi_has_named_property(env, object, name, &present), "inspect property");
    if (!present) { throw std::invalid_argument(std::string("Missing property: ") + name); }
    napi_value result = nullptr;
    Check(env, napi_get_named_property(env, object, name, &result), "read property");
    return result;
}

std::string ReadString(napi_env env, napi_value value, const char* name, size_t maximum)
{
    napi_valuetype type;
    Check(env, napi_typeof(env, value, &type), "inspect string");
    if (type != napi_string) { throw std::invalid_argument(std::string(name) + " must be a string."); }
    size_t length = 0;
    Check(env, napi_get_value_string_utf8(env, value, nullptr, 0, &length), "measure string");
    if (length == 0 || length > maximum) { throw std::invalid_argument(std::string(name) + " has invalid length."); }
    std::string result(length, '\0');
    size_t copied = 0;
    Check(env, napi_get_value_string_utf8(env, value, result.data(), result.size() + 1, &copied), "read string");
    if (copied != length) { throw std::runtime_error("NAPI string length changed."); }
    return result;
}

uint64_t ReadUnsigned(napi_env env, napi_value value, const char* name, bool positive)
{
    napi_valuetype type;
    Check(env, napi_typeof(env, value, &type), "inspect number");
    if (type != napi_number) { throw std::invalid_argument(std::string(name) + " must be a number."); }
    double numericValue = 0;
    Check(env, napi_get_value_double(env, value, &numericValue), "read number");
    if (!std::isfinite(numericValue) || std::trunc(numericValue) != numericValue ||
        numericValue < (positive ? 1.0 : 0.0) || numericValue > static_cast<double>(kMaxSafeInteger)) {
        throw std::invalid_argument(std::string(name) + " is outside the safe integer range.");
    }
    return static_cast<uint64_t>(numericValue);
}

TranslationArchiveRequest ParseRequest(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argument = nullptr;
    Check(env, napi_get_cb_info(env, info, &argc, &argument, nullptr, nullptr), "read extract arguments");
    napi_valuetype type;
    if (argc != 1 || napi_typeof(env, argument, &type) != napi_ok || type != napi_object) {
        throw std::invalid_argument("extractArchive expects one request object.");
    }

    TranslationArchiveRequest request;
    const uint64_t archiveFd = ReadUnsigned(env, RequiredProperty(env, argument, "archiveFd"), "archiveFd", false);
    if (archiveFd > static_cast<uint64_t>(INT_MAX)) {
        throw std::invalid_argument("archiveFd is outside the native descriptor range.");
    }
    request.archiveFd = static_cast<int>(archiveFd);
    request.archiveOffset = ReadUnsigned(env, RequiredProperty(env, argument, "archiveOffset"), "archiveOffset", false);
    request.archiveLength = ReadUnsigned(env, RequiredProperty(env, argument, "archiveLength"), "archiveLength", true);
    request.cacheRoot = ReadString(env, RequiredProperty(env, argument, "cacheRoot"), "cacheRoot", kMaxPathBytes);
    request.archiveSha256 = ReadString(env, RequiredProperty(env, argument, "archiveSha256"), "archiveSha256", 64);

    napi_value members = RequiredProperty(env, argument, "members");
    bool isArray = false;
    Check(env, napi_is_array(env, members, &isArray), "inspect members");
    uint32_t length = 0;
    if (!isArray || napi_get_array_length(env, members, &length) != napi_ok || length != 3) {
        throw std::invalid_argument("members must contain exactly three entries.");
    }
    request.members.reserve(length);
    for (uint32_t index = 0; index < length; ++index) {
        napi_value member = nullptr;
        Check(env, napi_get_element(env, members, index, &member), "read member");
        if (napi_typeof(env, member, &type) != napi_ok || type != napi_object) {
            throw std::invalid_argument("Each member must be an object.");
        }
        request.members.push_back({
            ReadString(env, RequiredProperty(env, member, "name"), "member.name", 32),
            ReadUnsigned(env, RequiredProperty(env, member, "size"), "member.size", true),
            ReadString(env, RequiredProperty(env, member, "sha256"), "member.sha256", 64),
        });
    }
    const int ownedFd = dup(request.archiveFd);
    if (ownedFd < 0) { throw std::runtime_error("Cannot retain archive FD: " + std::string(std::strerror(errno))); }
    request.archiveFd = ownedFd;
    return request;
}

napi_status CreateError(napi_env env, const char* message, napi_value* result) noexcept
{
    napi_value text = nullptr;
    napi_status status = napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
    return status == napi_ok ? napi_create_error(env, nullptr, text, result) : status;
}

napi_value RejectPromise(napi_env env, napi_deferred deferred, napi_value promise, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateError(env, message, &error) != napi_ok || napi_reject_deferred(env, deferred, error) != napi_ok) {
        Fatal("Cannot reject translation archive Promise.");
    }
    return promise;
}

struct ExtractWork {
    ~ExtractWork()
    {
        if (request.archiveFd >= 0) { close(request.archiveFd); }
    }
    napi_deferred deferred = nullptr;
    napi_async_work async = nullptr;
    TranslationArchiveRequest request;
    TranslationArchiveResult result;
    std::exception_ptr error;
};

void Execute(napi_env, void* raw) noexcept
{
    auto* work = static_cast<ExtractWork*>(raw);
    try {
        work->result = ExtractTranslationArchive(work->request);
    } catch (...) {
        work->error = std::current_exception();
    }
}

void RejectWork(napi_env env, ExtractWork* work, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateError(env, message, &error) != napi_ok || napi_reject_deferred(env, work->deferred, error) != napi_ok) {
        Fatal("Cannot reject completed translation archive Promise.");
    }
}

void Complete(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<ExtractWork> work(static_cast<ExtractWork*>(raw));
    if (work == nullptr) { Fatal("Translation archive async context is null."); }
    if (status != napi_ok) {
        RejectWork(env, work.get(), "Translation archive extraction was cancelled.");
    } else if (work->error != nullptr) {
        try {
            std::rethrow_exception(work->error);
        } catch (const std::exception& error) {
            RejectWork(env, work.get(), error.what());
        } catch (...) {
            RejectWork(env, work.get(), kUnknownError);
        }
    } else {
        napi_value result = nullptr;
        napi_value directory = nullptr;
        napi_value reused = nullptr;
        if (napi_create_object(env, &result) != napi_ok ||
            napi_create_string_utf8(env, work->result.directory.c_str(), work->result.directory.size(), &directory) != napi_ok ||
            napi_get_boolean(env, work->result.reused, &reused) != napi_ok ||
            napi_set_named_property(env, result, "directory", directory) != napi_ok ||
            napi_set_named_property(env, result, "reused", reused) != napi_ok ||
            napi_resolve_deferred(env, work->deferred, result) != napi_ok) {
            Fatal("Cannot resolve translation archive Promise.");
        }
    }
    napi_async_work async = work->async;
    work->async = nullptr;
    const napi_status cleanup = napi_delete_async_work(env, async);
    work.reset();
    if (cleanup != napi_ok) { Fatal("Cannot delete translation archive async work."); }
}

void DeleteUnqueuedOrFatal(napi_env env, std::unique_ptr<ExtractWork>& work) noexcept
{
    napi_async_work async = work->async;
    work->async = nullptr;
    const napi_status cleanup = async == nullptr ? napi_ok : napi_delete_async_work(env, async);
    work.reset();
    if (cleanup != napi_ok) { Fatal("Cannot delete unqueued translation archive work."); }
}

napi_value ExtractImpl(napi_env env, napi_callback_info info)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create extraction promise");

    TranslationArchiveRequest request;
    try {
        request = ParseRequest(env, info);
    } catch (const std::exception& error) {
        return RejectPromise(env, deferred, promise, error.what());
    }

    auto work = std::make_unique<ExtractWork>();
    work->deferred = deferred;
    work->request = std::move(request);
    napi_value resource = nullptr;
    Check(env, napi_create_string_utf8(env, "translation_archive_extract", NAPI_AUTO_LENGTH, &resource), "create resource name");
    napi_status status = napi_create_async_work(env, nullptr, resource, Execute, Complete, work.get(), &work->async);
    if (status != napi_ok) {
        DeleteUnqueuedOrFatal(env, work);
        return RejectPromise(env, deferred, promise, "Cannot create translation archive async work.");
    }
    status = napi_queue_async_work(env, work->async);
    if (status != napi_ok) {
        DeleteUnqueuedOrFatal(env, work);
        return RejectPromise(env, deferred, promise, "Cannot queue translation archive async work.");
    }
    work.release();
    return promise;
}

napi_value ExtractBoundary(napi_env env, napi_callback_info info) noexcept
{
    try {
        return ExtractImpl(env, info);
    } catch (const std::exception& error) {
        ThrowOrFatal(env, error.what());
    } catch (...) {
        ThrowOrFatal(env, kUnknownError);
    }
    return nullptr;
}

napi_value Init(napi_env env, napi_value exports) noexcept
{
    try {
        napi_property_descriptor property = {
            "extractArchive", nullptr, ExtractBoundary, nullptr, nullptr, nullptr, napi_default, nullptr
        };
        Check(env, napi_define_properties(env, exports, 1, &property), "define extraction export");
        return exports;
    } catch (const std::exception& error) {
        ThrowOrFatal(env, error.what());
    } catch (...) {
        ThrowOrFatal(env, kUnknownError);
    }
    return nullptr;
}
} // namespace

static napi_module translationArchiveModule = {
    1, 0, nullptr, Init, "translation_archive", nullptr, {0},
};

extern "C" __attribute__((constructor)) void RegisterTranslationArchiveModule()
{
    napi_module_register(&translationArchiveModule);
}
