#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <mindspore-lite-2.6.0-linux-x64.tar.gz> <project-root>" >&2
  exit 2
fi

archive=$(readlink -f "$1")
project_root=$(readlink -f "$2")
expected_archive_sha=DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E
actual_archive_sha=$(sha256sum "$archive" | awk '{print toupper($1)}')
[[ "$actual_archive_sha" == "$expected_archive_sha" ]] || {
  echo "unexpected MindSpore Lite archive SHA-256: $actual_archive_sha" >&2
  exit 1
}

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
tar -xzf "$archive" -C "$stage"
tool_root="$stage/mindspore-lite-2.6.0-linux-x64/tools/converter"
converter="$tool_root/converter/converter_lite"
export LD_LIBRARY_PATH="$tool_root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

declare -A expected=(
  [custom_channel_mean]=DB1A0A273DA0658155473FB391E95D027D0D5606C72FB2FFB18BFAE0FDC85409
  [custom_channel_mean_inverted]=7EB540E46CE1437FB3004CAB1AF80BBAEBE2D83355923DA4432006482EA336D9
  [custom_channel_mean_non_finite]=C8087D8D7C94CD3BB92F872BC0665CABC0BB343A6C0D16B276FC4659C4AE0957
  [custom_text_classifier]=25E35BA4F0AC6B2B03212463AAAF7ED38D91ADC2C051C22AB996DA7E4CDC9616
)

for name in custom_channel_mean custom_channel_mean_inverted custom_channel_mean_non_finite custom_text_classifier; do
  "$converter" \
    --fmk=TFLITE \
    --modelFile="$project_root/model_sources/custom_model/$name.tflite" \
    --outputFile="$stage/$name" \
    --saveType=MINDIR_LITE \
    --optimize=general \
    --fp16=off
  actual=$(sha256sum "$stage/$name.ms" | awk '{print toupper($1)}')
  [[ "$actual" == "${expected[$name]}" ]] || {
    echo "$name.ms SHA-256 $actual does not match ${expected[$name]}" >&2
    exit 1
  }
  echo "$name.ms $actual"
done

for name in custom_channel_mean custom_channel_mean_inverted custom_channel_mean_non_finite; do
  cp "$stage/$name.ms" "$project_root/entry/src/main/resources/rawfile/model/$name.ms"
done
cp "$stage/custom_text_classifier.ms" "$project_root/model_sources/custom_model/custom_text_classifier.ms"
cp "$stage/custom_channel_mean.ms" "$project_root/model_sources/custom_model/package_image/model.ms"
cp "$stage/custom_text_classifier.ms" "$project_root/model_sources/custom_model/package_text/model.ms"

python3 "$project_root/scripts/package-custom-model-fixtures.py" --project-root "$project_root"

echo "Custom Model fixtures converted and verified with MindSpore Lite 2.6.0."
