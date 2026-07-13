#include <algorithm>
#include <cmath>
#include <cstring>
#include <iostream>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

#include "include/api/context.h"
#include "include/api/model.h"
#include "translation_runtime_contract.h"

using mindspore::DataType;
using mindspore::MSTensor;

static MSTensor &Find(std::vector<MSTensor> &tensors, const std::string &name) {
  auto it = std::find_if(tensors.begin(), tensors.end(), [&](const MSTensor &tensor) { return tensor.Name() == name; });
  if (it == tensors.end()) throw std::runtime_error("missing tensor: " + name);
  return *it;
}

static const MSTensor &Find(const std::vector<MSTensor> &tensors, const std::string &name) {
  auto it = std::find_if(tensors.begin(), tensors.end(), [&](const MSTensor &tensor) { return tensor.Name() == name; });
  if (it == tensors.end()) throw std::runtime_error("missing tensor: " + name);
  return *it;
}

static void RequireDescriptors(
    const std::string &label, const std::vector<MSTensor> &tensors,
    const std::vector<translation_contract::TensorDescriptor> &expected) {
  if (tensors.size() != expected.size()) throw std::runtime_error(label + " tensor count contract mismatch");
  for (const auto &descriptor : expected) {
    const auto &tensor = Find(tensors, descriptor.name);
    if (tensor.DataType() != descriptor.dtype) {
      throw std::runtime_error(label + " tensor dtype contract mismatch: " + descriptor.name);
    }
    if (tensor.Shape() != descriptor.shape) {
      throw std::runtime_error(label + " tensor shape contract mismatch: " + descriptor.name);
    }
  }
}

static void FillI32(MSTensor &tensor, int32_t value) {
  if (tensor.DataType() != DataType::kNumberTypeInt32) throw std::runtime_error("expected INT32: " + tensor.Name());
  auto *data = static_cast<int32_t *>(tensor.MutableData());
  std::fill(data, data + tensor.ElementNum(), value);
}

static void FillFloat(MSTensor &tensor, float value) {
  if (value != 0.0F) throw std::runtime_error("smoke helper only fills floating tensors with zero");
  if (tensor.DataType() != DataType::kNumberTypeFloat32) throw std::runtime_error("expected FLOAT32: " + tensor.Name());
  std::memset(tensor.MutableData(), 0, tensor.DataSize());
}

static float HalfToFloat(uint16_t bits) {
  const float sign = (bits & 0x8000U) ? -1.0F : 1.0F;
  const int exponent = (bits >> 10U) & 0x1FU;
  const int mantissa = bits & 0x03FFU;
  if (exponent == 0) return mantissa == 0 ? sign * 0.0F : sign * std::ldexp(static_cast<float>(mantissa), -24);
  if (exponent == 31) return mantissa == 0 ? sign * INFINITY : NAN;
  return sign * std::ldexp(static_cast<float>(1024 + mantissa), exponent - 25);
}

static float ValueAt(const MSTensor &tensor, int64_t index) {
  if (tensor.DataType() == DataType::kNumberTypeFloat32) {
    return static_cast<const float *>(tensor.Data().get())[index];
  }
  if (tensor.DataType() == DataType::kNumberTypeFloat16) {
    return HalfToFloat(static_cast<const uint16_t *>(tensor.Data().get())[index]);
  }
  throw std::runtime_error("unexpected output dtype: " + tensor.Name());
}

static void Copy(const MSTensor &source, MSTensor &target) {
  if (source.DataType() != target.DataType() || source.DataSize() != target.DataSize()) {
    throw std::runtime_error("tensor copy contract mismatch: " + source.Name() + " -> " + target.Name());
  }
  std::memcpy(target.MutableData(), source.Data().get(), source.DataSize());
}

static void ScatterCacheSlot(const MSTensor &source, MSTensor &target, int64_t position) {
  const auto source_shape = source.Shape();
  const auto target_shape = target.Shape();
  if (source.DataType() != target.DataType() || source_shape.size() != 4 || target_shape.size() != 4 ||
      source_shape[0] != target_shape[0] || source_shape[1] != target_shape[1] || source_shape[2] != 1 ||
      source_shape[3] != target_shape[3] || position < 0 || position >= target_shape[2]) {
    throw std::runtime_error("cache slot contract mismatch: " + source.Name() + " -> " + target.Name());
  }
  const size_t element_size = source.DataSize() / static_cast<size_t>(source.ElementNum());
  const size_t slot_size = static_cast<size_t>(source_shape[3]) * element_size;
  const auto *source_data = static_cast<const unsigned char *>(source.Data().get());
  auto *target_data = static_cast<unsigned char *>(target.MutableData());
  for (int64_t batch = 0; batch < source_shape[0]; ++batch) {
    for (int64_t head = 0; head < source_shape[1]; ++head) {
      const size_t source_offset = static_cast<size_t>(batch * source_shape[1] + head) * slot_size;
      const size_t target_offset =
          static_cast<size_t>(((batch * target_shape[1] + head) * target_shape[2] + position) * target_shape[3]) *
          element_size;
      std::memcpy(target_data + target_offset, source_data + source_offset, slot_size);
    }
  }
}

static void ReadFixture(const std::string &path, MSTensor &target) {
  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) throw std::runtime_error("cannot read fixture: " + path);
  if (static_cast<size_t>(stream.tellg()) != target.DataSize()) throw std::runtime_error("fixture size mismatch: " + path);
  stream.seekg(0);
  stream.read(static_cast<char *>(target.MutableData()), static_cast<std::streamsize>(target.DataSize()));
  if (!stream) throw std::runtime_error("fixture read failed: " + path);
}

static void CheckFinite(const std::vector<MSTensor> &outputs) {
  for (const auto &tensor : outputs) {
    if (tensor.DataType() != DataType::kNumberTypeFloat32) {
      throw std::runtime_error("MindSpore runtime contract requires FLOAT32: " + tensor.Name());
    }
    for (int64_t index = 0; index < tensor.ElementNum(); ++index) {
      if (!std::isfinite(ValueAt(tensor, index))) throw std::runtime_error("non-finite output: " + tensor.Name());
    }
  }
}

static int32_t Argmax(const MSTensor &tensor) {
  int32_t best = 0;
  float best_value = ValueAt(tensor, 0);
  for (int64_t index = 1; index < tensor.ElementNum(); ++index) {
    const float value = ValueAt(tensor, index);
    if (value > best_value) {
      best = static_cast<int32_t>(index);
      best_value = value;
    }
  }
  return best;
}

static mindspore::Model Build(const char *path, const std::shared_ptr<mindspore::Context> &context) {
  mindspore::Model model;
  auto status = model.Build(path, mindspore::ModelType::kMindIR_Lite, context);
  if (!status.IsOk()) throw std::runtime_error("model build failed: " + status.ToString());
  return model;
}

int main(int argc, char **argv) try {
  if (argc != 4 && argc != 5) return 2;
  auto context = std::make_shared<mindspore::Context>();
  context->SetThreadNum(2);
  context->MutableDeviceInfo().push_back(std::make_shared<mindspore::CPUDeviceInfo>());
  auto encoder = Build(argv[1], context);
  auto prefill = Build(argv[2], context);
  auto step = Build(argv[3], context);

  auto encoder_inputs = encoder.GetInputs();
  RequireDescriptors("encoder inputs", encoder_inputs, translation_contract::kEncoderInputs);
  auto &encoder_ids = Find(encoder_inputs, "input_ids");
  auto *encoder_id_data = static_cast<int32_t *>(encoder_ids.MutableData());
  for (int64_t index = 0; index < encoder_ids.ElementNum(); ++index) encoder_id_data[index] = static_cast<int32_t>(index);
  auto &encoder_mask = Find(encoder_inputs, "attention_mask");
  FillI32(encoder_mask, 0);
  std::fill(static_cast<int32_t *>(encoder_mask.MutableData()),
            static_cast<int32_t *>(encoder_mask.MutableData()) + encoder_mask.ElementNum() / 2, 1);
  std::vector<MSTensor> encoder_outputs;
  auto status = encoder.Predict(encoder_inputs, &encoder_outputs);
  if (!status.IsOk()) throw std::runtime_error(status.ToString());
  RequireDescriptors("encoder outputs", encoder_outputs, translation_contract::kEncoderOutputs);
  CheckFinite(encoder_outputs);

  auto prefill_inputs = prefill.GetInputs();
  RequireDescriptors("prefill inputs", prefill_inputs, translation_contract::kDecoderPrefillInputs);
  FillI32(Find(prefill_inputs, "decoder_input_ids"), 32000);
  auto &prefill_mask = Find(prefill_inputs, "encoder_attention_mask");
  FillI32(prefill_mask, 0);
  std::fill(static_cast<int32_t *>(prefill_mask.MutableData()),
            static_cast<int32_t *>(prefill_mask.MutableData()) + prefill_mask.ElementNum() / 2, 1);
  if (argc == 5) {
    const std::string fixture_root = argv[4];
    ReadFixture(fixture_root + "\\pre_01_encoder.bin", Find(prefill_inputs, "encoder_hidden_states"));
    ReadFixture(fixture_root + "\\pre_02_mask.bin", Find(prefill_inputs, "encoder_attention_mask"));
  } else {
    Copy(Find(encoder_outputs, "last_hidden_state"), Find(prefill_inputs, "encoder_hidden_states"));
  }
  std::vector<MSTensor> prefill_outputs;
  status = prefill.Predict(prefill_inputs, &prefill_outputs);
  if (!status.IsOk()) throw std::runtime_error(status.ToString());
  RequireDescriptors("prefill outputs", prefill_outputs, translation_contract::kDecoderPrefillOutputs);
  CheckFinite(prefill_outputs);

  int32_t token = Argmax(Find(prefill_outputs, "logits"));
  std::vector<int32_t> tokens{token};
  auto step_inputs = step.GetInputs();
  RequireDescriptors("step inputs", step_inputs, translation_contract::kDecoderStepInputs);
  auto &step_cross_mask = Find(step_inputs, "cross_attention_mask");
  FillI32(step_cross_mask, 0);
  std::fill(static_cast<int32_t *>(step_cross_mask.MutableData()),
            static_cast<int32_t *>(step_cross_mask.MutableData()) + step_cross_mask.ElementNum() / 2, 1);
  for (int layer = 0; layer < 2; ++layer) {
    auto &past_key = Find(step_inputs, "past_key_" + std::to_string(layer));
    auto &past_value = Find(step_inputs, "past_value_" + std::to_string(layer));
    FillFloat(past_key, 0.0F);
    FillFloat(past_value, 0.0F);
    const auto &self_key = Find(prefill_outputs, "self_key_" + std::to_string(layer));
    const auto &self_value = Find(prefill_outputs, "self_value_" + std::to_string(layer));
    ScatterCacheSlot(self_key, past_key, 0);
    ScatterCacheSlot(self_value, past_value, 0);
    Copy(Find(prefill_outputs, "cross_key_" + std::to_string(layer)),
         Find(step_inputs, "cross_key_" + std::to_string(layer)));
    Copy(Find(prefill_outputs, "cross_value_" + std::to_string(layer)),
         Find(step_inputs, "cross_value_" + std::to_string(layer)));
  }
  if (argc == 5) {
    const std::string fixture_root = argv[4];
    ReadFixture(fixture_root + "\\step_00_ids.bin", Find(step_inputs, "decoder_input_ids"));
    token = *static_cast<int32_t *>(Find(step_inputs, "decoder_input_ids").MutableData());
    tokens = {token};
    for (int layer = 0; layer < 2; ++layer) {
      const int offset = 4 + layer * 4;
      ReadFixture(fixture_root + "\\step_" + (offset < 10 ? "0" : "") + std::to_string(offset) + "_past_key_" + std::to_string(layer) + ".bin",
                  Find(step_inputs, "past_key_" + std::to_string(layer)));
      ReadFixture(fixture_root + "\\step_" + (offset + 1 < 10 ? "0" : "") + std::to_string(offset + 1) + "_past_value_" + std::to_string(layer) + ".bin",
                  Find(step_inputs, "past_value_" + std::to_string(layer)));
      ReadFixture(fixture_root + "\\step_" + (offset + 2 < 10 ? "0" : "") + std::to_string(offset + 2) + "_cross_key_" + std::to_string(layer) + ".bin",
                  Find(step_inputs, "cross_key_" + std::to_string(layer)));
      ReadFixture(fixture_root + "\\step_" + (offset + 3 < 10 ? "0" : "") + std::to_string(offset + 3) + "_cross_value_" + std::to_string(layer) + ".bin",
                  Find(step_inputs, "cross_value_" + std::to_string(layer)));
    }
  }

  for (int32_t position = 1; position <= 5; ++position) {
    FillI32(Find(step_inputs, "decoder_input_ids"), token);
    FillI32(Find(step_inputs, "position_id"), position);
    auto &mask = Find(step_inputs, "self_attention_mask");
    FillI32(mask, 0);
    auto *mask_data = static_cast<int32_t *>(mask.MutableData());
    std::fill(mask_data, mask_data + position, 1);
    mask_data[mask.ElementNum() - 1] = 1;
    std::vector<MSTensor> step_outputs;
    status = step.Predict(step_inputs, &step_outputs);
    if (!status.IsOk()) throw std::runtime_error(status.ToString());
    RequireDescriptors("step outputs", step_outputs, translation_contract::kDecoderStepOutputs);
    CheckFinite(step_outputs);
    token = Argmax(Find(step_outputs, "logits"));
    tokens.push_back(token);
    for (int layer = 0; layer < 2; ++layer) {
      auto &past_key = Find(step_inputs, "past_key_" + std::to_string(layer));
      auto &past_value = Find(step_inputs, "past_value_" + std::to_string(layer));
      const auto &new_key = Find(step_outputs, "new_key_" + std::to_string(layer));
      const auto &new_value = Find(step_outputs, "new_value_" + std::to_string(layer));
      ScatterCacheSlot(new_key, past_key, position);
      ScatterCacheSlot(new_value, past_value, position);
    }
  }
  std::cout << "TOKENS";
  for (int32_t value : tokens) std::cout << " " << value;
  std::cout << std::endl;
  return 0;
} catch (const std::exception &error) {
  std::cerr << error.what() << std::endl;
  return 1;
}
