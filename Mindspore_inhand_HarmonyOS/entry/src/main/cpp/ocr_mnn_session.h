#ifndef MINDSPORE_INHAND_OCR_MNN_SESSION_H
#define MINDSPORE_INHAND_OCR_MNN_SESSION_H

#include <cstddef>
#include <cstdint>
#include <mutex>
#include <vector>

namespace MNN {
class Interpreter;
class Session;
class Tensor;
}

class OcrMnnSession final {
public:
    struct Model {
        std::vector<uint8_t> bytes;
        MNN::Interpreter* interpreter = nullptr;
        MNN::Session* session = nullptr;
        MNN::Tensor* input = nullptr;
    };

    OcrMnnSession() = default;
    ~OcrMnnSession();
    OcrMnnSession(const OcrMnnSession&) = delete;
    OcrMnnSession& operator=(const OcrMnnSession&) = delete;

    void LoadModels(const uint8_t* detectorBytes, size_t detectorSize,
                    const uint8_t* recognizerBytes, size_t recognizerSize);
    std::vector<float> PredictDetector(const std::vector<float>& input);
    std::vector<float> PredictRecognizer(const std::vector<float>& input);
    void Release() noexcept;

private:
    std::vector<float> Predict(Model& model, const std::vector<float>& input,
                               const std::vector<int>& inputShape, const std::vector<int>& outputShape,
                               const char* outputName, const char* label);
    void ReleaseModel(Model& model) noexcept;

    std::mutex mutex_;
    Model detector_;
    Model recognizer_;
};

#endif
