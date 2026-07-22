// Persistent three-graph Marian cache loop for MindSpore Lite parity checks.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#include "include/c_api/model_c.h"

namespace fs = std::filesystem;

template <typename T>
std::vector<T> ReadBinary(const fs::path &path) {
  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) throw std::runtime_error("cannot open input: " + path.string());
  auto bytes = static_cast<size_t>(stream.tellg());
  if (bytes % sizeof(T) != 0) throw std::runtime_error("misaligned input: " + path.string());
  stream.seekg(0);
  std::vector<T> values(bytes / sizeof(T));
  if (!stream.read(reinterpret_cast<char *>(values.data()), static_cast<std::streamsize>(bytes))) {
    throw std::runtime_error("cannot read input: " + path.string());
  }
  return values;
}

MSTensorHandle FindTensor(const MSTensorHandleArray &tensors, const std::string &name) {
  for (size_t index = 0; index < tensors.handle_num; ++index) {
    if (name == MSTensorGetName(tensors.handle_list[index])) return tensors.handle_list[index];
  }
  throw std::runtime_error("missing tensor: " + name);
}

template <typename T>
void SetInput(const MSTensorHandleArray &inputs, const std::string &name, const std::vector<T> &values,
              MSDataType expected_type) {
  auto tensor = FindTensor(inputs, name);
  if (MSTensorGetDataType(tensor) != expected_type || MSTensorGetDataSize(tensor) != values.size() * sizeof(T)) {
    throw std::runtime_error("input contract differs: " + name);
  }
  std::memcpy(MSTensorGetMutableData(tensor), values.data(), values.size() * sizeof(T));
}

std::vector<float> FloatOutput(const MSTensorHandleArray &outputs, const std::string &name) {
  auto tensor = FindTensor(outputs, name);
  if (MSTensorGetDataType(tensor) != kMSDataTypeNumberTypeFloat32 || MSTensorGetDataSize(tensor) % sizeof(float)) {
    throw std::runtime_error("float output contract differs: " + name);
  }
  size_t count = MSTensorGetDataSize(tensor) / sizeof(float);
  auto begin = static_cast<const float *>(MSTensorGetData(tensor));
  std::vector<float> values(begin, begin + count);
  if (!std::all_of(values.begin(), values.end(), [](float value) { return std::isfinite(value); })) {
    throw std::runtime_error("non-finite output: " + name);
  }
  return values;
}

MSTensorHandleArray Predict(MSModelHandle model) {
  auto inputs = MSModelGetInputs(model);
  MSTensorHandleArray outputs{};
  int status = MSModelPredict(model, inputs, &outputs, nullptr, nullptr);
  if (status != kMSStatusSuccess) throw std::runtime_error("MSModelPredict failed: " + std::to_string(status));
  return outputs;
}

MSModelHandle Build(const fs::path &path) {
  auto context = MSContextCreate();
  MSContextSetThreadNum(context, 2);
  MSContextSetThreadAffinityMode(context, 0);
  auto cpu = MSDeviceInfoCreate(kMSDeviceTypeCPU);
  MSDeviceInfoSetEnableFP16(cpu, false);
  MSContextAddDeviceInfo(context, cpu);
  auto model = MSModelCreate();
  int status = MSModelBuildFromFile(model, path.c_str(), kMSModelTypeMindIR, context);
  if (status != kMSStatusSuccess) throw std::runtime_error("MSModelBuildFromFile failed: " + std::to_string(status));
  return model;
}

int32_t ArgMax(const std::vector<float> &logits) {
  return static_cast<int32_t>(std::distance(logits.begin(), std::max_element(logits.begin(), logits.end())));
}

int Run(const fs::path &encoder_path, const fs::path &prefill_path, const fs::path &decoder_step_path,
        const fs::path &ids_path, const fs::path &mask_path, int32_t start_token, int layers, int steps,
        const fs::path &report_path) {
  if (steps < 1 || steps > 100) throw std::runtime_error("steps must be in [1,100]");
  auto ids = ReadBinary<int32_t>(ids_path);
  auto mask = ReadBinary<int32_t>(mask_path);
  if (ids.size() != mask.size() || ids.empty()) throw std::runtime_error("encoder input lengths differ");
  const size_t max_tokens = ids.size();

  auto encoder = Build(encoder_path);
  auto prefill = Build(prefill_path);
  auto decoder_step = Build(decoder_step_path);

  auto encoder_inputs = MSModelGetInputs(encoder);
  SetInput(encoder_inputs, "input_ids", ids, kMSDataTypeNumberTypeInt32);
  SetInput(encoder_inputs, "attention_mask", mask, kMSDataTypeNumberTypeInt32);
  auto hidden = FloatOutput(Predict(encoder), "last_hidden_state");

  auto prefill_inputs = MSModelGetInputs(prefill);
  SetInput(prefill_inputs, "decoder_input_ids", std::vector<int32_t>{start_token}, kMSDataTypeNumberTypeInt32);
  SetInput(prefill_inputs, "encoder_hidden_states", hidden, kMSDataTypeNumberTypeFloat32);
  SetInput(prefill_inputs, "encoder_attention_mask", mask, kMSDataTypeNumberTypeInt32);
  auto prefill_outputs = Predict(prefill);
  int32_t token = ArgMax(FloatOutput(prefill_outputs, "logits"));
  std::vector<int32_t> tokens{token};

  std::vector<std::vector<float>> past_keys, past_values, cross_keys, cross_values;
  for (int layer = 0; layer < layers; ++layer) {
    auto self_key = FloatOutput(prefill_outputs, "self_key_" + std::to_string(layer));
    auto self_value = FloatOutput(prefill_outputs, "self_value_" + std::to_string(layer));
    auto cross_key = FloatOutput(prefill_outputs, "cross_key_" + std::to_string(layer));
    auto cross_value = FloatOutput(prefill_outputs, "cross_value_" + std::to_string(layer));
    if (self_key.size() != self_value.size() || cross_key.size() != cross_value.size() ||
        cross_key.size() != self_key.size() * max_tokens) {
      throw std::runtime_error("prefill cache shapes differ");
    }
    size_t head_slice = self_key.size();
    size_t past_head_stride = (max_tokens - 1) * (head_slice / 8);
    size_t head_dim = head_slice / 8;
    std::vector<float> past_key(head_slice * (max_tokens - 1), 0.0f);
    std::vector<float> past_value(past_key.size(), 0.0f);
    for (size_t head = 0; head < 8; ++head) {
      std::copy_n(self_key.begin() + head * head_dim, head_dim,
                  past_key.begin() + head * past_head_stride);
      std::copy_n(self_value.begin() + head * head_dim, head_dim,
                  past_value.begin() + head * past_head_stride);
    }
    past_keys.push_back(std::move(past_key));
    past_values.push_back(std::move(past_value));
    cross_keys.push_back(std::move(cross_key));
    cross_values.push_back(std::move(cross_value));
  }

  for (int position = 1; position <= steps; ++position) {
    auto step_inputs = MSModelGetInputs(decoder_step);
    SetInput(step_inputs, "decoder_input_ids", std::vector<int32_t>{token}, kMSDataTypeNumberTypeInt32);
    SetInput(step_inputs, "position_id", std::vector<int32_t>{position}, kMSDataTypeNumberTypeInt32);
    std::vector<int32_t> self_mask(max_tokens, 0);
    std::fill(self_mask.begin(), self_mask.begin() + position, 1);
    self_mask.back() = 1;
    SetInput(step_inputs, "self_attention_mask", self_mask, kMSDataTypeNumberTypeInt32);
    SetInput(step_inputs, "cross_attention_mask", mask, kMSDataTypeNumberTypeInt32);
    for (int layer = 0; layer < layers; ++layer) {
      SetInput(step_inputs, "past_key_" + std::to_string(layer), past_keys[layer],
               kMSDataTypeNumberTypeFloat32);
      SetInput(step_inputs, "past_value_" + std::to_string(layer), past_values[layer],
               kMSDataTypeNumberTypeFloat32);
      SetInput(step_inputs, "cross_key_" + std::to_string(layer), cross_keys[layer],
               kMSDataTypeNumberTypeFloat32);
      SetInput(step_inputs, "cross_value_" + std::to_string(layer), cross_values[layer],
               kMSDataTypeNumberTypeFloat32);
    }
    auto step_outputs = Predict(decoder_step);
    token = ArgMax(FloatOutput(step_outputs, "logits"));
    tokens.push_back(token);
    for (int layer = 0; layer < layers; ++layer) {
      auto new_key = FloatOutput(step_outputs, "new_key_" + std::to_string(layer));
      auto new_value = FloatOutput(step_outputs, "new_value_" + std::to_string(layer));
      size_t head_dim = new_key.size() / 8;
      size_t head_stride = (max_tokens - 1) * head_dim;
      for (size_t head = 0; head < 8; ++head) {
        std::copy_n(new_key.begin() + head * head_dim, head_dim,
                    past_keys[layer].begin() + head * head_stride + position * head_dim);
        std::copy_n(new_value.begin() + head * head_dim, head_dim,
                    past_values[layer].begin() + head * head_stride + position * head_dim);
      }
    }
  }

  fs::create_directories(report_path.parent_path());
  std::ofstream report(report_path);
  report << "{\n  \"schemaVersion\": 1,\n  \"steps\": " << steps
         << ",\n  \"finite\": true,\n  \"tokens\": [";
  for (size_t index = 0; index < tokens.size(); ++index) {
    if (index) report << ", ";
    report << tokens[index];
  }
  report << "]\n}\n";
  std::cout << "wrote " << report_path << '\n';
  MSModelDestroy(&decoder_step);
  MSModelDestroy(&prefill);
  MSModelDestroy(&encoder);
  return 0;
}

int main(int argc, char **argv) {
  if (argc != 10) {
    std::cerr << "usage: cache-loop ENCODER PREFILL STEP IDS MASK START_TOKEN LAYERS STEPS REPORT\n";
    return 64;
  }
  try {
    return Run(argv[1], argv[2], argv[3], argv[4], argv[5], std::stoi(argv[6]), std::stoi(argv[7]),
               std::stoi(argv[8]), argv[9]);
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
