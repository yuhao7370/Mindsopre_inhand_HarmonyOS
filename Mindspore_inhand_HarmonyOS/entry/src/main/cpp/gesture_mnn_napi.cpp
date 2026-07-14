#include "gesture_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
constexpr size_t kInputElementCount = 150528;
constexpr const char* kUnknownNativeError = "Unknown native gesture error.";
GestureMnnSession g_session;

[[noreturn]] void FatalNapi(const char* location, const char* message) noexcept
{
    napi_fatal_error(location, NAPI_AUTO_LENGTH, message, NAPI_AUTO_LENGTH);
}

void EstablishExceptionOrFatal(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok) {
        FatalNapi("gesture_mnn", "Could not inspect the NAPI exception state.");
    }
    if (pending) {
        return;
    }
    if (napi_throw_error(env, nullptr, message) != napi_ok) {
        FatalNapi("gesture_mnn", "Could not establish a JavaScript exception.");
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

napi_status CreateErrorValue(napi_env env, const char* message, napi_value* result) noexcept
{
    napi_value text = nullptr;
    napi_status status = napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
    if (status != napi_ok) {
        return status;
    }
    return napi_create_error(env, nullptr, text, result);
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

napi_value ModelInfoValue(napi_env env, const GestureModelInfo& info)
{
    napi_value result = nullptr;
    Check(env, napi_create_object(env, &result), "create model info");
    Set(env, result, "inputName", String(env, info.inputName));
    Set(env, result, "inputShape", Shape(env, info.inputShape));
    return result;
}

napi_value OutputsValue(napi_env env, const GestureRawOutputs& outputs)
{
    napi_value result = nullptr;
    napi_value tensors = nullptr;
    Check(env, napi_create_object(env, &result), "create outputs");
    Check(env, napi_create_array_with_length(env, outputs.tensors.size(), &tensors), "create tensor array");
    for (size_t index = 0; index < outputs.tensors.size(); ++index) {
        const GestureRawTensor& source = outputs.tensors[index];
        napi_value tensor = nullptr;
        napi_value arrayBuffer = nullptr;
        void* destination = nullptr;
        Check(env, napi_create_object(env, &tensor), "create tensor");
        Set(env, tensor, "name", String(env, source.name));
        Set(env, tensor, "shape", Shape(env, source.shape));
        const size_t byteLength = source.data.size() * sizeof(float);
        Check(env, napi_create_arraybuffer(env, byteLength, &destination, &arrayBuffer), "create tensor buffer");
        if (byteLength != 0 && destination == nullptr) {
            throw std::runtime_error("NAPI returned a null gesture output buffer.");
        }
        std::memcpy(destination, source.data.data(), byteLength);
        Set(env, tensor, "data", arrayBuffer);
        Check(env, napi_set_element(env, tensors, index, tensor), "set output tensor");
    }
    Set(env, result, "tensors", tensors);
    return result;
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
    napi_typedarray_type type;
    size_t length = 0;
    void* data = nullptr;
    Check(env, napi_get_typedarray_info(env, argument, &type, &length, &data, nullptr, nullptr), "read model bytes");
    if (type != napi_uint8_array) {
        throw std::invalid_argument("loadModel expects one Uint8Array.");
    }
    return ModelInfoValue(env, g_session.LoadModel(static_cast<const uint8_t*>(data), length));
}

napi_value LoadModelBoundary(napi_env env, napi_callback_info callbackInfo) noexcept
{
    try {
        return LoadModelImpl(env, callbackInfo);
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
    GestureRawOutputs outputs;
    std::exception_ptr error;
};

void DeleteUnqueuedWorkOrFatal(napi_env env, std::unique_ptr<PredictWork>& work) noexcept
{
    napi_async_work asyncWork = work->work;
    work->work = nullptr;
    const napi_status status = asyncWork == nullptr ? napi_ok : napi_delete_async_work(env, asyncWork);
    work.reset();
    if (status != napi_ok) {
        FatalNapi("gesture_mnn predict", "Could not delete unqueued gesture async work.");
    }
}

void ExecutePredict(napi_env, void* raw) noexcept
{
    auto* work = static_cast<PredictWork*>(raw);
    try {
        work->outputs = g_session.Predict(work->input);
    } catch (...) {
        work->error = std::current_exception();
    }
}

napi_status CleanupPredictWork(napi_env env, std::unique_ptr<PredictWork>& work) noexcept
{
    napi_async_work asyncWork = work->work;
    work->work = nullptr;
    const napi_status status = asyncWork == nullptr ? napi_ok : napi_delete_async_work(env, asyncWork);
    work.reset();
    return status;
}

[[noreturn]] void CleanupThenFatal(napi_env env, std::unique_ptr<PredictWork>& work, const char* message) noexcept
{
    const napi_status cleanupStatus = CleanupPredictWork(env, work);
    if (cleanupStatus != napi_ok) {
        FatalNapi("gesture_mnn completion", "Could not delete failed gesture async work.");
    }
    FatalNapi("gesture_mnn completion", message);
}

void RejectAsyncOrFatal(napi_env env, std::unique_ptr<PredictWork>& work, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateErrorValue(env, message, &error) != napi_ok) {
        CleanupThenFatal(env, work, "Could not create the gesture Promise rejection value.");
    }
    if (napi_reject_deferred(env, work->deferred, error) != napi_ok) {
        CleanupThenFatal(env, work, "Could not reject the gesture Promise.");
    }
}

void SettleAsyncOrFatal(napi_env env, napi_status status, std::unique_ptr<PredictWork>& work) noexcept
{
    if (status != napi_ok) {
        RejectAsyncOrFatal(env, work, "Native gesture inference was cancelled.");
        return;
    }
    if (work->error != nullptr) {
        try {
            std::rethrow_exception(work->error);
        } catch (const std::exception& error) {
            RejectAsyncOrFatal(env, work, error.what());
        } catch (...) {
            RejectAsyncOrFatal(env, work, kUnknownNativeError);
        }
        return;
    }
    try {
        napi_value outputs = OutputsValue(env, work->outputs);
        if (napi_resolve_deferred(env, work->deferred, outputs) != napi_ok) {
            CleanupThenFatal(env, work, "Could not resolve the gesture Promise.");
        }
    } catch (const std::exception& error) {
        RejectAsyncOrFatal(env, work, error.what());
    } catch (...) {
        RejectAsyncOrFatal(env, work, kUnknownNativeError);
    }
}

void CompletePredict(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<PredictWork> work(static_cast<PredictWork*>(raw));
    if (work == nullptr) {
        FatalNapi("gesture_mnn completion", "Gesture async work context is null.");
    }
    SettleAsyncOrFatal(env, status, work);
    const napi_status cleanupStatus = CleanupPredictWork(env, work);
    if (cleanupStatus != napi_ok) {
        FatalNapi("gesture_mnn completion", "Could not delete gesture async work.");
    }
}

napi_value RejectBeforeQueue(napi_env env, napi_deferred deferred, napi_value promise, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateErrorValue(env, message, &error) != napi_ok) {
        EstablishExceptionOrFatal(env, message);
        return nullptr;
    }
    if (napi_reject_deferred(env, deferred, error) != napi_ok) {
        EstablishExceptionOrFatal(env, message);
        return nullptr;
    }
    return promise;
}

napi_value PredictImpl(napi_env env, napi_callback_info callbackInfo)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create gesture prediction promise");

    size_t argc = 1;
    napi_value argument = nullptr;
    bool isTypedArray = false;
    napi_typedarray_type type;
    size_t length = 0;
    void* data = nullptr;
    if (napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr) != napi_ok || argc != 1 ||
        napi_is_typedarray(env, argument, &isTypedArray) != napi_ok || !isTypedArray ||
        napi_get_typedarray_info(env, argument, &type, &length, &data, nullptr, nullptr) != napi_ok ||
        type != napi_float32_array) {
        return RejectBeforeQueue(env, deferred, promise, "predict expects one Float32Array.");
    }
    if (length != kInputElementCount) {
        return RejectBeforeQueue(env, deferred, promise, "Gesture input must contain exactly 150528 float32 values.");
    }

    auto work = std::make_unique<PredictWork>();
    work->deferred = deferred;
    const float* values = static_cast<const float*>(data);
    work->input.assign(values, values + length);
    napi_value resourceName = String(env, "gesture_mnn_predict");
    napi_status status = napi_create_async_work(env, nullptr, resourceName, ExecutePredict, CompletePredict, work.get(),
                                                &work->work);
    if (status != napi_ok) {
        DeleteUnqueuedWorkOrFatal(env, work);
        return RejectBeforeQueue(env, deferred, promise, "Could not create gesture async work.");
    }
    status = napi_queue_async_work(env, work->work);
    if (status != napi_ok) {
        DeleteUnqueuedWorkOrFatal(env, work);
        return RejectBeforeQueue(env, deferred, promise, "Could not queue gesture async work.");
    }
    work.release();
    return promise;
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

napi_value ReleaseImpl(napi_env env)
{
    g_session.Release();
    napi_value result = nullptr;
    Check(env, napi_get_undefined(env, &result), "create release result");
    return result;
}

napi_value ReleaseBoundary(napi_env env, napi_callback_info) noexcept
{
    try {
        return ReleaseImpl(env);
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
    }
    return nullptr;
}

napi_value InitImpl(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"loadModel", nullptr, LoadModelBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predict", nullptr, PredictBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, ReleaseBoundary, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    Check(env, napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties),
          "define gesture exports");
    return exports;
}

napi_value InitBoundary(napi_env env, napi_value exports) noexcept
{
    try {
        return InitImpl(env, exports);
    } catch (const std::exception& error) {
        EstablishExceptionOrFatal(env, error.what());
    } catch (...) {
        EstablishExceptionOrFatal(env, kUnknownNativeError);
    }
    return nullptr;
}
}

static napi_module gestureModule = {
    1,
    0,
    nullptr,
    InitBoundary,
    "gesture_mnn",
    nullptr,
    {0},
};

extern "C" __attribute__((constructor)) void RegisterGestureMnnModule()
{
    napi_module_register(&gestureModule);
}
