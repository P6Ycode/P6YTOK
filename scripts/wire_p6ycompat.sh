#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(pwd)}"
repo_root="$(cd "$repo_root" && pwd)"

makefile="$(find "$repo_root" -maxdepth 6 -name Makefile -not -path '*/.git/*' -print | while read -r candidate; do
  if grep -Eq 'TWEAK_NAME|THEOS_MAKE_PATH|theos/makefiles|\$\(THEOS\)' "$candidate"; then
    printf '%s\n' "$candidate"
    break
  fi
done)"

if [ -z "$makefile" ]; then
  echo "No Theos Makefile found under $repo_root" >&2
  exit 1
fi

project_dir="$(dirname "$makefile")"
target_name="$(awk -F'=' '/^[[:space:]]*TWEAK_NAME[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$makefile")"

if [ -z "$target_name" ]; then
  echo "Found Makefile at $makefile, but could not read TWEAK_NAME." >&2
  exit 1
fi

rel_compat_dir="$(python3 - <<PY
import os
print(os.path.relpath(os.path.join('$repo_root', 'P6YCompat'), '$project_dir'))
PY
)"

source_line="${target_name}_FILES += ${rel_compat_dir}/P6YCompatCore.m ${rel_compat_dir}/P6YDelayedInit.xm ${rel_compat_dir}/P6YDelayedGroups.xm"

if grep -q 'P6YCompat/P6YCompatCore.m\|P6YCompatCore.m' "$makefile"; then
  echo "P6YCompat already appears to be wired into $makefile"
else
  {
    printf '\n# P6Y login-safe IPA compatibility layer\n'
    printf '%s\n' "$source_line"
  } >> "$makefile"
  echo "Added P6YCompat source line to $makefile"
fi

echo "project_dir=$project_dir"
echo "makefile=$makefile"
echo "target_name=$target_name"
echo "source_line=$source_line"
