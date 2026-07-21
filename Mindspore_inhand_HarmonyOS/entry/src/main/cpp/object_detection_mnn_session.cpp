#include "object_detection_mnn_session.h"

#include <MNN/Interpreter.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <stdexcept>
#include <type_traits>
#include <utility>

namespace {
constexpr size_t kInputElementCount = 1U * 3U * 320U * 320U;
constexpr size_t kOutputElementCount = 1U * 2125U * 112U;
const std::vector<int> kInputShape = {1, 3, 320, 320};
const std::vector<int> kOutputShape = {1, 2125, 112};
constexpr const char* kInputName = "data";
constexpr const char* kOutputName = "output";

static_assert(std::is_nothrow_move_constructible<ObjectDetectionModelInfo>::value,
              "Model info handoff after session replacement must not throw.");
static_assert(std::is_nothrow_move_assignable<ObjectDetectionModelInfo>::value,
              "Async model-info publication after session replacement must not throw.");

bool IsFloat32(const MNN::Tensor* tensor)
{
    const halide_type_t type = tensor->getType();
    return type.code == halide_type_float && type.bits == 32 && type.lanes == 1;
}

void ValidateTensor(const MNN::Tensor* tensor, const std::vector<int>& shape, const char* name)
{
    if (tensor == nullptr) {
        throw std::runtime_error(std::string("Missing object-detection tensor: ") + name);
    }
    if (!IsFloat32(tensor)) {
        throw std::runtime_error(std::string("Object-detection tensor is not float32: ") + name);
    }
    if (tensor->shape() != shape) {
        throw std::runtime_error(std::string("Object-detection tensor shape mismatch: ") + name);
    }
}

struct CandidateModel {
    std::vector<uint8_t> bytes;
    MNN::Interpreter* interpreter = nullptr;
    MNN::Session* session = nullptr;
    MNN::Tensor* input = nullptr;

    ~CandidateModel()
    {
        input = nullptr;
        if (interpreter != nullptr && session != nullptr) {
            interpreter->releaseSession(session);
        }
        session = nullptr;
        if (interpreter != nullptr) {
            interpreter->releaseModel();
            MNN::Interpreter::destroy(interpreter);
        }
        interpreter = nullptr;
    }
};

std::vector<float> Run(MNN::Interpreter* interpreter, MNN::Session* session, MNN::Tensor* input,
                       const std::vector<float>& values)
{
    ValidateTensor(input, kInputShape, kInputName);
    MNN::Tensor hostInput(input, MNN::Tensor::CAFFE, true);
    if (hostInput.host<float>() == nullptr || static_cast<size_t>(hostInput.elementSize()) != kInputElementCount ||
        hostInput.usize() != kInputElementCount * sizeof(float)) {
        throw std::runtime_error("MNN allocated an invalid object-detection input host tensor.");
    }
    std::memcpy(hostInput.host<float>(), values.data(), kInputElementCount * sizeof(float));
    if (!input->copyFromHostTensor(&hostInput)) {
        throw std::runtime_error("MNN failed to copy the object-detection input tensor.");
    }
    const MNN::ErrorCode status = interpreter->runSession(session);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error("MNN object-detection inference failed with code " +
                                 std::to_string(static_cast<int>(status)) + '.');
    }

    MNN::Tensor* output = interpreter->getSessionOutput(session, kOutputName);
    ValidateTensor(output, kOutputShape, kOutputName);
    MNN::Tensor hostOutput(output, MNN::Tensor::CAFFE, true);
    if (hostOutput.host<float>() == nullptr || static_cast<size_t>(hostOutput.elementSize()) != kOutputElementCount ||
        hostOutput.usize() != kOutputElementCount * sizeof(float)) {
        throw std::runtime_error("MNN allocated an invalid object-detection output host tensor.");
    }
    if (!output->copyToHostTensor(&hostOutput)) {
        throw std::runtime_error("MNN failed to copy the object-detection output tensor.");
    }
    std::vector<float> result(hostOutput.host<float>(), hostOutput.host<float>() + kOutputElementCount);
    if (!std::all_of(result.begin(), result.end(), [](float value) { return std::isfinite(value); })) {
        throw std::runtime_error("Object-detection output contains a non-finite value.");
    }
    return result;
}
}

ObjectDetectionMnnSession::~ObjectDetectionMnnSession()
{
    Release();
}

ObjectDetectionModelInfo ObjectDetectionMnnSession::LoadModel(const uint8_t* bytes, size_t size)
{
    if (bytes == nullptr || size == 0) {
        throw std::invalid_argument("Object-detection model bytes must not be empty.");
    }

    CandidateModel candidate;
    candidate.bytes.assign(bytes, bytes + size);
    candidate.interpreter = MNN::Interpreter::createFromBuffer(candidate.bytes.data(), candidate.bytes.size());
    if (candidate.interpreter == nullptr) {
        throw std::runtime_error("MNN rejected the object-detection model buffer.");
    }
    MNN::ScheduleConfig config;
    config.type = MNN_FORWARD_CPU;
    config.numThread = 1;
    candidate.session = candidate.interpreter->createSession(config);
    if (candidate.session == nullptr) {
        throw std::runtime_error("MNN failed to create the object-detection CPU session.");
    }

    const auto& inputs = candidate.interpreter->getSessionInputAll(candidate.session);
    const auto inputEntry = inputs.find(kInputName);
    if (inputs.size() != 1 || inputEntry == inputs.end()) {
        throw std::runtime_error("Object-detection model input name mismatch; expected only data.");
    }
    candidate.input = inputEntry->second;
    ValidateTensor(candidate.input, kInputShape, kInputName);
    const auto& outputs = candidate.interpreter->getSessionOutputAll(candidate.session);
    const auto outputEntry = outputs.find(kOutputName);
    if (outputs.size() != 1 || outputEntry == outputs.end()) {
        throw std::runtime_error("Object-detection model output name mismatch; expected only output.");
    }
    ValidateTensor(outputEntry->second, kOutputShape, kOutputName);

    const std::vector<float> probeInput(kInputElementCount, 0.0F);
    const std::vector<float> probeOutput = Run(candidate.interpreter, candidate.session, candidate.input, probeInput);
    if (!std::any_of(probeOutput.begin(), probeOutput.end(), [](float value) { return std::fabs(value) > 1.0e-12F; })) {
        throw std::runtime_error("Object-detection model probe produced only zero values.");
    }

    ObjectDetectionModelInfo modelInfo{kInputName, {1, 3, 320, 320}, kOutputName, {1, 2125, 112}};

    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
    modelBytes_.swap(candidate.bytes);
    interpreter_ = candidate.interpreter;
    session_ = candidate.session;
    input_ = candidate.input;
    candidate.interpreter = nullptr;
    candidate.session = nullptr;
    candidate.input = nullptr;
    return modelInfo;
}

std::vector<float> ObjectDetectionMnnSession::Predict(const std::vector<float>& input)
{
    if (input.size() != kInputElementCount) {
        throw std::invalid_argument("Object-detection input must contain exactly 307200 float32 values.");
    }
    if (!std::all_of(input.begin(), input.end(), [](float value) { return std::isfinite(value); })) {
        throw std::invalid_argument("Object-detection input contains a non-finite value.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    if (interpreter_ == nullptr || session_ == nullptr || input_ == nullptr) {
        throw std::runtime_error("Object-detection model is not loaded.");
    }
    return Run(interpreter_, session_, input_, input);
}

void ObjectDetectionMnnSession::Release() noexcept
{
    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseLocked();
}

void ObjectDetectionMnnSession::ReleaseLocked() noexcept
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
