#include "ocr_mnn_session.h"

#include <napi/native_api.h>

#include <cstring>
#include <exception>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
constexpr size_t kDetectorInputCount = 1U * 3U * 960U * 960U;
constexpr size_t kRecognizerInputCount = 1U * 3U * 48U * 320U;
constexpr const char* kUnknownError = "Unknown native PP-OCR error.";
OcrMnnSession g_session;

void Check(napi_env env, napi_status status, const char* operation)
{
    if (status != napi_ok) {
        throw std::runtime_error(operation);
    }
}

void Throw(napi_env env, const char* message) noexcept
{
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) == napi_ok && !pending) {
        napi_throw_error(env, nullptr, message);
    }
}

napi_value ErrorValue(napi_env env, const char* message)
{
    napi_value text = nullptr;
    napi_value error = nullptr;
    Check(env, napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text), "create OCR error text");
    Check(env, napi_create_error(env, nullptr, text, &error), "create OCR error");
    return error;
}

void ReadBytes(napi_env env, napi_value value, const uint8_t*& bytes, size_t& length)
{
    bool typed = false;
    napi_typedarray_type type = napi_int8_array;
    void* data = nullptr;
    Check(env, napi_is_typedarray(env, value, &typed), "check OCR model bytes");
    if (!typed || napi_get_typedarray_info(env, value, &type, &length, &data, nullptr, nullptr) != napi_ok ||
        type != napi_uint8_array || data == nullptr || length == 0) {
        throw std::invalid_argument("loadModels expects non-empty Uint8Array model bytes.");
    }
    bytes = static_cast<const uint8_t*>(data);
}

napi_value LoadModelsImpl(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    Check(env, napi_get_cb_info(env, info, &argc, args, nullptr, nullptr), "read loadModels arguments");
    if (argc != 2) {
        throw std::invalid_argument("loadModels expects detector and recognizer Uint8Array values.");
    }
    const uint8_t* detector = nullptr;
    const uint8_t* recognizer = nullptr;
    size_t detectorSize = 0;
    size_t recognizerSize = 0;
    ReadBytes(env, args[0], detector, detectorSize);
    ReadBytes(env, args[1], recognizer, recognizerSize);
    g_session.LoadModels(detector, detectorSize, recognizer, recognizerSize);
    napi_value result = nullptr;
    Check(env, napi_get_undefined(env, &result), "create undefined");
    return result;
}

napi_value LoadModels(napi_env env, napi_callback_info info) noexcept
{
    try {
        return LoadModelsImpl(env, info);
    } catch (const std::exception& error) {
        Throw(env, error.what());
    } catch (...) {
        Throw(env, kUnknownError);
    }
    return nullptr;
}

struct PredictWork {
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    std::vector<float> input;
    std::vector<float> output;
    bool detector = false;
    std::exception_ptr error;
};

void Execute(napi_env, void* raw) noexcept
{
    auto* work = static_cast<PredictWork*>(raw);
    try {
        work->output = work->detector ? g_session.PredictDetector(work->input) : g_session.PredictRecognizer(work->input);
    } catch (...) {
        work->error = std::current_exception();
    }
}

void Complete(napi_env env, napi_status status, void* raw) noexcept
{
    std::unique_ptr<PredictWork> work(static_cast<PredictWork*>(raw));
    try {
        if (status != napi_ok) {
            Check(env, napi_reject_deferred(env, work->deferred, ErrorValue(env, "Native PP-OCR work was cancelled.")), "reject OCR cancellation");
        } else if (work->error != nullptr) {
            try {
                std::rethrow_exception(work->error);
            } catch (const std::exception& error) {
                Check(env, napi_reject_deferred(env, work->deferred, ErrorValue(env, error.what())), "reject OCR failure");
            }
        } else {
            napi_value buffer = nullptr;
            void* destination = nullptr;
            const size_t byteLength = work->output.size() * sizeof(float);
            Check(env, napi_create_arraybuffer(env, byteLength, &destination, &buffer), "create OCR output");
            std::memcpy(destination, work->output.data(), byteLength);
            Check(env, napi_resolve_deferred(env, work->deferred, buffer), "resolve OCR output");
        }
    } catch (const std::exception& error) {
        napi_reject_deferred(env, work->deferred, ErrorValue(env, error.what()));
    }
    if (work->work != nullptr) {
        napi_delete_async_work(env, work->work);
    }
}

napi_value Predict(napi_env env, napi_callback_info info, bool detector)
{
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    Check(env, napi_create_promise(env, &deferred, &promise), "create OCR promise");
    try {
        size_t argc = 1;
        napi_value argument = nullptr;
        Check(env, napi_get_cb_info(env, info, &argc, &argument, nullptr, nullptr), "read OCR input");
        bool typed = false;
        napi_typedarray_type type = napi_int8_array;
        size_t infoLength = 0;
        void* data = nullptr;
        napi_value backing = nullptr;
        size_t offset = 0;
        const size_t expected = detector ? kDetectorInputCount : kRecognizerInputCount;
        Check(env, napi_is_typedarray(env, argument, &typed), "check OCR input");
        Check(env, napi_get_typedarray_info(env, argument, &type, &infoLength, &data, &backing, &offset), "read OCR input");
        napi_value logicalLengthValue = nullptr;
        uint32_t logicalLength = 0;
        Check(env, napi_get_named_property(env, argument, "length", &logicalLengthValue), "read OCR input length");
        Check(env, napi_get_value_uint32(env, logicalLengthValue, &logicalLength), "read OCR logical length");
        // ponytail: API24 reports typed-array metadata in bytes; accept its documented equivalent.
        if (argc != 1 || !typed || type != napi_float32_array || data == nullptr || logicalLength != expected ||
            (infoLength != expected && infoLength != expected * sizeof(float))) {
            throw std::invalid_argument("PP-OCR input tensor contract mismatch.");
        }
        auto work = std::make_unique<PredictWork>();
        work->deferred = deferred;
        work->detector = detector;
        const float* values = static_cast<const float*>(data);
        work->input.assign(values, values + expected);
        napi_value name = nullptr;
        Check(env, napi_create_string_utf8(env, detector ? "ppocr_detector" : "ppocr_recognizer", NAPI_AUTO_LENGTH, &name), "create OCR work name");
        Check(env, napi_create_async_work(env, nullptr, name, Execute, Complete, work.get(), &work->work), "create OCR work");
        Check(env, napi_queue_async_work(env, work->work), "queue OCR work");
        work.release();
    } catch (const std::exception& error) {
        napi_reject_deferred(env, deferred, ErrorValue(env, error.what()));
    }
    return promise;
}

napi_value PredictDetector(napi_env env, napi_callback_info info) noexcept
{
    try { return Predict(env, info, true); } catch (const std::exception& error) { Throw(env, error.what()); }
    return nullptr;
}

napi_value PredictRecognizer(napi_env env, napi_callback_info info) noexcept
{
    try { return Predict(env, info, false); } catch (const std::exception& error) { Throw(env, error.what()); }
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
    napi_property_descriptor values[] = {
        {"loadModels", nullptr, LoadModels, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predictDetector", nullptr, PredictDetector, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"predictRecognizer", nullptr, PredictRecognizer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, Release, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    return napi_define_properties(env, exports, sizeof(values) / sizeof(values[0]), values) == napi_ok ? exports : nullptr;
}
}

static napi_module ocrModule = {1, 0, nullptr, Init, "ocr_mnn", nullptr, {0}};
extern "C" __attribute__((constructor)) void RegisterOcrMnnModule()
{
    napi_module_register(&ocrModule);
}
