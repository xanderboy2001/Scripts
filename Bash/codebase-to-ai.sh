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
CODEBASE_DIR="${__dir}"
GITIGNORE_PATH="${__dir}/.gitignore"
find_cmd=()
files=()
final_output=""

exit_error() {
		echo "${__base} (line ${BASH_LINENO[0]}): ${1:-"Unknown Error}"}" 1>&2
		exit 1
}

read_args() {
		while (( "$#" )); do
				case "$1" in
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
						--gitignore=*)
								GITIGNORE_PATH="$1"
								shift 2
								;;
						--gitignore)
								GITIGNORE_PATH="$2"
								shift 1
								;;
						-*)
								exit_error "Unknown option $1"
								;;
				esac
		done
}

build_find_cmd() {
		find_cmd=("find" "$CODEBASE_DIR" "-type" "f" "-not" "-name" ".gitignore")

		if [[ "$USE_GITIGNORE" = true ]] && [[ -f "$GITIGNORE_PATH" ]]; then
				while IFS= read -r line || [[ -n "$line" ]]; do
						# Ignore empty lines and comments in .gitignore
						[[ -z "$line" || "$line" =~ ^# ]] && continue

						# Add to the array
						find_cmd+=("-not" "-path" "*/$line*")
				done < "$GITIGNORE_PATH"
		fi
}

find_files() {
		while IFS= read -r -d '' file; do
				files+=("$file")
		done < <("${find_cmd[@]}" -print0)
		echo "Found ${#files[@]} files."
}

build_output() {
		for file in ${files[@]}; do
				# Get path relative to codebase root for better context
				rel_path="${file#$CODEBASE_DIR/}"
				# Skip binary files
				if grep -qI . "$file"; then
						# Use 'read' to preserve formatting and append to the string
						content=$(cat "$file")

						# Building the string with explicit newlines
						final_output+=$'---\nFile: '"$rel_path"$'\n```\n'"$content"$'\n```\n\n'
				fi
		done
}

copy_to_clipboard() {
		copy_wayland() {
				echo -n "$final_output" | wl-copy
				echo "Copied to clipboard via wl-copy (Wayland)"
		}

		copy_x11() {
				echo -n "$final_output" | xclip -selection -clipboard
				echo "Copied to clipboard via xclip (X11)."
		}
		[[ -z "${final_output:-}" ]] && exit_error "No content found to copy."

		# Check for WSL
		if grep -qi microsoft /proc/version 2>/dev/null; then
				echo -n "$final_output" | clip.exe
				echo "Copied to Windows clipboard via clip.exe."
				return
		fi

		# Check for macOS
		if [[ "$OSTYPE" == "darwin"* ]]; then
				echo -n "$final_output" | pbcopy
				echo "Copied to macOS clipboard via pbcopy."
				return
		fi

		# Linux session detection
		local session_type="${XDG_SESSION_TYPE:-unknown}"

		if [[ "$session_type" == "wayland" ]]; then
				if type wl-copy >/dev/null 2>&1; then
						copy_wayland
						return
				else
						exit_error "Wayland session detected but 'wl-copy' is not installed."
				fi
		elif [[ "$session_type" == "x11" ]]; then
				if type xclip >/dev/null 2>&1; then
						copy_x11
				else
						exit_error "X11 session detected but 'xclip' is not installed."
				fi
		else
				# Fallback: Try to guess if session type is unknown
				if type wl-copy >/dev/null 2>&1; then
						copy_wayland
				elif type xclip >/dev/null 2>&1; then
						copy_x11
				else
						echo "$final_output"
						echo "Warning: No clipboard manager found. Output printed above."
				fi
		fi
}



read_args "$@"
build_find_cmd
find_files
build_output
copy_to_clipboard
