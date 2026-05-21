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

## Script 3 — `reconstruct.sh` (Bash)

Reconstructs the original file using only POSIX tools (no Python).

```bash
./reconstruct.sh <chunks_dir> [-o <output_file>]
```

- `chunks_dir`: Folder containing the `*.part<N>.txt` chunk files.
- `-o / --output`: Optional path for the reconstructed file. Defaults to `<original_filename>` placed next to `chunks_dir`.

---

## Script 4 — `reconstruct.ps1` (PowerShell)

Reconstructs the original file on Windows using PowerShell (no Python).

```powershell
.\reconstruct.ps1 <chunks_dir> [-o <output_file>]
```

- `chunks_dir`: Folder containing the `*.part<N>.txt` chunk files.
- `-o / --output`: Optional path for the reconstructed file. Defaults to `<original_filename>` placed next to `chunks_dir`.

---

## Script 5 — `encode_split_folder.sh` (Bash)

Archives a folder into a `.tar`, base64-encodes it, then splits it into `.txt` chunk files of at most **1024 KB** each.

```bash
./encode_split_folder.sh <input_dir> [-o <output_dir>]
```

- `input_dir`: Folder you want to encode and split.
- `-o / --output`: Optional output folder for chunk files. Defaults to `<input_dir>.parts/`.

Chunk files are named `<folder_name>.tar.part<N>.txt`.

---

## Script 6 — `reconstruct_folder.sh` (Bash)

Reconstructs the original folder from chunk files produced by `encode_split_folder.sh`.

```bash
./reconstruct_folder.sh <chunks_dir> [-o <output_dir>]
```

- `chunks_dir`: Folder containing the `*.part<N>.txt` chunk files.
- `-o / --output`: Optional output folder for the reconstructed directory.

---

## Script 7 — `encode_split_folder.ps1` (PowerShell)

Windows PowerShell equivalent of `encode_split_folder.sh`.

```powershell
.\encode_split_folder.ps1 <input_dir> [<output_dir>]
```

If `<output_dir>` is omitted, chunks are written to `<input_dir>.parts/`.

---

## Script 8 — `reconstruct_folder.ps1` (PowerShell)

Windows PowerShell equivalent of `reconstruct_folder.sh`.

```powershell
.\reconstruct_folder.ps1 <chunks_dir> [<output_dir>]
```

If `<output_dir>` is omitted, the folder is reconstructed next to `<chunks_dir>`.

---

## Running as installed commands

After `uv sync` you can also invoke the scripts through their console entry points:

```bash
uv run encode-split photo.jpg
uv run reconstruct  photo.jpg.parts/
```
