#ifndef MINDSPORE_INHAND_STYLE_TRANSFER_MNN_SESSION_H
#define MINDSPORE_INHAND_STYLE_TRANSFER_MNN_SESSION_H

#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <vector>

struct StyleTransferMnnStage;

struct StyleTransferMnnOutput {
    std::vector<float> output;
    int64_t predictMs = 0;
    int64_t transferMs = 0;
};

class StyleTransferMnnSession final {
public:
    StyleTransferMnnSession();
    ~StyleTransferMnnSession();

    StyleTransferMnnSession(const StyleTransferMnnSession&) = delete;
    StyleTransferMnnSession& operator=(const StyleTransferMnnSession&) = delete;

    void LoadModels(const uint8_t* predictBytes, size_t predictSize,
                    const uint8_t* transferBytes, size_t transferSize);
    bool ValidatePredictModel(const uint8_t* bytes, size_t size) noexcept;
    bool ValidateTransferModel(const uint8_t* bytes, size_t size) noexcept;
    bool ValidateModelPair(const uint8_t* predictBytes, size_t predictSize,
                           const uint8_t* transferBytes, size_t transferSize) noexcept;
    StyleTransferMnnOutput Run(const std::vector<float>& styleInput,
                               const std::vector<float>& contentInput);
    void Release() noexcept;

private:
    std::mutex mutex_;
    std::unique_ptr<StyleTransferMnnStage> predict_;
    std::unique_ptr<StyleTransferMnnStage> transfer_;
};

#endif
