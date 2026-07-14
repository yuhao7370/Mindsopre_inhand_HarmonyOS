#ifndef MINDSPORE_INHAND_TRANSLATION_XZ_EXTRACT_H
#define MINDSPORE_INHAND_TRANSLATION_XZ_EXTRACT_H

#include <cstdint>
#include <string>
#include <vector>

struct TranslationArchiveMember {
    std::string name;
    uint64_t size = 0;
    std::string sha256;
};

struct TranslationArchiveRequest {
    int archiveFd = -1;
    uint64_t archiveOffset = 0;
    uint64_t archiveLength = 0;
    std::string cacheRoot;
    std::string archiveSha256;
    std::vector<TranslationArchiveMember> members;
};

struct TranslationArchiveResult {
    std::string directory;
    bool reused = false;
};

TranslationArchiveResult ExtractTranslationArchive(const TranslationArchiveRequest& request);

#endif
