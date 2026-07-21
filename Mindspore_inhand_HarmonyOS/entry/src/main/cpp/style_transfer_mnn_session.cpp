#include "style_transfer_mnn_session.h"

#include <MNN/Interpreter.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>

namespace {
constexpr size_t kStyleElementCount = 1U * 256U * 256U * 3U;
constexpr size_t kContentElementCount = 1U * 384U * 384U * 3U;
constexpr size_t kEmbeddingElementCount = 100U;
constexpr size_t kOutputElementCount = kContentElementCount;
constexpr const char* kStyleInputName = "style_image";
constexpr const char* kEmbeddingName = "mobilenet_conv/Conv/BiasAdd";
constexpr const char* kContentInputName = "content_image";
constexpr const char* kOutputName = "transformer/expand/conv3/conv/Sigmoid";
const std::vector<int> kStyleShape = {1, 256, 256, 3};
const std::vector<int> kContentShape = {1, 384, 384, 3};
const std::vector<int> kEmbeddingShape = {1, 1, 1, 100};
const std::vector<int> kOutputShape = {1, 384, 384, 3};

bool IsFloat32(const MNN::Tensor* tensor)
{
    if (tensor == nullptr) {
        return false;
    }
    const halide_type_t type = tensor->getType();
    return type.code == halide_type_float && type.bits == 32 && type.lanes == 1;
}

void ValidateTensor(const MNN::Tensor* tensor, const std::vector<int>& shape, const char* name)
{
    if (tensor == nullptr) {
        throw std::runtime_error(std::string("Missing style-transfer tensor: ") + name);
    }
    if (!IsFloat32(tensor)) {
        throw std::runtime_error(std::string("Style-transfer tensor is not float32: ") + name);
    }
    if (tensor->getDimensionType() != MNN::Tensor::TENSORFLOW) {
        throw std::runtime_error(std::string("Style-transfer tensor is not NHWC: ") + name);
    }
    if (tensor->shape() != shape) {
        throw std::runtime_error(std::string("Style-transfer tensor shape mismatch: ") + name);
    }
}

bool AllFinite(const std::vector<float>& values)
{
    return std::all_of(values.begin(), values.end(), [](float value) { return std::isfinite(value); });
}

void ValidateUnitInput(const std::vector<float>& values, size_t expectedCount, const char* name)
{
    if (values.size() != expectedCount) {
        throw std::invalid_argument(std::string(name) + " has an unexpected float count.");
    }
    if (!AllFinite(values) || !std::all_of(values.begin(), values.end(), [](float value) {
            return value >= 0.0F && value <= 1.0F;
        })) {
        throw std::invalid_argument(std::string(name) + " must contain finite values in [0,1].");
    }
}

std::vector<float> CopyOutput(MNN::Tensor* output, const std::vector<int>& shape,
                              size_t elementCount, const char* name)
{
    ValidateTensor(output, shape, name);
    MNN::Tensor host(output, MNN::Tensor::TENSORFLOW, true);
    if (host.host<float>() == nullptr || static_cast<size_t>(host.elementSize()) != elementCount ||
        host.usize() != elementCount * sizeof(float)) {
        throw std::runtime_error(std::string("MNN allocated an invalid host output: ") + name);
    }
    if (!output->copyToHostTensor(&host)) {
        throw std::runtime_error(std::string("MNN failed to copy output: ") + name);
    }
    std::vector<float> result(host.host<float>(), host.host<float>() + elementCount);
    if (!AllFinite(result)) {
        throw std::runtime_error(std::string("Style-transfer output contains non-finite values: ") + name);
    }
    return result;
}

void CopyInput(MNN::Tensor* input, const std::vector<int>& shape,
               const std::vector<float>& values, const char* name)
{
    ValidateTensor(input, shape, name);
    MNN::Tensor host(input, MNN::Tensor::TENSORFLOW, true);
    if (host.host<float>() == nullptr || static_cast<size_t>(host.elementSize()) != values.size() ||
        host.usize() != values.size() * sizeof(float)) {
        throw std::runtime_error(std::string("MNN allocated an invalid host input: ") + name);
    }
    std::memcpy(host.host<float>(), values.data(), values.size() * sizeof(float));
    if (!input->copyFromHostTensor(&host)) {
        throw std::runtime_error(std::string("MNN failed to copy input: ") + name);
    }
}
}

struct StyleTransferMnnStage {
    std::vector<uint8_t> bytes;
    MNN::Interpreter* interpreter = nullptr;
    MNN::Session* session = nullptr;
    std::map<std::string, MNN::Tensor*> inputs;

    ~StyleTransferMnnStage()
    {
        inputs.clear();
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

namespace {
std::unique_ptr<StyleTransferMnnStage> BuildStage(
    const uint8_t* bytes,
    size_t size,
    const std::map<std::string, std::vector<int>>& expectedInputs,
    const char* outputName,
    const std::vector<int>& outputShape)
{
    if (bytes == nullptr || size == 0) {
        throw std::invalid_argument("Style-transfer model bytes must not be empty.");
    }
    auto stage = std::make_unique<StyleTransferMnnStage>();
    stage->bytes.assign(bytes, bytes + size);
    stage->interpreter = MNN::Interpreter::createFromBuffer(stage->bytes.data(), stage->bytes.size());
    if (stage->interpreter == nullptr) {
        throw std::runtime_error("MNN rejected a style-transfer model buffer.");
    }
    MNN::ScheduleConfig config;
    config.type = MNN_FORWARD_CPU;
    config.numThread = 2;
    stage->session = stage->interpreter->createSession(config);
    if (stage->session == nullptr) {
        throw std::runtime_error("MNN failed to create a style-transfer CPU session.");
    }
    const auto& inputs = stage->interpreter->getSessionInputAll(stage->session);
    if (inputs.size() != expectedInputs.size()) {
        throw std::runtime_error("Style-transfer model input count mismatch.");
    }
    for (const auto& expected : expectedInputs) {
        const auto found = inputs.find(expected.first);
        if (found == inputs.end()) {
            throw std::runtime_error("Style-transfer model input name mismatch: " + expected.first);
        }
        ValidateTensor(found->second, expected.second, expected.first.c_str());
        stage->inputs.emplace(expected.first, found->second);
    }
    const auto& outputs = stage->interpreter->getSessionOutputAll(stage->session);
    const auto output = outputs.find(outputName);
    if (outputs.size() != 1 || output == outputs.end()) {
        throw std::runtime_error(std::string("Style-transfer model output name mismatch: ") + outputName);
    }
    ValidateTensor(output->second, outputShape, outputName);
    return stage;
}

std::unique_ptr<StyleTransferMnnStage> BuildPredict(const uint8_t* bytes, size_t size)
{
    return BuildStage(bytes, size, {{kStyleInputName, kStyleShape}}, kEmbeddingName, kEmbeddingShape);
}

std::unique_ptr<StyleTransferMnnStage> BuildTransfer(const uint8_t* bytes, size_t size)
{
    return BuildStage(bytes, size,
                      {{kContentInputName, kContentShape}, {kEmbeddingName, kEmbeddingShape}},
                      kOutputName, kOutputShape);
}

std::vector<float> RunPredict(StyleTransferMnnStage& stage, const std::vector<float>& styleInput)
{
    CopyInput(stage.inputs.at(kStyleInputName), kStyleShape, styleInput, kStyleInputName);
    const MNN::ErrorCode status = stage.interpreter->runSession(stage.session);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error("MNN style prediction failed with code " +
                                 std::to_string(static_cast<int>(status)) + '.');
    }
    return CopyOutput(stage.interpreter->getSessionOutput(stage.session, kEmbeddingName),
                      kEmbeddingShape, kEmbeddingElementCount, kEmbeddingName);
}

std::vector<float> RunTransfer(StyleTransferMnnStage& stage, const std::vector<float>& contentInput,
                               const std::vector<float>& embedding)
{
    CopyInput(stage.inputs.at(kContentInputName), kContentShape, contentInput, kContentInputName);
    CopyInput(stage.inputs.at(kEmbeddingName), kEmbeddingShape, embedding, kEmbeddingName);
    const MNN::ErrorCode status = stage.interpreter->runSession(stage.session);
    if (status != MNN::NO_ERROR) {
        throw std::runtime_error("MNN style transform failed with code " +
                                 std::to_string(static_cast<int>(status)) + '.');
    }
    std::vector<float> output = CopyOutput(stage.interpreter->getSessionOutput(stage.session, kOutputName),
                                           kOutputShape, kOutputElementCount, kOutputName);
    if (!std::all_of(output.begin(), output.end(), [](float value) {
            return value >= 0.0F && value <= 1.0F;
        })) {
        throw std::runtime_error("Style-transfer output is outside [0,1].");
    }
    return output;
}

void ProbePredict(StyleTransferMnnStage& stage)
{
    const std::vector<float> output = RunPredict(stage, std::vector<float>(kStyleElementCount, 0.5F));
    if (!std::any_of(output.begin(), output.end(), [](float value) { return std::fabs(value) > 1.0e-7F; })) {
        throw std::runtime_error("Style prediction probe produced only zero values.");
    }
}

void ProbeTransfer(StyleTransferMnnStage& stage)
{
    const std::vector<float> output = RunTransfer(stage, std::vector<float>(kContentElementCount, 0.5F),
                                                  std::vector<float>(kEmbeddingElementCount, 0.0F));
    if (!std::any_of(output.begin(), output.end(), [](float value) { return std::fabs(value) > 1.0e-7F; })) {
        throw std::runtime_error("Style transform probe produced only zero values.");
    }
}

void ProbePair(StyleTransferMnnStage& predict, StyleTransferMnnStage& transfer)
{
    const std::vector<float> embedding = RunPredict(predict, std::vector<float>(kStyleElementCount, 0.5F));
    const std::vector<float> output = RunTransfer(transfer, std::vector<float>(kContentElementCount, 0.5F), embedding);
    if (output.size() != kOutputElementCount) {
        throw std::runtime_error("Style-transfer pair probe produced an invalid output.");
    }
}
}

StyleTransferMnnSession::StyleTransferMnnSession() = default;

StyleTransferMnnSession::~StyleTransferMnnSession()
{
    Release();
}

void StyleTransferMnnSession::LoadModels(const uint8_t* predictBytes, size_t predictSize,
                                         const uint8_t* transferBytes, size_t transferSize)
{
    auto candidatePredict = BuildPredict(predictBytes, predictSize);
    auto candidateTransfer = BuildTransfer(transferBytes, transferSize);
    ProbePair(*candidatePredict, *candidateTransfer);

    std::lock_guard<std::mutex> lock(mutex_);
    predict_.swap(candidatePredict);
    transfer_.swap(candidateTransfer);
}

bool StyleTransferMnnSession::ValidatePredictModel(const uint8_t* bytes, size_t size) noexcept
{
    try {
        auto candidate = BuildPredict(bytes, size);
        ProbePredict(*candidate);
        return true;
    } catch (...) {
        return false;
    }
}

bool StyleTransferMnnSession::ValidateTransferModel(const uint8_t* bytes, size_t size) noexcept
{
    try {
        auto candidate = BuildTransfer(bytes, size);
        ProbeTransfer(*candidate);
        return true;
    } catch (...) {
        return false;
    }
}

bool StyleTransferMnnSession::ValidateModelPair(const uint8_t* predictBytes, size_t predictSize,
                                                const uint8_t* transferBytes, size_t transferSize) noexcept
{
    try {
        auto candidatePredict = BuildPredict(predictBytes, predictSize);
        auto candidateTransfer = BuildTransfer(transferBytes, transferSize);
        ProbePair(*candidatePredict, *candidateTransfer);
        return true;
    } catch (...) {
        return false;
    }
}

StyleTransferMnnOutput StyleTransferMnnSession::Run(const std::vector<float>& styleInput,
                                                    const std::vector<float>& contentInput)
{
    ValidateUnitInput(styleInput, kStyleElementCount, "Style input");
    ValidateUnitInput(contentInput, kContentElementCount, "Content input");
    std::lock_guard<std::mutex> lock(mutex_);
    if (predict_ == nullptr || transfer_ == nullptr) {
        throw std::runtime_error("Style-transfer model pair is not loaded.");
    }
    const auto predictStarted = std::chrono::steady_clock::now();
    std::vector<float> embedding = RunPredict(*predict_, styleInput);
    const auto transferStarted = std::chrono::steady_clock::now();
    std::vector<float> output = RunTransfer(*transfer_, contentInput, embedding);
    const auto completed = std::chrono::steady_clock::now();
    return {
        std::move(output),
        std::chrono::duration_cast<std::chrono::milliseconds>(transferStarted - predictStarted).count(),
        std::chrono::duration_cast<std::chrono::milliseconds>(completed - transferStarted).count()
    };
}

void StyleTransferMnnSession::Release() noexcept
{
    std::lock_guard<std::mutex> lock(mutex_);
    predict_.reset();
    transfer_.reset();
}
