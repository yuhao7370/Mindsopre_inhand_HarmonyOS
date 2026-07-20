#include "segmentation_mnn_session.h"

#include <MNN/Interpreter.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <stdexcept>

namespace {
constexpr size_t kInputElementCount = 1U * 256U * 256U * 3U;
constexpr size_t kOutputElementCount = 1U * 256U * 256U * 1U;
const std::vector<int> kInputShape = {1, 256, 256, 3};
const std::vector<int> kOutputShape = {1, 256, 256, 1};
constexpr const char* kInputName = "input_1";
constexpr const char* kOutputName = "activation_10";

bool IsFloat32(const MNN::Tensor* tensor)
{
    const halide_type_t type = tensor->getType();
    return type.code == halide_type_float && type.bits == 32 && type.lanes == 1;
}

void ValidateTensor(const MNN::Tensor* tensor, const std::vector<int>& shape, const char* name)
{
    if (tensor == nullptr) {
        throw std::runtime_error(std::string("Missing segmentation tensor: ") + name);
    }
    if (!IsFloat32(tensor)) {
        throw std::runtime_error(std::string("Segmentation tensor is not float32: ") + name);
    }
    if (tensor->shape() != shape) {
        throw std::runtime_error(std::string("Segmentation tensor shape mismatch: ") + name);
    }
}
}

SegmentationMnnSession::~SegmentationMnnSession()
{
    Release();
}

SegmentationModelInfo SegmentationMnnSession::LoadModel(const uint8_t* bytes, size_t size)
{
    if (bytes == nullptr || size == 0) {
        throw std::invalid_argument("Segmentation model bytes must not be empty.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
    modelBytes_.assign(bytes, bytes + size);
    try {
        interpreter_ = MNN::Interpreter::createFromBuffer(modelBytes_.data(), modelBytes_.size());
        if (interpreter_ == nullptr) {
            throw std::runtime_error("MNN rejected the segmentation model buffer.");
        }
        MNN::ScheduleConfig config;
        config.type = MNN_FORWARD_CPU;
        config.numThread = 2;
        session_ = interpreter_->createSession(config);
        if (session_ == nullptr) {
            throw std::runtime_error("MNN failed to create the segmentation CPU session.");
        }
        const auto& inputs = interpreter_->getSessionInputAll(session_);
        const auto inputEntry = inputs.find(kInputName);
        if (inputs.size() != 1 || inputEntry == inputs.end()) {
            throw std::runtime_error("Segmentation model input name mismatch; expected only input_1.");
        }
        input_ = inputEntry->second;
        ValidateTensor(input_, kInputShape, kInputName);
        ValidateTensor(interpreter_->getSessionOutput(session_, kOutputName), kOutputShape, kOutputName);
    } catch (...) {
        ReleaseLocked();
        throw;
    }
    return {kInputName, {1, 256, 256, 3}, kOutputName, {1, 256, 256, 1}};
}

std::vector<float> SegmentationMnnSession::Predict(const std::vector<float>& input)
{
    if (input.size() != kInputElementCount) {
        throw std::invalid_argument("Segmentation input must contain exactly 196608 float32 values.");
    }
    if (!std::all_of(input.begin(), input.end(), [](float value) { return std::isfinite(value); })) {
        throw std::invalid_argument("Segmentation input contains a non-finite value.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    if (interpreter_ == nullptr || session_ == nullptr || input_ == nullptr) {
        throw std::runtime_error("Segmentation model is not loaded.");
    }
    MNN::Tensor hostInput(input_, MNN::Tensor::TENSORFLOW, true);
    if (hostInput.host<float>() == nullptr || hostInput.elementSize() != kInputElementCount ||
        hostInput.usize() != kInputElementCount * sizeof(float)) {
        throw std::runtime_error("MNN allocated an invalid segmentation input host tensor.");
    }
    std::memcpy(hostInput.host<float>(), input.data(), kInputElementCount * sizeof(float));
    if (!input_->copyFromHostTensor(&hostInput)) {
        throw std::runtime_error("MNN failed to copy the segmentation input tensor.");
    }
    const MNN::ErrorCode status = interpreter_->runSession(session_);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error("MNN segmentation inference failed with code " +
                                 std::to_string(static_cast<int>(status)) + '.');
    }
    MNN::Tensor* output = interpreter_->getSessionOutput(session_, kOutputName);
    ValidateTensor(output, kOutputShape, kOutputName);
    MNN::Tensor hostOutput(output, MNN::Tensor::TENSORFLOW, true);
    if (hostOutput.host<float>() == nullptr || hostOutput.elementSize() != kOutputElementCount ||
        hostOutput.usize() != kOutputElementCount * sizeof(float)) {
        throw std::runtime_error("MNN allocated an invalid segmentation output host tensor.");
    }
    if (!output->copyToHostTensor(&hostOutput)) {
        throw std::runtime_error("MNN failed to copy the segmentation output tensor.");
    }
    std::vector<float> result(hostOutput.host<float>(), hostOutput.host<float>() + kOutputElementCount);
    if (!std::all_of(result.begin(), result.end(), [](float value) { return std::isfinite(value); })) {
        throw std::runtime_error("Segmentation output contains a non-finite value.");
    }
    return result;
}

void SegmentationMnnSession::Release() noexcept
{
    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
}

void SegmentationMnnSession::ReleaseLocked() noexcept
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
