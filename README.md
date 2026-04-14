# B64-Encode-Slicer

Two Python scripts for base64-encoding a file, splitting it into small chunks, and reassembling it — managed with [uv](https://github.com/astral-sh/uv).

---

## Requirements

- Python ≥ 3.12
- [uv](https://docs.astral.sh/uv/getting-started/installation/)

---

## Setup

```bash
uv sync          # create the virtual environment and install the project
```

---

## Script 1 — `encode_split.py`

Base64-encodes a file and splits the result into `.txt` chunk files of at most **1024 KB** each.

### Usage

```bash
uv run encode_split.py <input_file> [-o <output_dir>]
```

| Argument | Description |
|---|---|
| `input_file` | Path to the file you want to encode and split. |
| `-o / --output-dir` | Directory where chunk files are written. Defaults to `<input_file>.parts/` next to the input file. |

### Example

```bash
uv run encode_split.py photo.jpg
# Creates: photo.jpg.parts/photo.jpg.part1.txt, photo.jpg.parts/photo.jpg.part2.txt, …
```

Chunk files are named `<original_filename>.part<N>.txt` (zero-padded, naturally sortable).

---

## Script 2 — `reconstruct.py`

Reads all chunk files from a folder (produced by Script 1) and reconstructs the original file.

### Usage

```bash
uv run reconstruct.py <chunks_dir> [-o <output_file>]
```

| Argument | Description |
|---|---|
| `chunks_dir` | Path to the folder containing the `*.part<N>.txt` chunk files. |
| `-o / --output` | Path for the reconstructed file. Defaults to `<original_filename>` placed next to `chunks_dir`. |

### Example

```bash
uv run reconstruct.py photo.jpg.parts/
# Creates: photo.jpg  (next to the parts folder)
```

---

## Running as installed commands

After `uv sync` you can also invoke the scripts through their console entry points:

```bash
uv run encode-split photo.jpg
uv run reconstruct  photo.jpg.parts/
```
