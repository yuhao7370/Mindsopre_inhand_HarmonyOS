import argparse
import zipfile
from pathlib import Path


def package(root: Path, name: str, files: list[str]) -> None:
    source = root / "model_sources" / "custom_model" / f"package_{name}"
    target = root / "entry" / "src" / "main" / "resources" / "rawfile" / "model" / f"custom_{name}_package.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file_name in files:
            info = zipfile.ZipInfo(file_name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (source / file_name).read_bytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path("."))
    root = parser.parse_args().project_root.resolve()
    package(root, "image", ["manifest.json", "model.ms", "labels.txt"])
    package(root, "text", ["manifest.json", "model.ms", "labels.txt", "tokenizer.ttok"])


if __name__ == "__main__":
    main()
