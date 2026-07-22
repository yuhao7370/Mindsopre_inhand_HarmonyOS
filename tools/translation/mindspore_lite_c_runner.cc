// Runs one MindSpore Lite graph with named binary inputs and dumps every output.
#include <algorithm>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "include/c_api/model_c.h"

namespace fs = std::filesystem;

std::vector<char> ReadFile(const fs::path &path) {
  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) throw std::runtime_error("cannot open input: " + path.string());
  auto size = stream.tellg();
  stream.seekg(0);
  std::vector<char> data(static_cast<size_t>(size));
  if (!stream.read(data.data(), size)) throw std::runtime_error("cannot read input: " + path.string());
  return data;
}

std::string SafeName(std::string name) {
  std::replace_if(name.begin(), name.end(), [](char value) { return value == '/' || value == '\\'; }, '_');
  return name;
}

int Run(const fs::path &model_path, const fs::path &output_root,
        const std::map<std::string, fs::path> &input_paths) {
  MSContextHandle context = MSContextCreate();
  MSContextSetThreadNum(context, 2);
  MSContextSetThreadAffinityMode(context, 0);
  MSDeviceInfoHandle cpu = MSDeviceInfoCreate(kMSDeviceTypeCPU);
  MSDeviceInfoSetEnableFP16(cpu, false);
  MSContextAddDeviceInfo(context, cpu);

  MSModelHandle model = MSModelCreate();
  int status = MSModelBuildFromFile(model, model_path.c_str(), kMSModelTypeMindIR, context);
  if (status != kMSStatusSuccess) {
    std::cerr << "MSModelBuildFromFile failed: " << status << '\n';
    MSModelDestroy(&model);
    return status;
  }
  auto inputs = MSModelGetInputs(model);
  if (inputs.handle_list == nullptr || inputs.handle_num != input_paths.size()) {
    std::cerr << "model input count differs from named files\n";
    MSModelDestroy(&model);
    return 2;
  }
  for (size_t index = 0; index < inputs.handle_num; ++index) {
    auto tensor = inputs.handle_list[index];
    std::string name = MSTensorGetName(tensor);
    auto found = input_paths.find(name);
    if (found == input_paths.end()) {
      std::cerr << "missing named input: " << name << '\n';
      MSModelDestroy(&model);
      return 3;
    }
    auto data = ReadFile(found->second);
    size_t expected = MSTensorGetDataSize(tensor);
    if (data.size() != expected) {
      std::cerr << "input " << name << " has " << data.size() << " bytes; expected " << expected << '\n';
      MSModelDestroy(&model);
      return 4;
    }
    std::memcpy(MSTensorGetMutableData(tensor), data.data(), data.size());
  }

  MSTensorHandleArray outputs{};
  status = MSModelPredict(model, inputs, &outputs, nullptr, nullptr);
  if (status != kMSStatusSuccess) {
    std::cerr << "MSModelPredict failed: " << status << '\n';
    MSModelDestroy(&model);
    return status;
  }
  fs::create_directories(output_root);
  std::ostringstream report;
  report << "{\n  \"model\": \"" << model_path.string() << "\",\n  \"outputs\": [\n";
  for (size_t index = 0; index < outputs.handle_num; ++index) {
    auto tensor = outputs.handle_list[index];
    std::string name = MSTensorGetName(tensor);
    fs::path output_path = output_root / (std::to_string(index) + "_" + SafeName(name) + ".bin");
    size_t size = MSTensorGetDataSize(tensor);
    std::ofstream output(output_path, std::ios::binary);
    output.write(static_cast<const char *>(MSTensorGetData(tensor)), static_cast<std::streamsize>(size));
    if (!output) throw std::runtime_error("cannot write output: " + output_path.string());
    size_t rank = 0;
    const int64_t *shape = MSTensorGetShape(tensor, &rank);
    report << "    {\"name\": \"" << name << "\", \"dtype\": " << MSTensorGetDataType(tensor)
           << ", \"shape\": [";
    for (size_t dimension = 0; dimension < rank; ++dimension) {
      if (dimension) report << ", ";
      report << shape[dimension];
    }
    report << "], \"size\": " << size << ", \"path\": \"" << output_path.string() << "\"}"
           << (index + 1 == outputs.handle_num ? "\n" : ",\n");
  }
  report << "  ]\n}\n";
  std::ofstream(output_root / "outputs.json") << report.str();
  std::cout << report.str();
  MSModelDestroy(&model);
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 4) {
    std::cerr << "usage: runner MODEL OUTPUT_ROOT NAME=INPUT [NAME=INPUT ...]\n";
    return 64;
  }
  std::map<std::string, fs::path> inputs;
  for (int index = 3; index < argc; ++index) {
    std::string item = argv[index];
    auto delimiter = item.find('=');
    if (delimiter == std::string::npos) return 64;
    inputs.emplace(item.substr(0, delimiter), item.substr(delimiter + 1));
  }
  try {
    return Run(argv[1], argv[2], inputs);
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
