#include "object_detection_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
constexpr size_t kInputElementCount = 307200;
constexpr const char* kUnknownNativeError = "Unknown native object-detection error.";
ObjectDetectionMnnSession g_session;

[[noreturn]] void FatalNapi(const char* location, const char* message) noexcept
{
    napi_fatal_error(location, NAPI_AUTO_LENGTH, message, NAPI_AUTO_LENGTH);
}

void EstablishExceptionOrFatal(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok) {
        FatalNapi("object_detection_mnn", "Could not inspect the NAPI exception state.");
    }
    if (!pending && napi_throw_error(env, nullptr, message) != napi_ok) {
        FatalNapi("object_detection_mnn", "Could not establish a JavaScript exception.");
    }
}

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

napi_value String(napi_env env, const std::string& value)
{
    napi_value result = nullptr;
    Check(env, napi_create_string_utf8(env, value.c_str(), value.size(), &result), "create string");
    return result;
}

void Set(napi_env env, napi_value object, const char* name, napi_value value)
{
    Check(env, napi_set_named_property(env, object, name, value), "set property");
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

napi_value ModelInfoValue(napi_env env, const ObjectDetectionModelInfo& info)
{
    napi_value result = nullptr;
    Check(env, napi_create_object(env, &result), "create model info");
    Set(env, result, "inputName", String(env, info.inputName));
    Set(env, result, "inputShape", Shape(env, info.inputShape));
    Set(env, result, "outputName", String(env, info.outputName));
    Set(env, result, "outputShape", Shape(env, info.outputShape));
    return result;
}

uint32_t VisibleLength(napi_env env, napi_value typedArray)
{
    napi_value lengthValue = nullptr;
    uint32_t length = 0;
    Check(env, napi_get_named_property(env, typedArray, "length", &lengthValue), "read typed-array length");
    Check(env, napi_get_value_uint32(env, lengthValue, &length), "decode typed-array length");
    return length;
}

struct TypedArrayView {
    void* data = nullptr;
    size_t visibleLength = 0;
};

TypedArrayView ReadTypedArray(napi_env env, napi_value value, napi_typedarray_type expectedType,
                              size_t elementSize, const char* message)
{
    bool isTypedArray = false;
    if (napi_is_typedarray(env, value, &isTypedArray) != napi_ok || !isTypedArray) {
        throw std::invalid_argument(message);
    }
    napi_typedarray_type type;
    size_t reportedLength = 0;
    void* data = nullptr;
    napi_value arrayBuffer = nullptr;
    size_t byteOffset = 0;
    Check(env, napi_get_typedarray_info(env, value, &type, &reportedLength, &data, &arrayBuffer, &byteOffset),
          "inspect typed array");
    if (type != expectedType) {
        throw std::invalid_argument(message);
    }
    const size_t visibleLength = VisibleLength(env, value);
    void* backing = nullptr;
    size_t backingBytes = 0;
    Check(env, napi_get_arraybuffer_info(env, arrayBuffer, &backing, &backingBytes), "inspect array buffer");
    if (byteOffset > backingBytes || visibleLength > (backingBytes - byteOffset) / elementSize ||
        (reportedLength != visibleLength && reportedLength != visibleLength * elementSize) ||
        (visibleLength != 0 && data == nullptr)) {
        throw std::invalid_argument(message);
    }
    return {data, visibleLength};
}

napi_status CreateErrorValue(napi_env env, const char* message, napi_value* result) noexcept
{
    napi_value text = nullptr;
    napi_status status = napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
    return status == napi_ok ? napi_create_error(env, nullptr, text, result) : status;
}

struct ModelWork {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    std::vector<uint8_t> bytes;
    bool validationOnly = false;
    bool valid = false;
    ObjectDetectionModelInfo info;
    std::exception_ptr error;
};

napi_value RejectModelBeforeQueue(napi_env env, napi_deferred deferred, napi_value promise,
                                  const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateErrorValue(env, message, &error) != napi_ok || napi_reject_deferred(env, deferred, error) != napi_ok) {
        EstablishExceptionOrFatal(env, message);
        return nullptr;
    }
    return promise;
}

void ExecuteModelWork(napi_env, void* raw) noexcept
{
    auto* work = static_cast<ModelWork*>(raw);
    if (work->validationOnly) {
        try {
            ObjectDetectionMnnSession candidate;
            candidate.LoadModel(work->bytes.data(), work->bytes.size());
            work->valid = true;
        } catch (...) {
            work->valid = false;
        }
        return;
    }
    try {
        work->info = g_session.LoadModel(work->bytes.data(), work->bytes.size());
    } catch (...) {
        work->error = std::current_exception();
    }
}

std::string ErrorMessage(const std::exception_ptr& error);

void CompleteModelWork(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<ModelWork> work(static_cast<ModelWork*>(raw));
    if (work == nullptr) {
        FatalNapi("object_detection_mnn model completion", "Async model work context is null.");
    }
    if (status != napi_ok && work->error == nullptr) {
        work->error = std::make_exception_ptr(std::runtime_error("Native object-detection model work was cancelled."));
    }
    napi_value value = nullptr;
    if (work->error != nullptr) {
        const std::string message = ErrorMessage(work->error);
        if (CreateErrorValue(env, message.c_str(), &value) != napi_ok ||
            napi_reject_deferred(env, work->deferred, value) != napi_ok) {
            FatalNapi("object_detection_mnn model completion", "Could not reject model Promise.");
        }
    } else {
        try {
            if (work->validationOnly) {
                Check(env, napi_get_boolean(env, work->valid, &value), "create validation result");
            } else {
                value = ModelInfoValue(env, work->info);
            }
            Check(env, napi_resolve_deferred(env, work->deferred, value), "resolve model Promise");
        } catch (const std::exception& exception) {
            napi_value error = nullptr;
            if (CreateErrorValue(env, exception.what(), &error) != napi_ok ||
                napi_reject_deferred(env, work->deferred, error) != napi_ok) {
                FatalNapi("object_detection_mnn model completion", "Could not settle model Promise.");
            }
        }
    }
    const napi_async_work asyncWork = work->work;
    work->work = nullptr;
    work.reset();
    if (napi_delete_async_work(env, asyncWork) != napi_ok) {
        FatalNapi("object_detection_mnn model completion", "Could not delete model async work.");
    }
}

napi_value StartModelWork(napi_env env, napi_callback_info callbackInfo, bool validationOnly)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create model Promise");
    try {
        size_t argc = 1;
        napi_value argument = nullptr;
        Check(env, napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr), "read model arguments");
        const char* expectation = validationOnly ? "validateModel expects one Uint8Array." :
                                                   "loadModel expects one Uint8Array.";
        if (argc != 1) {
            return RejectModelBeforeQueue(env, deferred, promise, expectation);
        }
        const TypedArrayView bytes = ReadTypedArray(env, argument, napi_uint8_array, sizeof(uint8_t), expectation);
        auto work = std::make_unique<ModelWork>();
        work->deferred = deferred;
        work->validationOnly = validationOnly;
        const uint8_t* source = static_cast<const uint8_t*>(bytes.data);
        work->bytes.assign(source, source + bytes.visibleLength);
        napi_value resourceName = String(env, validationOnly ? "object_detection_mnn_validate" :
                                                       "object_detection_mnn_load");
        napi_status createStatus = napi_create_async_work(env, nullptr, resourceName, ExecuteModelWork,
                                                          CompleteModelWork, work.get(), &work->work);
        if (createStatus != napi_ok) {
            return RejectModelBeforeQueue(env, deferred, promise, "Could not create model async work.");
        }
        napi_status queueStatus = napi_queue_async_work(env, work->work);
        if (queueStatus != napi_ok) {
            napi_delete_async_work(env, work->work);
            work->work = nullptr;
            return RejectModelBeforeQueue(env, deferred, promise, "Could not queue model async work.");
        }
        work.release();
        return promise;
    } catch (const std::exception& error) {
        return RejectModelBeforeQueue(env, deferred, promise, error.what());
    } catch (...) {
        return RejectModelBeforeQueue(env, deferred, promise, kUnknownNativeError);
    }
}

napi_value LoadModelBoundary(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return StartModelWork(env, callbackInfo, false);
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
    }
    return nullptr;
}

napi_value ValidateModelBoundary(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return StartModelWork(env, callbackInfo, true);
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
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

napi_value RejectBeforeQueue(napi_env env, napi_deferred deferred, napi_value promise, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateErrorValue(env, message, &error) != napi_ok || napi_reject_deferred(env, deferred, error) != napi_ok) {
        EstablishExceptionOrFatal(env, message);
        return nullptr;
    }
    return promise;
}

void ExecutePredict(napi_env, void* raw) noexcept
{
    auto* work = static_cast<PredictWork*>(raw);
    try {
        work->output = g_session.Predict(work->input);
    } catch (...) {
        work->error = std::current_exception();
    }
}

std::string ErrorMessage(const std::exception_ptr& error)
{
    try {
        std::rethrow_exception(error);
    } catch (const std::exception& exception) {
        return exception.what();
    } catch (...) {
        return kUnknownNativeError;
    }
}

void CompletePredict(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<PredictWork> work(static_cast<PredictWork*>(raw));
    if (work == nullptr) {
        FatalNapi("object_detection_mnn completion", "Async work context is null.");
    }
    if (status != napi_ok && work->error == nullptr) {
        work->error = std::make_exception_ptr(std::runtime_error("Native object-detection inference was cancelled."));
    }
    if (work->error != nullptr) {
        const std::string message = ErrorMessage(work->error);
        napi_value error = nullptr;
        if (CreateErrorValue(env, message.c_str(), &error) != napi_ok ||
            napi_reject_deferred(env, work->deferred, error) != napi_ok) {
            FatalNapi("object_detection_mnn completion", "Could not reject prediction Promise.");
        }
    } else {
        napi_value arrayBuffer = nullptr;
        napi_value typedArray = nullptr;
        void* destination = nullptr;
        const size_t byteLength = work->output.size() * sizeof(float);
        if (napi_create_arraybuffer(env, byteLength, &destination, &arrayBuffer) != napi_ok ||
            destination == nullptr) {
            FatalNapi("object_detection_mnn completion", "Could not allocate prediction output.");
        }
        std::memcpy(destination, work->output.data(), byteLength);
        if (napi_create_typedarray(env, napi_float32_array, work->output.size(), arrayBuffer, 0, &typedArray) != napi_ok ||
            napi_resolve_deferred(env, work->deferred, typedArray) != napi_ok) {
            FatalNapi("object_detection_mnn completion", "Could not resolve prediction Promise.");
        }
    }
    const napi_async_work asyncWork = work->work;
    work->work = nullptr;
    work.reset();
    if (napi_delete_async_work(env, asyncWork) != napi_ok) {
        FatalNapi("object_detection_mnn completion", "Could not delete prediction async work.");
    }
}

napi_value PredictImpl(napi_env env, napi_callback_info callbackInfo)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create prediction Promise");
    try {
        size_t argc = 1;
        napi_value argument = nullptr;
        Check(env, napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr),
              "read predict arguments");
        if (argc != 1) {
            return RejectBeforeQueue(env, deferred, promise, "predict expects one Float32Array.");
        }
        const TypedArrayView input = ReadTypedArray(env, argument, napi_float32_array, sizeof(float),
                                                   "predict expects one Float32Array.");
        if (input.visibleLength != kInputElementCount) {
            return RejectBeforeQueue(env, deferred, promise,
                                     "Object-detection input must contain exactly 307200 float32 values.");
        }
        auto work = std::make_unique<PredictWork>();
        work->deferred = deferred;
        const float* values = static_cast<const float*>(input.data);
        work->input.assign(values, values + input.visibleLength);
        napi_value resourceName = String(env, "object_detection_mnn_predict");
        napi_status createStatus = napi_create_async_work(env, nullptr, resourceName, ExecutePredict, CompletePredict,
                                                          work.get(), &work->work);
        if (createStatus != napi_ok) {
            return RejectBeforeQueue(env, deferred, promise, "Could not create object-detection async work.");
        }
        napi_status queueStatus = napi_queue_async_work(env, work->work);
        if (queueStatus != napi_ok) {
            napi_delete_async_work(env, work->work);
            work->work = nullptr;
            return RejectBeforeQueue(env, deferred, promise, "Could not queue object-detection async work.");
        }
        work.release();
        return promise;
    } catch (const std::exception& error) {
        return RejectBeforeQueue(env, deferred, promise, error.what());
    } catch (...) {
        return RejectBeforeQueue(env, deferred, promise, kUnknownNativeError);
    }
}

napi_value PredictBoundary(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return PredictImpl(env, callbackInfo);
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
    }
    return nullptr;
}

napi_value ReleaseBoundary(napi_env env, napi_callback_info) noexcept
{
    try {
        g_session.Release();
        napi_value result = nullptr;
        Check(env, napi_get_undefined(env, &result), "create release result");
        return result;
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
    }
    return nullptr;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"loadModel", nullptr, LoadModelBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"validateModel", nullptr, ValidateModelBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predict", nullptr, PredictBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, ReleaseBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    Check(env, napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties),
          "define object-detection exports");
    return exports;
}
}

static napi_module objectDetectionModule = {
    1, 0, nullptr, Init, "object_detection_mnn", nullptr, {0},
};

extern "C" __attribute__((constructor)) void RegisterObjectDetectionMnnModule()
{
    napi_module_register(&objectDetectionModule);
}
