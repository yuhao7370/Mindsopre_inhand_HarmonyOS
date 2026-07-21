#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <mindspore-lite-2.6.0-linux-x64.tar.gz> <project-root>" >&2
  exit 2
fi

archive=$(readlink -f "$1")
project_root=$(readlink -f "$2")
source_model="$project_root/model_sources/posenet/movenet_singlepose_lightning_float16_v4.tflite"
output_model="$project_root/entry/src/main/resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms"
expected_archive_sha=DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E
expected_source_sha=0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB
expected_model_sha=972F3BE55A484B0A86A418693CF134C5BD5BD32B3418965891E7FF1DD2874677

[[ $(sha256sum "$archive" | awk '{print toupper($1)}') == "$expected_archive_sha" ]] || {
  echo "unexpected MindSpore Lite archive SHA-256" >&2
  exit 1
}
[[ $(sha256sum "$source_model" | awk '{print toupper($1)}') == "$expected_source_sha" ]] || {
  echo "unexpected MoveNet source SHA-256" >&2
  exit 1
}

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
tar -xzf "$archive" -C "$stage"
tool_root="$stage/mindspore-lite-2.6.0-linux-x64/tools/converter"
converter="$tool_root/converter/converter_lite"
export LD_LIBRARY_PATH="$tool_root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

for run in first repeat; do
  "$converter" \
    --fmk=TFLITE \
    --modelFile="$source_model" \
    --outputFile="$stage/movenet_$run" \
    --saveType=MINDIR_LITE \
    --optimize=general \
    --fp16=off
  actual=$(sha256sum "$stage/movenet_$run.ms" | awk '{print toupper($1)}')
  [[ "$actual" == "$expected_model_sha" ]] || {
    echo "MoveNet conversion $run SHA-256 $actual does not match $expected_model_sha" >&2
    exit 1
  }
done
cmp "$stage/movenet_first.ms" "$stage/movenet_repeat.ms"
cp "$stage/movenet_first.ms" "$output_model"
echo "MoveNet FLOAT16 v4 converted twice with byte-identical MindSpore Lite 2.6.0 output."
