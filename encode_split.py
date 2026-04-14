#!/usr/bin/env python3
"""Script 1: Base64-encode a file and split it into ≤1024 KB .txt chunk files."""

import argparse
import base64
import math
import sys
from pathlib import Path

# Maximum bytes per output chunk file (1024 KiB = 1 MiB)
CHUNK_SIZE = 1024 * 1024


def encode_and_split(input_path: Path, output_dir: Path) -> list[Path]:
    """Base64-encode *input_path* and write chunks to *output_dir*.

    Returns the list of chunk files created (in order).
    """
    raw = input_path.read_bytes()
    encoded = base64.b64encode(raw)

    total_chunks = math.ceil(len(encoded) / CHUNK_SIZE) or 1
    pad = len(str(total_chunks))

    output_dir.mkdir(parents=True, exist_ok=True)

    created: list[Path] = []
    for i in range(total_chunks):
        chunk = encoded[i * CHUNK_SIZE : (i + 1) * CHUNK_SIZE]
        part_name = f"{input_path.name}.part{str(i + 1).zfill(pad)}.txt"
        out_file = output_dir / part_name
        out_file.write_bytes(chunk)
        created.append(out_file)
        print(f"  Written: {out_file}")

    return created


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Base64-encode a file and split the result into ≤1024 KB .txt files."
        )
    )
    parser.add_argument("input_file", help="Path to the file to encode and split.")
    parser.add_argument(
        "-o",
        "--output-dir",
        default=None,
        help=(
            "Directory where chunk files are written. "
            "Defaults to a sub-directory named '<input_file>.parts' "
            "next to the input file."
        ),
    )
    args = parser.parse_args()

    input_path = Path(args.input_file).resolve()
    if not input_path.is_file():
        print(f"Error: '{input_path}' is not a file.", file=sys.stderr)
        sys.exit(1)

    output_dir = (
        Path(args.output_dir).resolve()
        if args.output_dir
        else input_path.parent / f"{input_path.name}.parts"
    )

    print(f"Encoding '{input_path}' …")
    parts = encode_and_split(input_path, output_dir)
    print(f"Done. {len(parts)} chunk(s) written to '{output_dir}'.")


if __name__ == "__main__":
    main()
