#include "segmentation_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
constexpr size_t kInputElementCount = 1U * 256U * 256U * 3U;
constexpr size_t kInputByteCount = kInputElementCount * sizeof(float);
constexpr const char* kUnknownNativeError = "Unknown native segmentation error.";
SegmentationMnnSession g_session;

void Check(napi_env env, napi_status status, const char* operation)
{
    if (status == napi_ok) {
        return;
    }
    const napi_extended_error_info* info = nullptr;
    napi_get_last_error_info(env, &info);
    std::string message(operation);
    if (info != nullptr && info->error_message != nullptr) {
        message += ": ";
        message += info->error_message;
    }
    throw std::runtime_error(message);
}

void Throw(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) == napi_ok && !pending) {
        napi_throw_error(env, nullptr, message);
    }
}

napi_value String(napi_env env, const std::string& value)
{
    napi_value result = nullptr;
    Check(env, napi_create_string_utf8(env, value.c_str(), value.size(), &result), "create string");
    return result;
}

napi_value Shape(napi_env env, const std::vector<int32_t>& shape)
{
    napi_value result = nullptr;
    Check(env, napi_create_array_with_length(env, shape.size(), &result), "create shape");
    for (size_t index = 0; index < shape.size(); ++index) {
        napi_value dimension = nullptr;
        Check(env, napi_create_int32(env, shape[index], &dimension), "create dimension");
        Check(env, napi_set_element(env, result, index, dimension), "set dimension");
    }
    return result;
}

void Set(napi_env env, napi_value object, const char* name, napi_value value)
{
    Check(env, napi_set_named_property(env, object, name, value), "set property");
}

napi_value LoadModelImpl(napi_env env, napi_callback_info callbackInfo)
{
    size_t argc = 1;
    napi_value argument = nullptr;
    Check(env, napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr), "read loadModel arguments");
    bool isTypedArray = false;
    if (argc != 1 || napi_is_typedarray(env, argument, &isTypedArray) != napi_ok || !isTypedArray) {
        throw std::invalid_argument("loadModel expects one Uint8Array.");
    }
    napi_typedarray_type type = napi_int8_array;
    size_t length = 0;
    void* data = nullptr;
    Check(env, napi_get_typedarray_info(env, argument, &type, &length, &data, nullptr, nullptr), "read model bytes");
    if (type != napi_uint8_array) {
        throw std::invalid_argument("loadModel expects one Uint8Array.");
    }
    const SegmentationModelInfo info = g_session.LoadModel(static_cast<const uint8_t*>(data), length);
    napi_value result = nullptr;
    Check(env, napi_create_object(env, &result), "create model info");
    Set(env, result, "inputName", String(env, info.inputName));
    Set(env, result, "inputShape", Shape(env, info.inputShape));
    Set(env, result, "outputName", String(env, info.outputName));
    Set(env, result, "outputShape", Shape(env, info.outputShape));
    return result;
}

napi_value LoadModel(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return LoadModelImpl(env, callbackInfo);
    } catch (const std::exception& error) {
        Throw(env, error.what());
    } catch (...) {
        Throw(env, kUnknownNativeError);
    }
    return nullptr;
}

struct PredictWork {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    std::vector<float> input;
    std::vector<float> output;
    std::exception_ptr error;
};

void ExecutePredict(napi_env, void* raw) noexcept
{
    auto* work = static_cast<PredictWork*>(raw);
    try {
        work->output = g_session.Predict(work->input);
    } catch (...) {
        work->error = std::current_exception();
    }
}

napi_value ErrorValue(napi_env env, const char* message)
{
    napi_value text = nullptr;
    napi_value error = nullptr;
    Check(env, napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text), "create error text");
    Check(env, napi_create_error(env, nullptr, text, &error), "create error");
    return error;
}

bool RejectDeferredNoThrow(napi_env env, napi_deferred deferred, const char* message) noexcept
{
    napi_value text = nullptr;
    napi_value error = nullptr;
    return napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text) == napi_ok &&
        napi_create_error(env, nullptr, text, &error) == napi_ok &&
        napi_reject_deferred(env, deferred, error) == napi_ok;
}

void CompletePredict(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<PredictWork> work(static_cast<PredictWork*>(raw));
    try {
        if (status != napi_ok) {
            Check(env, napi_reject_deferred(env, work->deferred, ErrorValue(env, "Native segmentation inference was cancelled.")),
                  "reject cancelled prediction");
        } else if (work->error != nullptr) {
            try {
                std::rethrow_exception(work->error);
            } catch (const std::exception& error) {
                Check(env, napi_reject_deferred(env, work->deferred, ErrorValue(env, error.what())),
                      "reject failed prediction");
            } catch (...) {
                Check(env, napi_reject_deferred(env, work->deferred, ErrorValue(env, kUnknownNativeError)),
                      "reject unknown prediction failure");
            }
        } else {
            napi_value arrayBuffer = nullptr;
            void* destination = nullptr;
            const size_t byteLength = work->output.size() * sizeof(float);
            Check(env, napi_create_arraybuffer(env, byteLength, &destination, &arrayBuffer), "create output buffer");
            if (byteLength != 0 && destination == nullptr) {
                throw std::runtime_error("NAPI returned a null segmentation output buffer.");
            }
            std::memcpy(destination, work->output.data(), byteLength);
            Check(env, napi_resolve_deferred(env, work->deferred, arrayBuffer), "resolve prediction");
        }
    } catch (const std::exception& error) {
        if (!RejectDeferredNoThrow(env, work->deferred, error.what())) {
            Throw(env, kUnknownNativeError);
        }
    } catch (...) {
        if (!RejectDeferredNoThrow(env, work->deferred, kUnknownNativeError)) {
            Throw(env, kUnknownNativeError);
        }
    }
    if (work->work != nullptr) {
        napi_delete_async_work(env, work->work);
        work->work = nullptr;
    }
}

napi_value PredictImpl(napi_env env, napi_callback_info callbackInfo)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create prediction promise");
    size_t argc = 1;
    napi_value argument = nullptr;
    bool isTypedArray = false;
    napi_typedarray_type type = napi_int8_array;
    size_t length = 0;
    void* data = nullptr;
    napi_value arrayBuffer = nullptr;
    size_t byteOffset = 0;
    const napi_status argumentStatus = napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr);
    const napi_status typedArrayStatus = argumentStatus == napi_ok && argc == 1 ?
        napi_is_typedarray(env, argument, &isTypedArray) : napi_invalid_arg;
    const napi_status infoStatus = typedArrayStatus == napi_ok && isTypedArray ?
        napi_get_typedarray_info(env, argument, &type, &length, &data, &arrayBuffer, &byteOffset) : napi_invalid_arg;
    napi_value logicalLengthValue = nullptr;
    uint32_t logicalLength = 0;
    const napi_status logicalLengthPropertyStatus = infoStatus == napi_ok ?
        napi_get_named_property(env, argument, "length", &logicalLengthValue) : napi_invalid_arg;
    const napi_status logicalLengthStatus = logicalLengthPropertyStatus == napi_ok ?
        napi_get_value_uint32(env, logicalLengthValue, &logicalLength) : napi_invalid_arg;
    void* backingData = nullptr;
    size_t backingByteLength = 0;
    const napi_status backingStatus = infoStatus == napi_ok ?
        napi_get_arraybuffer_info(env, arrayBuffer, &backingData, &backingByteLength) : napi_invalid_arg;
    // ponytail: API24 reports typedarray_info length in bytes; JS-visible length is logical elements.
    const bool supportedInfoLength = length == kInputElementCount || length == kInputByteCount;
    const bool exactLogicalLength = logicalLengthStatus == napi_ok && logicalLength == kInputElementCount;
    const bool readableBacking = backingStatus == napi_ok && data != nullptr && backingData != nullptr &&
        byteOffset <= backingByteLength && backingByteLength - byteOffset >= kInputByteCount;
    if (argumentStatus != napi_ok || argc != 1 || typedArrayStatus != napi_ok || !isTypedArray ||
        infoStatus != napi_ok || type != napi_float32_array || !exactLogicalLength || !supportedInfoLength ||
        !readableBacking) {
        const std::string message = "predict expects exactly 196608 float32 values; argc=" +
            std::to_string(argc) + " typed=" + std::to_string(isTypedArray ? 1 : 0) + " type=" +
            std::to_string(static_cast<int>(type)) + " logicalLength=" + std::to_string(logicalLength) +
            " infoLength=" + std::to_string(length) + '.';
        Check(env, napi_reject_deferred(env, deferred,
              ErrorValue(env, message.c_str())), "reject invalid input");
        return promise;
    }
    auto work = std::make_unique<PredictWork>();
    work->deferred = deferred;
    const float* values = static_cast<const float*>(data);
    work->input.assign(values, values + kInputElementCount);
    napi_value resourceName = String(env, "segmentation_mnn_predict");
    const napi_status createStatus = napi_create_async_work(
        env, nullptr, resourceName, ExecutePredict, CompletePredict, work.get(), &work->work);
    if (createStatus != napi_ok) {
        if (!RejectDeferredNoThrow(env, deferred, "Unable to create native segmentation work.")) {
            Throw(env, kUnknownNativeError);
        }
        return promise;
    }
    const napi_status queueStatus = napi_queue_async_work(env, work->work);
    if (queueStatus != napi_ok) {
        napi_delete_async_work(env, work->work);
        work->work = nullptr;
        if (!RejectDeferredNoThrow(env, deferred, "Unable to queue native segmentation work.")) {
            Throw(env, kUnknownNativeError);
        }
        return promise;
    }
    work.release();
    return promise;
}

napi_value Predict(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return PredictImpl(env, callbackInfo);
    } catch (const std::exception& error) {
        Throw(env, error.what());
    } catch (...) {
        Throw(env, kUnknownNativeError);
    }
    return nullptr;
}

napi_value Release(napi_env env, napi_callback_info) noexcept
{
    g_session.Release();
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"loadModel", nullptr, LoadModel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predict", nullptr, Predict, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, Release, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    if (napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties) != napi_ok) {
        return nullptr;
    }
    return exports;
}
}

static napi_module segmentationModule = {
    1, 0, nullptr, Init, "segmentation_mnn", nullptr, {0},
};

extern "C" __attribute__((constructor)) void RegisterSegmentationMnnModule()
{
    napi_module_register(&segmentationModule);
}
