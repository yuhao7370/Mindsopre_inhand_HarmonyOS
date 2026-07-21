#include "style_transfer_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
constexpr size_t kStyleElementCount = 1U * 256U * 256U * 3U;
constexpr size_t kContentElementCount = 1U * 384U * 384U * 3U;
constexpr const char* kUnknownError = "Unknown native style-transfer error.";
StyleTransferMnnSession g_session;

[[noreturn]] void Fatal(const char* location, const char* message) noexcept
{
    napi_fatal_error(location, NAPI_AUTO_LENGTH, message, NAPI_AUTO_LENGTH);
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

napi_value String(napi_env env, const char* value)
{
    napi_value result = nullptr;
    Check(env, napi_create_string_utf8(env, value, NAPI_AUTO_LENGTH, &result), "create string");
    return result;
}

napi_status CreateError(napi_env env, const char* message, napi_value* result) noexcept
{
    napi_value text = nullptr;
    const napi_status status = napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
    return status == napi_ok ? napi_create_error(env, nullptr, text, result) : status;
}

void EstablishExceptionOrFatal(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok) {
        Fatal("style_transfer_mnn", "Could not inspect NAPI exception state.");
    }
    if (!pending && napi_throw_error(env, nullptr, message) != napi_ok) {
        Fatal("style_transfer_mnn", "Could not establish JavaScript exception.");
    }
}

void DeleteWorkOrFatal(napi_env env, napi_async_work work, const char* location) noexcept
{
    if (work == nullptr || napi_delete_async_work(env, work) != napi_ok) {
        Fatal(location, "Could not delete native style-transfer async work.");
    }
}

struct TypedArrayView {
    void* data = nullptr;
    size_t visibleLength = 0;
};

uint32_t VisibleLength(napi_env env, napi_value value)
{
    napi_value lengthValue = nullptr;
    uint32_t length = 0;
    Check(env, napi_get_named_property(env, value, "length", &lengthValue), "read typed-array length");
    Check(env, napi_get_value_uint32(env, lengthValue, &length), "decode typed-array length");
    return length;
}

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

enum class WorkKind { Load, ValidatePredict, ValidateTransfer, Run };

struct Work {
    napi_deferred deferred = nullptr;
    napi_async_work asyncWork = nullptr;
    WorkKind kind = WorkKind::Load;
    std::vector<uint8_t> predictBytes;
    std::vector<uint8_t> transferBytes;
    std::vector<float> styleInput;
    std::vector<float> contentInput;
    bool valid = false;
    StyleTransferMnnOutput runOutput;
    std::exception_ptr error;
};

std::string ErrorMessage(const std::exception_ptr& error)
{
    try {
        std::rethrow_exception(error);
    } catch (const std::exception& exception) {
        return exception.what();
    } catch (...) {
        return kUnknownError;
    }
}

void Execute(napi_env, void* raw) noexcept
{
    auto* work = static_cast<Work*>(raw);
    try {
        switch (work->kind) {
            case WorkKind::Load:
                g_session.LoadModels(work->predictBytes.data(), work->predictBytes.size(),
                                     work->transferBytes.data(), work->transferBytes.size());
                break;
            case WorkKind::ValidatePredict:
                work->valid = g_session.ValidatePredictModel(work->predictBytes.data(), work->predictBytes.size());
                break;
            case WorkKind::ValidateTransfer:
                work->valid = g_session.ValidateTransferModel(work->transferBytes.data(), work->transferBytes.size());
                break;
            case WorkKind::Run:
                work->runOutput = g_session.Run(work->styleInput, work->contentInput);
                break;
        }
    } catch (...) {
        work->error = std::current_exception();
    }
}

napi_value FloatArray(napi_env env, const std::vector<float>& values)
{
    napi_value arrayBuffer = nullptr;
    napi_value typedArray = nullptr;
    void* destination = nullptr;
    const size_t bytes = values.size() * sizeof(float);
    Check(env, napi_create_arraybuffer(env, bytes, &destination, &arrayBuffer), "create output buffer");
    if (bytes != 0 && destination == nullptr) {
        throw std::runtime_error("NAPI returned a null style-transfer output buffer.");
    }
    std::memcpy(destination, values.data(), bytes);
    Check(env, napi_create_typedarray(env, napi_float32_array, values.size(), arrayBuffer, 0, &typedArray),
          "create output typed array");
    return typedArray;
}

napi_value RunOutputValue(napi_env env, const StyleTransferMnnOutput& output)
{
    napi_value result = nullptr;
    napi_value predictMs = nullptr;
    napi_value transferMs = nullptr;
    Check(env, napi_create_object(env, &result), "create run output");
    Check(env, napi_set_named_property(env, result, "output", FloatArray(env, output.output)), "set run output");
    Check(env, napi_create_int64(env, output.predictMs, &predictMs), "create predict duration");
    Check(env, napi_create_int64(env, output.transferMs, &transferMs), "create transfer duration");
    Check(env, napi_set_named_property(env, result, "predictMs", predictMs), "set predict duration");
    Check(env, napi_set_named_property(env, result, "transferMs", transferMs), "set transfer duration");
    return result;
}

void Complete(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<Work> work(static_cast<Work*>(raw));
    if (work == nullptr) {
        Fatal("style_transfer_mnn completion", "Async work context is null.");
    }
    if (status != napi_ok && work->error == nullptr) {
        work->error = std::make_exception_ptr(std::runtime_error("Native style-transfer work was cancelled."));
    }
    if (work->error != nullptr) {
        const std::string message = ErrorMessage(work->error);
        napi_value error = nullptr;
        if (CreateError(env, message.c_str(), &error) != napi_ok ||
            napi_reject_deferred(env, work->deferred, error) != napi_ok) {
            Fatal("style_transfer_mnn completion", "Could not reject style-transfer Promise.");
        }
    } else {
        try {
            napi_value value = nullptr;
            if (work->kind == WorkKind::ValidatePredict || work->kind == WorkKind::ValidateTransfer) {
                Check(env, napi_get_boolean(env, work->valid, &value), "create validation result");
            } else if (work->kind == WorkKind::Run) {
                value = RunOutputValue(env, work->runOutput);
            } else {
                Check(env, napi_get_undefined(env, &value), "create undefined");
            }
            Check(env, napi_resolve_deferred(env, work->deferred, value), "resolve style-transfer Promise");
        } catch (const std::exception& exception) {
            napi_value error = nullptr;
            if (CreateError(env, exception.what(), &error) != napi_ok ||
                napi_reject_deferred(env, work->deferred, error) != napi_ok) {
                Fatal("style_transfer_mnn completion", "Could not settle style-transfer Promise.");
            }
        }
    }
    const napi_async_work asyncWork = work->asyncWork;
    work->asyncWork = nullptr;
    DeleteWorkOrFatal(env, asyncWork, "style_transfer_mnn completion");
    work.reset();
}

napi_value RejectBeforeQueue(napi_env env, napi_deferred deferred, napi_value promise, const char* message) noexcept
{
    napi_value error = nullptr;
    if (CreateError(env, message, &error) != napi_ok || napi_reject_deferred(env, deferred, error) != napi_ok) {
        EstablishExceptionOrFatal(env, message);
        return nullptr;
    }
    return promise;
}

napi_value Start(napi_env env, napi_callback_info callbackInfo, WorkKind kind)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create style-transfer Promise");
    try {
        size_t argc = 2;
        napi_value arguments[2] = {nullptr, nullptr};
        Check(env, napi_get_cb_info(env, callbackInfo, &argc, arguments, nullptr, nullptr), "read arguments");
        auto work = std::make_unique<Work>();
        work->deferred = deferred;
        work->kind = kind;
        if (kind == WorkKind::Load) {
            if (argc != 2) {
                return RejectBeforeQueue(env, deferred, promise, "loadModels expects two Uint8Arrays.");
            }
            const TypedArrayView predict = ReadTypedArray(env, arguments[0], napi_uint8_array, sizeof(uint8_t),
                                                          "loadModels expects two Uint8Arrays.");
            const TypedArrayView transfer = ReadTypedArray(env, arguments[1], napi_uint8_array, sizeof(uint8_t),
                                                           "loadModels expects two Uint8Arrays.");
            if (predict.visibleLength == 0 || transfer.visibleLength == 0) {
                return RejectBeforeQueue(env, deferred, promise, "Style-transfer model bytes must not be empty.");
            }
            const auto* predictData = static_cast<const uint8_t*>(predict.data);
            const auto* transferData = static_cast<const uint8_t*>(transfer.data);
            work->predictBytes.assign(predictData, predictData + predict.visibleLength);
            work->transferBytes.assign(transferData, transferData + transfer.visibleLength);
        } else if (kind == WorkKind::ValidatePredict || kind == WorkKind::ValidateTransfer) {
            if (argc != 1) {
                return RejectBeforeQueue(env, deferred, promise, "model validation expects one Uint8Array.");
            }
            const TypedArrayView bytes = ReadTypedArray(env, arguments[0], napi_uint8_array, sizeof(uint8_t),
                                                        "model validation expects one Uint8Array.");
            if (bytes.visibleLength == 0) {
                return RejectBeforeQueue(env, deferred, promise, "Style-transfer model bytes must not be empty.");
            }
            const auto* data = static_cast<const uint8_t*>(bytes.data);
            if (kind == WorkKind::ValidatePredict) {
                work->predictBytes.assign(data, data + bytes.visibleLength);
            } else {
                work->transferBytes.assign(data, data + bytes.visibleLength);
            }
        } else {
            if (argc != 2) {
                return RejectBeforeQueue(env, deferred, promise, "run expects style and content Float32Arrays.");
            }
            const TypedArrayView style = ReadTypedArray(env, arguments[0], napi_float32_array, sizeof(float),
                                                        "run expects style and content Float32Arrays.");
            const TypedArrayView content = ReadTypedArray(env, arguments[1], napi_float32_array, sizeof(float),
                                                          "run expects style and content Float32Arrays.");
            if (style.visibleLength != kStyleElementCount || content.visibleLength != kContentElementCount) {
                return RejectBeforeQueue(env, deferred, promise,
                                         "Style/content inputs must contain exactly 196608/442368 float32 values.");
            }
            const auto* styleData = static_cast<const float*>(style.data);
            const auto* contentData = static_cast<const float*>(content.data);
            work->styleInput.assign(styleData, styleData + style.visibleLength);
            work->contentInput.assign(contentData, contentData + content.visibleLength);
        }

        napi_value resourceName = String(env, "style_transfer_mnn_work");
        const napi_status created = napi_create_async_work(env, nullptr, resourceName, Execute, Complete,
                                                           work.get(), &work->asyncWork);
        if (created != napi_ok) {
            return RejectBeforeQueue(env, deferred, promise, "Could not create native style-transfer work.");
        }
        if (napi_queue_async_work(env, work->asyncWork) != napi_ok) {
            DeleteWorkOrFatal(env, work->asyncWork, "style_transfer_mnn queue cleanup");
            work->asyncWork = nullptr;
            return RejectBeforeQueue(env, deferred, promise, "Could not queue native style-transfer work.");
        }
        work.release();
        return promise;
    } catch (const std::exception& exception) {
        return RejectBeforeQueue(env, deferred, promise, exception.what());
    } catch (...) {
        return RejectBeforeQueue(env, deferred, promise, kUnknownError);
    }
}

#define STYLE_BOUNDARY(Name, Kind) \
    napi_value Name(napi_env env, napi_callback_info info) noexcept \
    { \
        try { return Start(env, info, Kind); } \
        catch (const std::exception& exception) { EstablishExceptionOrFatal(env, exception.what()); } \
        catch (...) { EstablishExceptionOrFatal(env, kUnknownError); } \
        return nullptr; \
    }

STYLE_BOUNDARY(LoadModels, WorkKind::Load)
STYLE_BOUNDARY(ValidatePredict, WorkKind::ValidatePredict)
STYLE_BOUNDARY(ValidateTransfer, WorkKind::ValidateTransfer)
STYLE_BOUNDARY(Run, WorkKind::Run)

napi_value Release(napi_env env, napi_callback_info) noexcept
{
    g_session.Release();
    napi_value result = nullptr;
    if (napi_get_undefined(env, &result) != napi_ok) {
        EstablishExceptionOrFatal(env, "Could not create release result.");
        return nullptr;
    }
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor properties[] = {
        {"loadModels", nullptr, LoadModels, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"validatePredictModel", nullptr, ValidatePredict, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"validateTransferModel", nullptr, ValidateTransfer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"run", nullptr, Run, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, Release, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    Check(env, napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties),
          "define style-transfer exports");
    return exports;
}
}

static napi_module styleTransferModule = {
    1, 0, nullptr, Init, "style_transfer_mnn", nullptr, {0},
};

extern "C" __attribute__((constructor)) void RegisterStyleTransferMnnModule()
{
    napi_module_register(&styleTransferModule);
}
