#ifndef MINDSPORE_INHAND_GESTURE_MNN_SESSION_H
#define MINDSPORE_INHAND_GESTURE_MNN_SESSION_H

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

struct GestureModelInfo {
    std::string inputName;
    std::vector<int32_t> inputShape;
};

struct GestureRawTensor {
    std::string name;
    std::vector<int32_t> shape;
    std::vector<float> data;
};

struct GestureRawOutputs {
    std::vector<GestureRawTensor> tensors;
};

class GestureMnnSession final {
public:
    GestureMnnSession() = default;
    ~GestureMnnSession();

    GestureMnnSession(const GestureMnnSession&) = delete;
    GestureMnnSession& operator=(const GestureMnnSession&) = delete;

    GestureModelInfo LoadModel(const uint8_t* bytes, size_t size);
    GestureRawOutputs Predict(const std::vector<float>& input);
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
