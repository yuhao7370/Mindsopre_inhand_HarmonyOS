// Persistent two-graph Marian greedy/beam loop for MindSpore Lite parity checks.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <numeric>
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
  if (bytes % sizeof(T)) throw std::runtime_error("misaligned input: " + path.string());
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

void RequireTensor(MSTensorHandle tensor, const std::string &name, MSDataType data_type,
                   const std::vector<int64_t> &expected_shape) {
  if (name != MSTensorGetName(tensor) || MSTensorGetDataType(tensor) != data_type) {
    throw std::runtime_error("tensor name/dtype differs: " + name);
  }
  size_t rank = 0;
  const int64_t *shape = MSTensorGetShape(tensor, &rank);
  if (rank != expected_shape.size() ||
      !std::equal(shape, shape + static_cast<std::ptrdiff_t>(rank), expected_shape.begin())) {
    throw std::runtime_error("tensor shape differs: " + name);
  }
}

template <typename T>
void SetInput(const MSTensorHandleArray &inputs, const std::string &name,
              const std::vector<T> &values, MSDataType expected_type) {
  auto tensor = FindTensor(inputs, name);
  if (MSTensorGetDataType(tensor) != expected_type ||
      MSTensorGetDataSize(tensor) != values.size() * sizeof(T)) {
    throw std::runtime_error("input contract differs: " + name);
  }
  std::memcpy(MSTensorGetMutableData(tensor), values.data(), values.size() * sizeof(T));
}

std::vector<float> FloatOutput(const MSTensorHandleArray &outputs, const std::string &name) {
  auto tensor = FindTensor(outputs, name);
  if (MSTensorGetDataType(tensor) != kMSDataTypeNumberTypeFloat32 ||
      MSTensorGetDataSize(tensor) % sizeof(float)) {
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
  if (status != kMSStatusSuccess) {
    throw std::runtime_error("MSModelPredict failed: " + std::to_string(status));
  }
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
  if (status != kMSStatusSuccess) {
    throw std::runtime_error("MSModelBuildFromFile failed: " + std::to_string(status));
  }
  return model;
}

struct Beam {
  std::vector<int32_t> tokens;
  float score;
};

struct Hypothesis {
  std::vector<int32_t> tokens;
  float normalized_score;
};

struct BeamCandidate {
  Beam beam;
  int32_t token;
  float score;
};

int32_t GreedyToken(const std::vector<float> &row, int32_t pad_token,
                    int32_t eos_token, bool force_eos) {
  if (pad_token < 0 || eos_token < 0 || pad_token == eos_token ||
      static_cast<size_t>(pad_token) >= row.size() ||
      static_cast<size_t>(eos_token) >= row.size()) {
    throw std::runtime_error("greedy special token is outside decoder vocabulary");
  }
  if (force_eos) return eos_token;
  int32_t best_token = -1;
  float best_score = -INFINITY;
  for (size_t index = 0; index < row.size(); ++index) {
    if (static_cast<int32_t>(index) != pad_token && row[index] > best_score) {
      best_score = row[index];
      best_token = static_cast<int32_t>(index);
    }
  }
  if (best_token < 0) throw std::runtime_error("greedy decoder produced no candidate");
  return best_token;
}

void ValidateDirectionContract(
    size_t source_length, size_t target_length, size_t hidden_size, size_t vocab_size,
    int32_t start_token, int32_t eos_token, int32_t pad_token, size_t beam_count) {
  if (source_length != 128 || target_length != 32) {
    throw std::runtime_error("translation sequence contract differs");
  }
  bool chinese_to_english =
      hidden_size == 256 && vocab_size == 32001 && start_token == 32000 &&
      eos_token == 0 && pad_token == 32000 && beam_count == 1;
  bool english_to_chinese =
      hidden_size == 512 && vocab_size == 65001 && start_token == 65000 &&
      eos_token == 0 && pad_token == 65000 && beam_count == 4;
  if (!chinese_to_english && !english_to_chinese) {
    throw std::runtime_error("translation direction/model strategy contract differs");
  }
}

void KeepGlobalTop(std::vector<BeamCandidate> &candidates, size_t count) {
  std::sort(candidates.begin(), candidates.end(), [](const BeamCandidate &left,
                                                       const BeamCandidate &right) {
    return left.score > right.score;
  });
  if (candidates.size() > count) candidates.resize(count);
}

std::vector<std::pair<int32_t, float>> TopLogProbabilities(
    const std::vector<float> &row, size_t count, int32_t pad_token,
    int32_t eos_token, bool force_eos) {
  if (force_eos) return {{eos_token, 0.0f}};
  if (pad_token < 0 || static_cast<size_t>(pad_token) >= row.size()) {
    throw std::runtime_error("pad token is outside decoder vocabulary");
  }
  float maximum = *std::max_element(row.begin(), row.end());
  double total = 0.0;
  for (float value : row) total += std::exp(value - maximum);
  float log_denominator = maximum + static_cast<float>(std::log(total));
  std::vector<int32_t> indices(row.size());
  std::iota(indices.begin(), indices.end(), 0);
  count = std::min(count, row.size() - 1);
  std::partial_sort(
      indices.begin(), indices.begin() + static_cast<std::ptrdiff_t>(count), indices.end(),
      [&](int32_t left, int32_t right) {
        float left_value = left == pad_token ? -INFINITY : row[left];
        float right_value = right == pad_token ? -INFINITY : row[right];
        return left_value > right_value;
      });
  std::vector<std::pair<int32_t, float>> result;
  for (size_t index = 0; index < count; ++index) {
    int32_t token = indices[index];
    if (token != pad_token) result.emplace_back(token, row[token] - log_denominator);
  }
  return result;
}

std::vector<float> DecoderRow(
    MSModelHandle decoder, const MSTensorHandleArray &decoder_inputs,
    const std::vector<float> &hidden, const std::vector<int32_t> &source_mask,
    const std::vector<int32_t> &generated, int32_t start_token, int32_t pad_token,
    size_t target_length, size_t vocab_size) {
  if (generated.size() + 1 > target_length) throw std::runtime_error("decoder sequence is too long");
  std::vector<int32_t> decoder_ids(target_length, pad_token);
  std::vector<int32_t> decoder_mask(target_length, 0);
  decoder_ids[0] = start_token;
  decoder_mask[0] = 1;
  for (size_t index = 0; index < generated.size(); ++index) {
    decoder_ids[index + 1] = generated[index];
    decoder_mask[index + 1] = 1;
  }
  SetInput(decoder_inputs, "decoder_input_ids", decoder_ids, kMSDataTypeNumberTypeInt32);
  SetInput(decoder_inputs, "decoder_attention_mask", decoder_mask, kMSDataTypeNumberTypeInt32);
  SetInput(decoder_inputs, "encoder_hidden_states", hidden, kMSDataTypeNumberTypeFloat32);
  SetInput(decoder_inputs, "encoder_attention_mask", source_mask, kMSDataTypeNumberTypeInt32);
  auto outputs = Predict(decoder);
  if (outputs.handle_num != 1) throw std::runtime_error("decoder output count differs");
  RequireTensor(
      outputs.handle_list[0], "logits", kMSDataTypeNumberTypeFloat32,
      {1, static_cast<int64_t>(target_length), static_cast<int64_t>(vocab_size)});
  auto logits = FloatOutput(outputs, "logits");
  size_t position = generated.size();
  auto begin = logits.begin() + static_cast<std::ptrdiff_t>(position * vocab_size);
  return std::vector<float>(begin, begin + static_cast<std::ptrdiff_t>(vocab_size));
}

void AddHypothesis(std::vector<Hypothesis> &completed, const Beam &beam,
                   float score, size_t generated_length, size_t beam_count) {
  Hypothesis hypothesis{beam.tokens, score / static_cast<float>(generated_length)};
  completed.push_back(std::move(hypothesis));
  std::sort(completed.begin(), completed.end(), [](const Hypothesis &left, const Hypothesis &right) {
    return left.normalized_score > right.normalized_score;
  });
  if (completed.size() > beam_count) completed.resize(beam_count);
}

int Run(const fs::path &encoder_path, const fs::path &decoder_path,
        const fs::path &ids_path, const fs::path &mask_path, int32_t start_token,
        int32_t eos_token, int32_t pad_token, size_t beam_count,
        const fs::path &report_path) {
  if (beam_count != 1 && beam_count != 4) throw std::runtime_error("beam count must be 1 or 4");
  auto source_ids = ReadBinary<int32_t>(ids_path);
  auto source_mask = ReadBinary<int32_t>(mask_path);
  if (source_ids.empty() || source_ids.size() != source_mask.size()) {
    throw std::runtime_error("encoder input lengths differ");
  }
  if (source_ids.size() != 128) throw std::runtime_error("encoder source length must be 128");

  auto encoder = Build(encoder_path);
  auto decoder = Build(decoder_path);
  auto encoder_inputs = MSModelGetInputs(encoder);
  if (encoder_inputs.handle_num != 2) throw std::runtime_error("encoder input count differs");
  RequireTensor(
      FindTensor(encoder_inputs, "input_ids"), "input_ids", kMSDataTypeNumberTypeInt32,
      {1, static_cast<int64_t>(source_ids.size())});
  RequireTensor(
      FindTensor(encoder_inputs, "attention_mask"), "attention_mask", kMSDataTypeNumberTypeInt32,
      {1, static_cast<int64_t>(source_ids.size())});
  SetInput(encoder_inputs, "input_ids", source_ids, kMSDataTypeNumberTypeInt32);
  SetInput(encoder_inputs, "attention_mask", source_mask, kMSDataTypeNumberTypeInt32);
  auto encoder_outputs = Predict(encoder);
  if (encoder_outputs.handle_num != 1) throw std::runtime_error("encoder output count differs");
  auto hidden_tensor = FindTensor(encoder_outputs, "last_hidden_state");
  size_t hidden_rank = 0;
  const int64_t *hidden_shape = MSTensorGetShape(hidden_tensor, &hidden_rank);
  if (hidden_rank != 3 || hidden_shape[0] != 1 ||
      hidden_shape[1] != static_cast<int64_t>(source_ids.size()) || hidden_shape[2] <= 0) {
    throw std::runtime_error("encoder output shape differs");
  }
  RequireTensor(
      hidden_tensor, "last_hidden_state", kMSDataTypeNumberTypeFloat32,
      {1, static_cast<int64_t>(source_ids.size()), hidden_shape[2]});
  auto hidden = FloatOutput(encoder_outputs, "last_hidden_state");

  auto decoder_inputs = MSModelGetInputs(decoder);
  if (decoder_inputs.handle_num != 4) throw std::runtime_error("decoder input count differs");
  auto ids_tensor = FindTensor(decoder_inputs, "decoder_input_ids");
  size_t rank = 0;
  const int64_t *shape = MSTensorGetShape(ids_tensor, &rank);
  if (rank != 2 || shape[0] != 1 || shape[1] < 2 || shape[1] > 100) {
    throw std::runtime_error("decoder target shape differs");
  }
  size_t target_length = static_cast<size_t>(shape[1]);
  if (target_length != 32) throw std::runtime_error("decoder target length must be 32");
  if (pad_token < 0) throw std::runtime_error("pad token is outside decoder vocabulary");
  size_t vocab_size = static_cast<size_t>(pad_token) + 1;
  ValidateDirectionContract(
      source_ids.size(), target_length, static_cast<size_t>(hidden_shape[2]), vocab_size,
      start_token, eos_token, pad_token, beam_count);
  RequireTensor(
      ids_tensor, "decoder_input_ids", kMSDataTypeNumberTypeInt32,
      {1, static_cast<int64_t>(target_length)});
  RequireTensor(
      FindTensor(decoder_inputs, "decoder_attention_mask"), "decoder_attention_mask",
      kMSDataTypeNumberTypeInt32, {1, static_cast<int64_t>(target_length)});
  RequireTensor(
      FindTensor(decoder_inputs, "encoder_hidden_states"), "encoder_hidden_states",
      kMSDataTypeNumberTypeFloat32,
      {1, static_cast<int64_t>(source_ids.size()), hidden_shape[2]});
  RequireTensor(
      FindTensor(decoder_inputs, "encoder_attention_mask"), "encoder_attention_mask",
      kMSDataTypeNumberTypeInt32, {1, static_cast<int64_t>(source_ids.size())});
  std::vector<int32_t> tokens;
  if (beam_count == 1) {
    for (size_t position = 0; position < target_length - 1; ++position) {
      auto row = DecoderRow(
          decoder, decoder_inputs, hidden, source_mask, tokens,
          start_token, pad_token, target_length, vocab_size);
      bool force_eos = position == target_length - 2;
      int32_t token = GreedyToken(row, pad_token, eos_token, force_eos);
      tokens.push_back(token);
      if (token == eos_token) break;
    }
  } else {
    std::vector<Beam> active{{{}, 0.0f}};
    std::vector<Hypothesis> completed;
    bool done = false;
    for (size_t position = 0; position < target_length - 1 && !done; ++position) {
      std::vector<BeamCandidate> candidates;
      bool force_eos = position == target_length - 2;
      for (const auto &beam : active) {
        auto row = DecoderRow(
            decoder, decoder_inputs, hidden, source_mask, beam.tokens,
            start_token, pad_token, target_length, vocab_size);
        for (const auto &[token, log_probability] :
             TopLogProbabilities(row, beam_count * 2, pad_token, eos_token, force_eos)) {
          candidates.push_back({beam, token, beam.score + log_probability});
        }
      }
      KeepGlobalTop(candidates, beam_count * 2);
      if (candidates.empty()) throw std::runtime_error("beam decoder produced no candidate");
      std::vector<Beam> next_active;
      for (size_t rank_index = 0; rank_index < candidates.size(); ++rank_index) {
        const auto &candidate = candidates[rank_index];
        if (candidate.token == eos_token) {
          if (rank_index < beam_count) {
            AddHypothesis(
                completed, candidate.beam, candidate.score,
                position + 1, beam_count);
          }
        } else if (next_active.size() < beam_count) {
          Beam next = candidate.beam;
          next.tokens.push_back(candidate.token);
          next.score = candidate.score;
          next_active.push_back(std::move(next));
        }
        if (next_active.size() == beam_count) break;
      }
      if (next_active.size() < beam_count && !force_eos) {
        throw std::runtime_error("beam decoder did not fill active beams");
      }
      if (completed.size() == beam_count) {
        float worst_completed = completed.back().normalized_score;
        float best_possible = candidates.front().score / static_cast<float>(position + 1);
        done = worst_completed >= best_possible;
      }
      active = std::move(next_active);
    }
    if (!done) {
      for (const auto &beam : active) {
        AddHypothesis(
            completed, beam, beam.score,
            std::max<size_t>(1, beam.tokens.size()), beam_count);
      }
    }
    if (completed.empty()) throw std::runtime_error("beam decoder produced no hypothesis");
    tokens = completed.front().tokens;
    if (tokens.size() < target_length - 1) tokens.push_back(eos_token);
  }

  fs::create_directories(report_path.parent_path());
  std::ofstream report(report_path);
  report << "{\n  \"schemaVersion\": 1,\n  \"finite\": true,\n  \"numBeams\": "
         << beam_count << ",\n  \"tokens\": [";
  for (size_t index = 0; index < tokens.size(); ++index) {
    if (index) report << ", ";
    report << tokens[index];
  }
  report << "]\n}\n";
  std::cout << "wrote " << report_path << '\n';
  MSModelDestroy(&decoder);
  MSModelDestroy(&encoder);
  return 0;
}

template <typename Callback>
bool Throws(Callback callback) {
  try {
    callback();
    return false;
  } catch (const std::runtime_error &) {
    return true;
  }
}

int SelfTest() {
  if (GreedyToken({0.0f, 5.0f, 4.0f}, 2, 0, false) != 1) return 1;
  if (GreedyToken({4.0f, 5.0f, 100.0f}, 2, 0, false) != 1) return 2;
  if (GreedyToken({4.0f, 5.0f, 100.0f}, 2, 0, true) != 0) return 3;
  auto masked = TopLogProbabilities({10.0f, 9.0f, 8.0f, 100.0f}, 2, 3, 0, false);
  if (masked.size() != 2 || masked[0].first != 0 || masked[1].first != 1) return 4;
  auto forced = TopLogProbabilities({10.0f, 9.0f}, 2, 1, 0, true);
  if (forced.size() != 1 || forced[0] != std::make_pair<int32_t, float>(0, 0.0f)) return 5;
  ValidateDirectionContract(128, 32, 256, 32001, 32000, 0, 32000, 1);
  ValidateDirectionContract(128, 32, 512, 65001, 65000, 0, 65000, 4);
  if (!Throws([] { ValidateDirectionContract(127, 32, 256, 32001, 32000, 0, 32000, 1); })) return 6;
  if (!Throws([] { ValidateDirectionContract(128, 31, 256, 32001, 32000, 0, 32000, 1); })) return 7;
  if (!Throws([] { ValidateDirectionContract(128, 32, 512, 32001, 32000, 0, 32000, 1); })) return 8;
  if (!Throws([] { ValidateDirectionContract(128, 32, 256, 65001, 65000, 0, 65000, 4); })) return 9;
  if (!Throws([] { ValidateDirectionContract(128, 32, 256, 32001, 32000, 0, 32000, 4); })) return 10;
  if (!Throws([] { ValidateDirectionContract(128, 32, 256, 32001, 32000, 1, 32000, 1); })) return 11;
  std::vector<BeamCandidate> candidates{
      {{{1}, 0.0f}, 10, 1.0f}, {{{1}, 0.0f}, 11, 0.2f},
      {{{2}, 0.0f}, 20, 0.8f}, {{{2}, 0.0f}, 21, 0.7f},
  };
  KeepGlobalTop(candidates, 2);
  if (candidates.size() != 2 || candidates[0].token != 10 || candidates[1].token != 20) return 12;
  std::cout << "self-test passed\n";
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 2 && std::string(argv[1]) == "--self-test") return SelfTest();
  if (argc != 10) {
    std::cerr << "usage: full-loop ENCODER DECODER IDS MASK START EOS PAD BEAMS REPORT\n";
    return 64;
  }
  try {
    return Run(argv[1], argv[2], argv[3], argv[4], std::stoi(argv[5]),
               std::stoi(argv[6]), std::stoi(argv[7]), std::stoi(argv[8]), argv[9]);
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
