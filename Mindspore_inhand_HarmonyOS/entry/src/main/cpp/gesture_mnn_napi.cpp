#include "gesture_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>

namespace {
constexpr size_t kInputElementCount = 150528;
GestureMnnSession g_session;

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

napi_value ErrorValue(napi_env env, const std::string& message)
{
    napi_value text = nullptr;
    napi_value error = nullptr;
    if (napi_create_string_utf8(env, message.c_str(), message.size(), &text) != napi_ok ||
        napi_create_error(env, nullptr, text, &error) != napi_ok) {
        return nullptr;
    }
    return error;
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
        std::memcpy(destination, source.data.data(), byteLength);
        Set(env, tensor, "data", arrayBuffer);
        Check(env, napi_set_element(env, tensors, index, tensor), "set output tensor");
    }
    Set(env, result, "tensors", tensors);
    return result;
}

napi_value LoadModel(napi_env env, napi_callback_info callbackInfo)
{
    try {
        size_t argc = 1;
        napi_value argument = nullptr;
        Check(env, napi_get_cb_info(env, callbackInfo, &argc, &argument, nullptr, nullptr), "read loadModel arguments");
        bool isTypedArray = false;
        if (argc != 1 || napi_is_typedarray(env, argument, &isTypedArray) != napi_ok || !isTypedArray) {
            napi_throw_type_error(env, nullptr, "loadModel expects one Uint8Array.");
            return nullptr;
        }
        napi_typedarray_type type;
        size_t length = 0;
        void* data = nullptr;
        Check(env, napi_get_typedarray_info(env, argument, &type, &length, &data, nullptr, nullptr), "read model bytes");
        if (type != napi_uint8_array) {
            napi_throw_type_error(env, nullptr, "loadModel expects one Uint8Array.");
            return nullptr;
        }
        return ModelInfoValue(env, g_session.LoadModel(static_cast<const uint8_t*>(data), length));
    } catch (const std::exception& error) {
        napi_throw_error(env, nullptr, error.what());
        return nullptr;
    }
}

struct PredictWork {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    std::vector<float> input;
    GestureRawOutputs outputs;
    std::string error;
};

void ExecutePredict(napi_env, void* raw)
{
    auto* work = static_cast<PredictWork*>(raw);
    try {
        work->outputs = g_session.Predict(work->input);
    } catch (const std::exception& error) {
        work->error = error.what();
    } catch (...) {
        work->error = "Unknown native gesture inference error.";
    }
}

void CompletePredict(napi_env env, napi_status status, void* raw)
{
    std::unique_ptr<PredictWork> work(static_cast<PredictWork*>(raw));
    if (status != napi_ok && work->error.empty()) {
        work->error = "Native gesture inference was cancelled.";
    }
    try {
        if (work->error.empty()) {
            Check(env, napi_resolve_deferred(env, work->deferred, OutputsValue(env, work->outputs)), "resolve prediction");
        } else {
            napi_value error = ErrorValue(env, work->error);
            if (error != nullptr) {
                napi_reject_deferred(env, work->deferred, error);
            }
        }
    } catch (const std::exception& error) {
        napi_value value = ErrorValue(env, error.what());
        if (value != nullptr) {
            napi_reject_deferred(env, work->deferred, value);
        }
    }
    if (work->work != nullptr) {
        napi_delete_async_work(env, work->work);
    }
}

napi_value RejectedPromise(napi_env env, napi_deferred deferred, napi_value promise, const std::string& message)
{
    napi_value error = ErrorValue(env, message);
    if (error != nullptr) {
        napi_reject_deferred(env, deferred, error);
    }
    return promise;
}

napi_value Predict(napi_env env, napi_callback_info callbackInfo)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    if (napi_create_promise(env, &deferred, &promise) != napi_ok) {
        napi_throw_error(env, nullptr, "Could not create gesture prediction promise.");
        return nullptr;
    }

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
        return RejectedPromise(env, deferred, promise, "predict expects one Float32Array.");
    }
    if (length != kInputElementCount) {
        return RejectedPromise(env, deferred, promise, "Gesture input must contain exactly 150528 float32 values.");
    }

    auto work = std::make_unique<PredictWork>();
    work->deferred = deferred;
    try {
        const float* values = static_cast<const float*>(data);
        work->input.assign(values, values + length);
        napi_value resourceName = String(env, "gesture_mnn_predict");
        Check(env, napi_create_async_work(env, nullptr, resourceName, ExecutePredict, CompletePredict, work.get(), &work->work),
              "create gesture async work");
        Check(env, napi_queue_async_work(env, work->work), "queue gesture async work");
        work.release();
        return promise;
    } catch (const std::exception& error) {
        if (work->work != nullptr) {
            napi_delete_async_work(env, work->work);
        }
        return RejectedPromise(env, deferred, promise, error.what());
    }
}

napi_value Release(napi_env env, napi_callback_info)
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
    Check(env, napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties),
          "define gesture exports");
    return exports;
}
}

static napi_module gestureModule = {
    1,
    0,
    nullptr,
    Init,
    "gesture_mnn",
    nullptr,
    {0},
};

extern "C" __attribute__((constructor)) void RegisterGestureMnnModule()
{
    napi_module_register(&gestureModule);
}
