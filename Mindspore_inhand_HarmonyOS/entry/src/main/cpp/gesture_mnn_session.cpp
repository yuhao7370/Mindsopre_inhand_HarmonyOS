#include "gesture_mnn_session.h"

#include <MNN/Interpreter.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <stdexcept>

namespace {
constexpr size_t kInputElementCount = 1U * 3U * 224U * 224U;
const std::vector<int> kInputShape = {1, 3, 224, 224};

struct OutputContract {
    const char* name;
    std::vector<int> shape;
};

const std::array<OutputContract, 3> kOutputContracts = {{
    {"layer89-conv-hand", {1, 60, 7, 7}},
    {"layer101-conv-hand", {1, 60, 14, 14}},
    {"layer113-conv-hand", {1, 60, 28, 28}},
}};

bool IsFloat32(const MNN::Tensor* tensor)
{
    const halide_type_t type = tensor->getType();
    return type.code == halide_type_float && type.bits == 32 && type.lanes == 1;
}

void ValidateTensor(const MNN::Tensor* tensor, const std::vector<int>& shape, const char* name)
{
    if (tensor == nullptr) {
        throw std::runtime_error(std::string("Missing gesture tensor: ") + name);
    }
    if (!IsFloat32(tensor)) {
        throw std::runtime_error(std::string("Gesture tensor is not float32: ") + name);
    }
    if (tensor->shape() != shape) {
        throw std::runtime_error(std::string("Gesture tensor shape mismatch: ") + name);
    }
}

size_t ElementCount(const std::vector<int>& shape)
{
    size_t count = 1;
    for (const int dimension : shape) {
        if (dimension <= 0) {
            throw std::runtime_error("Gesture tensor has a non-positive dimension.");
        }
        count *= static_cast<size_t>(dimension);
    }
    return count;
}
}

GestureMnnSession::~GestureMnnSession()
{
    Release();
}

GestureModelInfo GestureMnnSession::LoadModel(const uint8_t* bytes, size_t size)
{
    if (bytes == nullptr || size == 0) {
        throw std::invalid_argument("Gesture model bytes must not be empty.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
    modelBytes_.assign(bytes, bytes + size);

    try {
        interpreter_ = MNN::Interpreter::createFromBuffer(modelBytes_.data(), modelBytes_.size());
        if (interpreter_ == nullptr) {
            throw std::runtime_error("MNN rejected the gesture model buffer.");
        }
        MNN::ScheduleConfig config;
        config.type = MNN_FORWARD_CPU;
        config.numThread = 4;
        session_ = interpreter_->createSession(config);
        if (session_ == nullptr) {
            throw std::runtime_error("MNN failed to create the gesture CPU session.");
        }

        const auto& inputs = interpreter_->getSessionInputAll(session_);
        const auto inputEntry = inputs.find("data");
        if (inputs.size() != 1 || inputEntry == inputs.end()) {
            throw std::runtime_error("Gesture model input name mismatch; expected only data.");
        }
        input_ = inputEntry->second;
        ValidateTensor(input_, kInputShape, "data");
        for (const auto& contract : kOutputContracts) {
            ValidateTensor(interpreter_->getSessionOutput(session_, contract.name), contract.shape, contract.name);
        }
    } catch (...) {
        ReleaseLocked();
        throw;
    }

    return {"data", {1, 3, 224, 224}};
}

GestureRawOutputs GestureMnnSession::Predict(const std::vector<float>& input)
{
    if (input.size() != kInputElementCount) {
        throw std::invalid_argument("Gesture input must contain exactly 150528 float32 values.");
    }
    if (!std::all_of(input.begin(), input.end(), [](float value) { return std::isfinite(value); })) {
        throw std::invalid_argument("Gesture input contains a non-finite value.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    if (interpreter_ == nullptr || session_ == nullptr || input_ == nullptr) {
        throw std::runtime_error("Gesture model is not loaded.");
    }

    MNN::Tensor hostInput(input_, MNN::Tensor::CAFFE, true);
    if (hostInput.host<float>() == nullptr || hostInput.elementSize() != kInputElementCount ||
        hostInput.usize() != kInputElementCount * sizeof(float)) {
        throw std::runtime_error("MNN allocated an invalid gesture input host tensor.");
    }
    std::memcpy(hostInput.host<float>(), input.data(), kInputElementCount * sizeof(float));
    if (!input_->copyFromHostTensor(&hostInput)) {
        throw std::runtime_error("MNN failed to copy the gesture input tensor.");
    }
    const MNN::ErrorCode status = interpreter_->runSession(session_);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error("MNN gesture inference failed with code " + std::to_string(static_cast<int>(status)) + '.');
    }

    GestureRawOutputs result;
    result.tensors.reserve(kOutputContracts.size());
    for (const auto& contract : kOutputContracts) {
        MNN::Tensor* output = interpreter_->getSessionOutput(session_, contract.name);
        ValidateTensor(output, contract.shape, contract.name);
        MNN::Tensor hostOutput(output, MNN::Tensor::CAFFE, true);
        const size_t expectedElementCount = ElementCount(contract.shape);
        if (hostOutput.host<float>() == nullptr ||
            static_cast<size_t>(hostOutput.elementSize()) != expectedElementCount ||
            hostOutput.usize() != expectedElementCount * sizeof(float)) {
            throw std::runtime_error(std::string("MNN allocated an invalid gesture output host tensor: ") +
                                     contract.name);
        }
        if (!output->copyToHostTensor(&hostOutput)) {
            throw std::runtime_error(std::string("MNN failed to copy gesture output: ") + contract.name);
        }
        GestureRawTensor tensor;
        tensor.name = contract.name;
        tensor.shape.assign(contract.shape.begin(), contract.shape.end());
        tensor.data.assign(hostOutput.host<float>(), hostOutput.host<float>() + expectedElementCount);
        if (!std::all_of(tensor.data.begin(), tensor.data.end(), [](float value) { return std::isfinite(value); })) {
            throw std::runtime_error(std::string("Gesture output contains a non-finite value: ") + contract.name);
        }
        result.tensors.emplace_back(std::move(tensor));
    }
    return result;
}

void GestureMnnSession::Release() noexcept
{
    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
}

void GestureMnnSession::ReleaseLocked() noexcept
{
    input_ = nullptr;
    if (interpreter_ != nullptr && session_ != nullptr) {
        interpreter_->releaseSession(session_);
    }
    session_ = nullptr;
    if (interpreter_ != nullptr) {
        interpreter_->releaseModel();
        MNN::Interpreter::destroy(interpreter_);
    }
    interpreter_ = nullptr;
    std::vector<uint8_t>().swap(modelBytes_);
}
