#!/usr/bin/env bash
set -euo pipefail

CHUNK_SIZE=$((1024 * 1024))

usage() {
  cat <<'EOF'
Usage: encode_split_folder.sh <input_dir> [-o <output_dir>]
  <input_dir>    Directory to archive, base64-encode, and split into chunks
  -o, --output   Output directory for chunk files (default: <input_dir>.parts)

Chunk files are written as:
  <folder_name>.tar.part<NNNNNN>.txt
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

input_dir=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -o|--output)
      shift || { echo "Error: missing value for $1" >&2; usage; exit 1; }
      output_dir="$1"
      ;;
    *)
      if [[ -z "$input_dir" ]]; then
        input_dir="$1"
      else
        echo "Error: unexpected argument '$1'" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$input_dir" ]]; then
  usage
  exit 1
fi

if command -v realpath >/dev/null 2>&1; then
  input_dir=$(realpath "$input_dir")
fi

if [[ ! -d "$input_dir" ]]; then
  echo "Error: '$input_dir' is not a directory." >&2
  exit 1
fi

leaf="$(basename "$input_dir")"
parent="$(dirname "$input_dir")"
archive_name="${leaf}.tar"

if [[ -z "$output_dir" ]]; then
  output_dir="${input_dir}.parts"
fi

mkdir -p "$output_dir"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

tmp_tar="$tmp_dir/$archive_name"
tmp_b64="$tmp_dir/${archive_name}.b64"

tar -cf "$tmp_tar" -C "$parent" "$leaf"

if base64 "$tmp_tar" >"$tmp_b64" 2>/dev/null; then
  :
else
  base64 <"$tmp_tar" >"$tmp_b64"
fi

prefix="$output_dir/${archive_name}.part"
split -b "$CHUNK_SIZE" -d -a 6 "$tmp_b64" "$prefix"

count=0
for f in "$prefix"*; do
  mv "$f" "$f.txt"
  count=$((count + 1))
  printf "  Written: %s\n" "$f.txt"
done

printf "Done. %d chunk(s) written to '%s'.\n" "$count" "$output_dir"
