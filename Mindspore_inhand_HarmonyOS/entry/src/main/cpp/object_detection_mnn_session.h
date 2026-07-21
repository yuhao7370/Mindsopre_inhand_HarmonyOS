#ifndef MINDSPORE_INHAND_OBJECT_DETECTION_MNN_SESSION_H
#define MINDSPORE_INHAND_OBJECT_DETECTION_MNN_SESSION_H

#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace MNN {
class Interpreter;
class Session;
class Tensor;
}

struct ObjectDetectionModelInfo {
    std::string inputName;
    std::vector<int32_t> inputShape;
    std::string outputName;
    std::vector<int32_t> outputShape;
};

class ObjectDetectionMnnSession final {
public:
    ObjectDetectionMnnSession() = default;
    ~ObjectDetectionMnnSession();

    ObjectDetectionMnnSession(const ObjectDetectionMnnSession&) = delete;
    ObjectDetectionMnnSession& operator=(const ObjectDetectionMnnSession&) = delete;

    ObjectDetectionModelInfo LoadModel(const uint8_t* bytes, size_t size);
    std::vector<float> Predict(const std::vector<float>& input);
    void Release() noexcept;

private:
    void ReleaseLocked() noexcept;

    std::mutex mutex_;
    std::vector<uint8_t> modelBytes_;
    MNN::Interpreter* interpreter_ = nullptr;
    MNN::Session* session_ = nullptr;
    MNN::Tensor* input_ = nullptr;
};

#endif
