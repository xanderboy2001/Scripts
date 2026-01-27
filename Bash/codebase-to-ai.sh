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



exit_error() {
		echo "${__base} (line ${BASH_LINENO[0]}): ${1:-"Unknown Error}"}" 1>&2
		exit 1
}

USE_GITIGNORE=true

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

CODEBASE_DIR="${__dir}"
GITIGNORE_PATH="${__dir}/.gitignore"

find_cmd=("find" "$CODEBASE_DIR" "-type" "f" "-not" "-name" ".gitignore")

if [[ "$USE_GITIGNORE" = true ]] && [[ -f "$GITIGNORE_PATH" ]]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
				# Ignore empty lines and comments in .gitignore
				[[ -z "$line" || "$line" =~ ^# ]] && continue

				# Add to the array
				find_cmd+=("-not" "-path" "*/$line*")
		done < "$GITIGNORE_PATH"
fi

files=()

while IFS= read -r -d '' file; do
		files+=("$file")
done < <("${find_cmd[@]}" -print0)

echo "Found ${#files[@]} files."

output_list=()
for file in ${files[@]}; do
		# Get path relative to codebase root for better context
		rel_path="${file#$CODEBASE_DIR/}"
		# Use 'read' to preserve formatting and append to the string
		content=$(cat "$file")

		# Building the string with explicit newlines
		final_output+=$'---\nFile: '"$rel_path"$'\n```\n'"$content"$'\n```\n\n'
done

echo "$final_output"
