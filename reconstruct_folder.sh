#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: reconstruct_folder.sh <chunks_dir> [-o <output_dir>]
  <chunks_dir>    Directory containing the chunk files (*.part<N>.txt)
  -o, --output    Output directory for the reconstructed folder
                 (default: next to chunks dir, inferred from archive name)

This reconstructs a .tar archive from the chunk files, then extracts it.
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

output_dir=""
chunks_dir=""

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
      if [[ -z "$chunks_dir" ]]; then
        chunks_dir="$1"
      else
        echo "Error: unexpected argument '$1'" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$chunks_dir" ]]; then
  usage
  exit 1
fi

if command -v realpath >/dev/null 2>&1; then
  chunks_dir=$(realpath "$chunks_dir")
fi

if [[ ! -d "$chunks_dir" ]]; then
  echo "Error: '$chunks_dir' is not a directory." >&2
  exit 1
fi

shopt -s nullglob
part_re='^(.+)\.part([0-9]+)\.txt$'
entries=()
base_name=""

for path in "$chunks_dir"/*.part*.txt; do
  file=$(basename "$path")
  if [[ $file =~ $part_re ]]; then
    name="${BASH_REMATCH[1]}"
    part="${BASH_REMATCH[2]}"
  else
    continue
  fi

  if [[ -z "$base_name" ]]; then
    base_name="$name"
  elif [[ "$name" != "$base_name" ]]; then
    echo "Error: multiple chunk sets found ('${base_name}' and '${name}'). Place only one set in the directory." >&2
    exit 1
  fi

  entries+=("${part}:${path}")
done

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "Error: no chunk files (*.part<N>.txt) found in '$chunks_dir'." >&2
  exit 1
fi

mapfile -t sorted < <(printf '%s\n' "${entries[@]}" | sort -t: -k1,1n)

folder_name="$base_name"
if [[ "$folder_name" == *.tar ]]; then
  folder_name="${folder_name%.tar}"
fi

if [[ -z "$output_dir" ]]; then
  output_dir="$(dirname "$chunks_dir")/$folder_name"
fi

if [[ -e "$output_dir" ]]; then
  echo "Error: output path '$output_dir' already exists." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

tmp_tar="$tmp_dir/$base_name"

if base64 --help 2>&1 | grep -q -- '-d'; then
  decoder=(base64 -d)
else
  decoder=(base64 -D)
fi

printf "Reassembling '%s' from %d chunk(s) …\n" "$base_name" "${#sorted[@]}"
{
  for entry in "${sorted[@]}"; do
    path="${entry#*:}"
    >&2 printf "  Read: %s\n" "$path"
    cat "$path"
  done
} | "${decoder[@]}" > "$tmp_tar" || {
  echo "Error: base64 decoding failed — the chunk files may be corrupted or incomplete." >&2
  exit 1
}

mkdir -p "$(dirname "$output_dir")"
tmp_extract="$tmp_dir/extract"
mkdir -p "$tmp_extract"
tar -xf "$tmp_tar" -C "$tmp_extract"

if [[ -d "$tmp_extract/$folder_name" ]]; then
  mv "$tmp_extract/$folder_name" "$output_dir"
else
  mapfile -t roots < <(find "$tmp_extract" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
  if [[ ${#roots[@]} -eq 1 && -d "$tmp_extract/${roots[0]}" ]]; then
    mv "$tmp_extract/${roots[0]}" "$output_dir"
  else
    echo "Error: expected a single root folder in archive; extraction produced: ${roots[*]:-(none)}" >&2
    exit 1
  fi
fi

printf "Done. Reconstructed folder written to '%s'.\n" "$output_dir"
