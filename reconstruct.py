#!/usr/bin/env python3
"""Script 2: Reconstruct the original file from base64-encoded .txt chunk files."""

import argparse
import base64
import binascii
import re
import sys
from pathlib import Path


def reconstruct(chunks_dir: Path, output_path: Path | None) -> Path:
    """Reassemble chunk files in *chunks_dir* into the decoded original file.

    Chunk files must follow the naming pattern produced by encode_split.py:
        <original_filename>.part<NNN>.txt

    If *output_path* is None the original filename is inferred from the chunks
    and the file is written next to *chunks_dir*.

    Returns the path of the reconstructed file.
    """
    part_pattern = re.compile(r"^(.+)\.part(\d+)\.txt$")

    candidates: list[tuple[str, int, Path]] = []
    for f in chunks_dir.iterdir():
        m = part_pattern.match(f.name)
        if m:
            candidates.append((m.group(1), int(m.group(2)), f))

    if not candidates:
        print(
            f"Error: no chunk files (*.part<N>.txt) found in '{chunks_dir}'.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Group by original filename in case multiple sets of chunks coexist.
    groups: dict[str, list[tuple[int, Path]]] = {}
    for orig_name, part_num, path in candidates:
        groups.setdefault(orig_name, []).append((part_num, path))

    if len(groups) > 1:
        names = ", ".join(sorted(groups))
        print(
            f"Error: multiple chunk sets found ({names}). "
            "Place only one set of chunks in the directory.",
            file=sys.stderr,
        )
        sys.exit(1)

    orig_name, parts = next(iter(groups.items()))
    parts.sort(key=lambda t: t[0])

    print(f"Reassembling '{orig_name}' from {len(parts)} chunk(s) …")

    encoded_chunks: list[bytes] = []
    for _, chunk_path in parts:
        encoded_chunks.append(chunk_path.read_bytes())
        print(f"  Read: {chunk_path}")

    try:
        decoded = base64.b64decode(b"".join(encoded_chunks))
    except binascii.Error as exc:
        print(
            f"Error: base64 decoding failed — the chunk files may be corrupted or "
            f"incomplete.\nDetails: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)
    if output_path is None:
        output_path = chunks_dir.parent / orig_name

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(decoded)
    print(f"Done. Reconstructed file written to '{output_path}'.")
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Reconstruct the original file from base64-encoded .txt chunk files "
            "produced by encode_split.py."
        )
    )
    parser.add_argument(
        "chunks_dir",
        help="Path to the folder containing the chunk .txt files.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help=(
            "Path for the reconstructed output file. "
            "Defaults to '<original_filename>' placed next to the chunks directory."
        ),
    )
    args = parser.parse_args()

    chunks_dir = Path(args.chunks_dir).resolve()
    if not chunks_dir.is_dir():
        print(f"Error: '{chunks_dir}' is not a directory.", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output).resolve() if args.output else None

    reconstruct(chunks_dir, output_path)


if __name__ == "__main__":
    main()
