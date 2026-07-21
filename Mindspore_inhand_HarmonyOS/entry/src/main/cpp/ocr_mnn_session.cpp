#include "ocr_mnn_session.h"

#include <MNN/Interpreter.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <numeric>
#include <stdexcept>
#include <string>

namespace {
const std::vector<int> kDetectorInputShape = {1, 3, 960, 960};
const std::vector<int> kDetectorOutputShape = {1, 1, 960, 960};
const std::vector<int> kRecognizerInputShape = {1, 3, 48, 320};
const std::vector<int> kRecognizerOutputShape = {1, 40, 6625};
constexpr const char* kDetectorInputName = "x";
constexpr const char* kDetectorOutputName = "sigmoid_0.tmp_0";
constexpr const char* kRecognizerInputName = "x";
constexpr const char* kRecognizerOutputName = "softmax_5.tmp_0";

bool IsFloat32(const MNN::Tensor* tensor)
{
    const halide_type_t type = tensor->getType();
    return type.code == halide_type_float && type.bits == 32 && type.lanes == 1;
}

size_t ElementCount(const std::vector<int>& shape)
{
    return std::accumulate(shape.begin(), shape.end(), static_cast<size_t>(1),
        [](size_t count, int dimension) { return count * static_cast<size_t>(dimension); });
}

void ValidateTensor(const MNN::Tensor* tensor, const std::vector<int>& shape, const char* label)
{
    if (tensor == nullptr || !IsFloat32(tensor) || tensor->shape() != shape) {
        std::string actual = "missing";
        if (tensor != nullptr) {
            actual = "shape=";
            for (const int dimension : tensor->shape()) {
                actual += std::to_string(dimension) + ',';
            }
            const halide_type_t type = tensor->getType();
            actual += " type=" + std::to_string(type.code) + '/' + std::to_string(type.bits);
        }
        throw std::runtime_error(std::string("PP-OCR tensor contract mismatch: ") + label + " " + actual);
    }
}

void LoadModel(OcrMnnSession::Model& model, const uint8_t* bytes, size_t size,
               const std::vector<int>& inputShape, const std::vector<int>& outputShape,
               const char* inputName, const char* outputName, const char* label)
{
    if (bytes == nullptr || size == 0) {
        throw std::invalid_argument(std::string("PP-OCR model bytes are empty: ") + label);
    }
    model.bytes.assign(bytes, bytes + size);
    model.interpreter = MNN::Interpreter::createFromBuffer(model.bytes.data(), model.bytes.size());
    if (model.interpreter == nullptr) {
        throw std::runtime_error(std::string("MNN rejected PP-OCR model: ") + label);
    }
    MNN::ScheduleConfig config;
    config.type = MNN_FORWARD_CPU;
    config.numThread = 2;
    model.session = model.interpreter->createSession(config);
    if (model.session == nullptr) {
        throw std::runtime_error(std::string("MNN failed to create PP-OCR session: ") + label);
    }
    const auto& inputs = model.interpreter->getSessionInputAll(model.session);
    const auto entry = inputs.find(inputName);
    if (inputs.size() != 1 || entry == inputs.end()) {
        throw std::runtime_error(std::string("PP-OCR input name mismatch: ") + label);
    }
  model.input = entry->second;
  model.interpreter->resizeTensor(model.input, inputShape);
  model.interpreter->resizeSession(model.session);
  ValidateTensor(model.input, inputShape, inputName);
    ValidateTensor(model.interpreter->getSessionOutput(model.session, outputName), outputShape, outputName);
}
}

OcrMnnSession::~OcrMnnSession()
{
    Release();
}

void OcrMnnSession::LoadModels(const uint8_t* detectorBytes, size_t detectorSize,
                               const uint8_t* recognizerBytes, size_t recognizerSize)
{
    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseModel(detector_);
    ReleaseModel(recognizer_);
    try {
        LoadModel(detector_, detectorBytes, detectorSize, kDetectorInputShape, kDetectorOutputShape,
                  kDetectorInputName, kDetectorOutputName, "detector");
        LoadModel(recognizer_, recognizerBytes, recognizerSize, kRecognizerInputShape, kRecognizerOutputShape,
                  kRecognizerInputName, kRecognizerOutputName, "recognizer");
    } catch (...) {
        ReleaseModel(detector_);
        ReleaseModel(recognizer_);
        throw;
    }
}

std::vector<float> OcrMnnSession::PredictDetector(const std::vector<float>& input)
{
    std::lock_guard<std::mutex> lock(mutex_);
    return Predict(detector_, input, kDetectorInputShape, kDetectorOutputShape,
                   kDetectorOutputName, "detector");
}

std::vector<float> OcrMnnSession::PredictRecognizer(const std::vector<float>& input)
{
    std::lock_guard<std::mutex> lock(mutex_);
    return Predict(recognizer_, input, kRecognizerInputShape, kRecognizerOutputShape,
                   kRecognizerOutputName, "recognizer");
}

std::vector<float> OcrMnnSession::Predict(Model& model, const std::vector<float>& input,
                                           const std::vector<int>& inputShape,
                                           const std::vector<int>& outputShape,
                                           const char* outputName, const char* label)
{
    const size_t inputCount = ElementCount(inputShape);
    const size_t outputCount = ElementCount(outputShape);
    if (input.size() != inputCount || !std::all_of(input.begin(), input.end(), [](float value) { return std::isfinite(value); })) {
        throw std::invalid_argument(std::string("PP-OCR input contract mismatch: ") + label);
    }
    if (model.interpreter == nullptr || model.session == nullptr || model.input == nullptr) {
        throw std::runtime_error(std::string("PP-OCR model is not loaded: ") + label);
    }
    MNN::Tensor hostInput(model.input, MNN::Tensor::CAFFE, true);
    if (hostInput.host<float>() == nullptr || hostInput.elementSize() != inputCount) {
        throw std::runtime_error(std::string("MNN allocated invalid PP-OCR input: ") + label);
    }
    std::memcpy(hostInput.host<float>(), input.data(), inputCount * sizeof(float));
    if (!model.input->copyFromHostTensor(&hostInput)) {
        throw std::runtime_error(std::string("MNN failed to copy PP-OCR input: ") + label);
    }
    const MNN::ErrorCode status = model.interpreter->runSession(model.session);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error(std::string("MNN PP-OCR inference failed: ") + label);
    }
    MNN::Tensor* output = model.interpreter->getSessionOutput(model.session, outputName);
    ValidateTensor(output, outputShape, outputName);
    MNN::Tensor hostOutput(output, MNN::Tensor::CAFFE, true);
    const bool hasHost = hostOutput.host<float>() != nullptr;
    const bool hasExpectedSize = hostOutput.elementSize() == outputCount;
    const bool copied = hasHost && hasExpectedSize && output->copyToHostTensor(&hostOutput);
    if (!copied) {
        throw std::runtime_error(std::string("MNN failed to read PP-OCR output: ") + label +
            " host=" + std::to_string(hasHost) +
            " elements=" + std::to_string(hostOutput.elementSize()) +
            " expected=" + std::to_string(outputCount));
    }
    std::vector<float> result(hostOutput.host<float>(), hostOutput.host<float>() + outputCount);
    if (!std::all_of(result.begin(), result.end(), [](float value) { return std::isfinite(value); })) {
        throw std::runtime_error(std::string("PP-OCR output is non-finite: ") + label);
    }
    return result;
}

void OcrMnnSession::Release() noexcept
{
    std::lock_guard<std::mutex> lock(mutex_);
    ReleaseModel(detector_);
    ReleaseModel(recognizer_);
}

void OcrMnnSession::ReleaseModel(Model& model) noexcept
{
    model.input = nullptr;
    if (model.interpreter != nullptr && model.session != nullptr) {
        model.interpreter->releaseSession(model.session);
    }
    model.session = nullptr;
    if (model.interpreter != nullptr) {
        model.interpreter->releaseModel();
        MNN::Interpreter::destroy(model.interpreter);
    }
    model.interpreter = nullptr;
    std::vector<uint8_t>().swap(model.bytes);
}
