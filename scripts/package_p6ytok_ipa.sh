#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/package_p6ytok_ipa.sh \
    --ipa TikTok.decrypted.ipa \
    --bootstrap P6YBootstrap.dylib \
    --payload P6YTOK.dylib \
    --output P6YTOK-login-safe-unsigned.ipa \
    [--layout unpacked-deb-layout]

The script:
  1. Unpacks a user-provided decrypted TikTok IPA.
  2. Copies the login-safe bootstrap and delayed feature payload into Frameworks/.
  3. Copies tweak resource bundles/frameworks from an optional unpacked .deb layout.
  4. Adds an LC_LOAD_DYLIB command for P6YBootstrap.dylib using LIEF.
  5. Removes stale signatures and repacks an unsigned IPA.

The output still needs to be signed with your own signing tool/profile.
EOF
}

ipa=""
bootstrap=""
payload=""
output=""
layout=""

while [ $# -gt 0 ]; do
  case "$1" in
    --ipa) ipa="${2:-}"; shift 2 ;;
    --bootstrap) bootstrap="${2:-}"; shift 2 ;;
    --payload) payload="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    --layout) layout="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$ipa" ] || [ -z "$bootstrap" ] || [ -z "$payload" ] || [ -z "$output" ]; then
  usage >&2
  exit 1
fi

for required in "$ipa" "$bootstrap" "$payload"; do
  if [ ! -f "$required" ]; then
    echo "Required file not found: $required" >&2
    exit 1
  fi
done

if [ -n "$layout" ] && [ ! -d "$layout" ]; then
  echo "Layout directory not found: $layout" >&2
  exit 1
fi

if ! python3 -c 'import lief' >/dev/null 2>&1; then
  echo "Python package 'lief' is required. Install it with: python3 -m pip install lief" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"

unzip -q "$ipa" -d "$workdir/unpacked"
app_dir="$(find "$workdir/unpacked/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1)"

if [ -z "$app_dir" ]; then
  echo "No .app bundle found inside IPA Payload." >&2
  exit 1
fi

frameworks_dir="$app_dir/Frameworks"
mkdir -p "$frameworks_dir"
cp "$bootstrap" "$frameworks_dir/P6YBootstrap.dylib"
cp "$payload" "$frameworks_dir/$(basename "$payload")"
chmod 0755 "$frameworks_dir/P6YBootstrap.dylib" "$frameworks_dir/$(basename "$payload")"

if [ -n "$layout" ]; then
  while IFS= read -r -d '' bundle; do
    rm -rf "$app_dir/$(basename "$bundle")"
    cp -R "$bundle" "$app_dir/"
  done < <(find "$layout" -type d -name '*.bundle' -print0)

  while IFS= read -r -d '' framework; do
    rm -rf "$frameworks_dir/$(basename "$framework")"
    cp -R "$framework" "$frameworks_dir/"
  done < <(find "$layout" -type d -name '*.framework' -print0)
fi

rm -rf "$app_dir/_CodeSignature" "$app_dir/SC_Info"
rm -f "$app_dir/embedded.mobileprovision"

python3 - "$app_dir" <<'PY'
from pathlib import Path
import os
import plistlib
import stat
import sys
import lief

app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as handle:
    info = plistlib.load(handle)

executable_name = info.get("CFBundleExecutable")
if not executable_name:
    raise SystemExit("Info.plist does not contain CFBundleExecutable")

executable = app / executable_name
if not executable.is_file():
    raise SystemExit(f"Main executable not found: {executable}")

original_mode = stat.S_IMODE(executable.stat().st_mode)
load_path = "@executable_path/Frameworks/P6YBootstrap.dylib"
parsed = lief.MachO.parse(str(executable))
if parsed is None:
    raise SystemExit(f"LIEF could not parse Mach-O executable: {executable}")

binaries = list(parsed) if isinstance(parsed, lief.MachO.FatBinary) else [parsed]
for binary in binaries:
    try:
        binary.remove_signature()
    except Exception:
        # Some decrypted inputs already have no LC_CODE_SIGNATURE.
        pass

    if binary.find_library(load_path) is None:
        if binary.add_library(load_path) is None:
            raise SystemExit(f"Could not add LC_LOAD_DYLIB to architecture {binary.header.cpu_type}")

parsed.write(str(executable))
os.chmod(executable, original_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

for dylib in (app / "Frameworks").glob("*.dylib"):
    os.chmod(dylib, 0o755)

print(f"Injected {load_path} into {executable_name}")
PY

if command -v otool >/dev/null 2>&1; then
  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_dir/Info.plist")"
  if ! otool -L "$app_dir/$executable_name" | grep -Fq '@executable_path/Frameworks/P6YBootstrap.dylib'; then
    echo "Injection verification failed: LC_LOAD_DYLIB is missing." >&2
    exit 1
  fi
fi

cat > "$workdir/unpacked/README-P6YTOK.txt" <<EOF
P6YBootstrap.dylib is injected into TikTok's main executable.

The bootstrap remains in login-safe mode until normal TikTok UI appears, then loads:
  Frameworks/$(basename "$payload")

This IPA is unsigned. Sign it using your own certificate/profile or signing service before installation.
EOF

(
  cd "$workdir/unpacked"
  zip -qry "$output" Payload README-P6YTOK.txt
)

echo "Built unsigned injected IPA: $output"
