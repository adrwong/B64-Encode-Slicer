#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: reconstruct.sh <chunks_dir> [-o <output_file>]
  <chunks_dir>   Directory containing the chunk files (*.part<N>.txt)
  -o, --output   Optional path for the reconstructed file
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

output=""
chunks_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -o|--output)
      shift || { echo "Error: missing value for $1" >&2; usage; exit 1; }
      output="$1"
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

if [[ -z "$output" ]]; then
  output="$(dirname "$chunks_dir")/$base_name"
fi

mkdir -p "$(dirname "$output")"

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
} | "${decoder[@]}" > "$output" || {
  echo "Error: base64 decoding failed — the chunk files may be corrupted or incomplete." >&2
  exit 1
}

printf "Done. Reconstructed file written to '%s'.\n" "$output"
