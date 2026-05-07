#!/usr/bin/env bash

# Strict settings
set -o errexit
set -o pipefail
set -o nounset

# On-the-fly-debugging
[[ -n "${DEBUG:-}" ]] && set -x

# "Magic" variables
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"

# Borrowed from https://paul.af/bash-script-preamble-boilerplate

# Global defaults
USE_GITIGNORE=true
CODEBASE_DIR="$PWD"
GITIGNORE_PATH=""
CHAR_LIMIT=20000
find_cmd=()
files=()
final_output=""

show_help() {
  cat << EOF
Usage: ${__base} [OPTIONS]

Options:
  -h, --help            Show this help
  -a, --all             Ignore .gitignore
  -d, --dir DIR         Directory to scan
  --gitignore PATH      Path to .gitignore
EOF
  exit 0
}

exit_error() {
  echo "${__base} (line ${BASH_LINENO[0]}): ${1:-"Unknown Error}"}" 1>&2
  exit 1
}

read_args() {
  while (( "$#" )); do
    case "$1" in
      -h|--help) show_help ;;
      --all|-a)
        USE_GITIGNORE=false
        shift
        ;;
      --directory=*|--dir=*|-d=*)
        CODEBASE_DIR="${1#*=}"
        shift
        ;;
      --directory|--dir|-d)
        CODEBASE_DIR="$2"
        shift 2
        ;;
      --limit=*|-l=*)
        CHAR_LIMIT="${1#*=}"
        shift
        ;;
      --limit|-l)
        CHAR_LIMIT="$2"
        shift 2
        ;;
      --gitignore=*)
        GITIGNORE_PATH="$1"
        shift
        ;;
      --gitignore)
        GITIGNORE_PATH="$2"
        shift 2
        ;;
      -*)
        exit_error "Unknown option $1"
        ;;
      *)
        shift
        ;;
esac
  done

  # Resolve CODEBASE_DIR to an absolute path
  CODEBASE_DIR=$(cd "$CODEBASE_DIR" && pwd)

  # Default gitignore path if not set
  [[ -z "$GITIGNORE_PATH" ]] && GITIGNORE_PATH="${CODEBASE_DIR}/.gitignore"
}

build_find_cmd() {
  find_cmd=("find" "$CODEBASE_DIR" "-path" "*/.git" "-prune" "-o" "-type" "f")

  # Standard ignores
  find_cmd+=("-not" "-name" ".gitignore" "-not" "-iname" "license*" "-not" "-name" "uv.lock")

  if [[ "$USE_GITIGNORE" = true ]] && [[ -f "$GITIGNORE_PATH" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Trim whitespace
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"

      # Ignore empty lines. comments, and negated lines
      [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^! ]] && continue

      clean_pattern="${line%/}"
      find_cmd+=("-not" "-path" "*/$clean_pattern/*" "-not" "-path" "*/$clean_pattern")
    done < "$GITIGNORE_PATH"
  fi
}

find_files() {
  # Change to target directory so git/find paths are relative
  cd "$CODEBASE_DIR" || exit_error "Could not access $CODEBASE_DIR"
  
  # Priority: Git Mode
  if [[ "$USE_GITIGNORE" = true ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "--- Git Repository Detected ---"
    echo "Using 'git ls-files' (supports negations and nested gitignores)..."

    while IFS= read -r -d '' file; do
      # Filter out hardcoded ignores that aren't usually in .gitignore
      [[ "$file" =~ (uv\.lock|LICENSE|\.gitignore)$ ]] && continue
      files+=("$CODEBASE_DIR/$file")
    done < <(git ls-files -z --cached --others --exclude-standard)

  # FALLBACK: Find mode
  else
    echo "--- Non-git Directory (or --all used) ---"
    echo "Using 'find' fallback (negations will be ignored)..."
    build_find_cmd
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <("${find_cmd[@]}" -print0)
  fi

  echo "Found ${#files[@]} files."
}

perform_copy() {
  local input_content="$1"
  local session_type="${XDG_SESSION_TYPE:-unknown}"

  # Check for WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo -n "$input_content" | clip.exe
    echo "Copied to Windows clipboard via clip.exe."
    return
  fi

  # Check for macOS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -n "$input_content" | pbcopy
    echo "Copied to macOS clipboard via pbcopy."
    return
  fi


  if [[ "$session_type" == "wayland" ]] && type wl-copy >/dev/null 2>&1; then
    echo -n "$input_content" | wl-copy
    return
  fi

  if [[ "$session_type" == "x11" ]] && type xclip >/dev/null 2>&1; then
    echo -n "$input_content" | xclip -selection -clipboard
    return
  fi

  echo "WARNING: No clipboard tool found. Printing to stdout:"
  echo "$input_content"
}

process_and_copy() {
  local current_chunk=""
  local chunk_index=1
  local total_chars=0

  for file in "${files[@]}"; do
    # Get path relative to codebase root
    rel_path="${file#$CODEBASE_DIR/}"

    if [[ -f "$file" ]] && grep -qI . "$file"; then
      content=$(cat "$file")

      # Prepare the file formatted string
      # We add a header for AI to understand context
      formatted_file=$'---\nFile: '"$rel_path"$'\n```\n'"$content"$'\n```\n\n'

      local file_len=${#formatted_file}
      local current_len=${#current_chunk}

      # Check if adding file will exceed limit
      if (( current_len + file_len > CHAR_LIMIT )) && (( current_len > 0 )); then
        perform_copy "$current_chunk"

        echo -e "\n--------------------------------------------------"
        echo -e "\033[1;32mPART $chunk_index COPIED\033[0m ($current_len characters)"
        echo -e "\tPaste this into the AI tool."
        echo -e "--------------------------------------------------"
        read -r -p "Press [Enter] to copy Part $((chunk_index + 1))... "

        current_chunk=""
        ((chunk_index++))
      fi

      current_chunk+="$formatted_file"
    fi
  done

  if [[ -n "$current_chunk" ]]; then
    perform_copy "$current_chunk"
    echo -e "\n--------------------------------------------------"
    if (( chunk_index > 1 )); then
      echo -e "\033[1;32mFINAL PART ($chunk_index) COPIED\033[0m (${#current_chunk} characters)"
    else
      echo -e "\033[1;32mALL CONTENT COPIED\033[0m (${#current_chunk} characters)"
    fi
    echo -e "--------------------------------------------------"
  fi
}


read_args "$@"
build_find_cmd
find_files
process_and_copy
