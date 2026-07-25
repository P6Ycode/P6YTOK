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

The script unpacks a user-provided decrypted TikTok IPA, embeds the login-safe
bootstrap and delayed payload, adds the bootstrap LC_LOAD_DYLIB command with
LIEF, removes stale signatures, verifies the modified Mach-O, and repacks an
unsigned IPA. The output must still be signed before installation.
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

for command_name in python3 unzip zip; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 1
  fi
done

if ! python3 -c 'import lief' >/dev/null 2>&1; then
  echo "Python package 'lief' is required." >&2
  exit 1
fi

ipa="$(cd "$(dirname "$ipa")" && pwd)/$(basename "$ipa")"
bootstrap="$(cd "$(dirname "$bootstrap")" && pwd)/$(basename "$bootstrap")"
payload="$(cd "$(dirname "$payload")" && pwd)/$(basename "$payload")"
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"

if [ "$ipa" = "$output" ]; then
  echo "Output IPA must not overwrite the input IPA." >&2
  exit 1
fi

unzip -tq "$ipa" >/dev/null

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
unzip -q "$ipa" -d "$workdir/unpacked"

shopt -s nullglob
app_dirs=("$workdir"/unpacked/Payload/*.app)
if [ ${#app_dirs[@]} -ne 1 ]; then
  echo "Expected exactly one .app bundle in Payload; found ${#app_dirs[@]}." >&2
  exit 1
fi
app_dir="${app_dirs[0]}"

if [ ! -f "$app_dir/Info.plist" ]; then
  echo "App bundle is missing Info.plist: $app_dir" >&2
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

  while IFS= read -r -d '' auxiliary_dylib; do
    auxiliary_name="$(basename "$auxiliary_dylib")"
    case "$auxiliary_name" in
      P6YBootstrap.dylib|"$(basename "$payload")") continue ;;
    esac
    cp "$auxiliary_dylib" "$frameworks_dir/$auxiliary_name"
    chmod 0755 "$frameworks_dir/$auxiliary_name"
  done < <(find "$layout" -type f -name '*.dylib' -print0)
fi

# Every binary will be re-signed later. Remove stale signatures and provisioning
# data recursively so the output is unambiguously unsigned.
while IFS= read -r -d '' signature_dir; do
  rm -rf "$signature_dir"
done < <(find "$app_dir" -type d -name '_CodeSignature' -print0)
find "$app_dir" -type f \( -name 'CodeResources' -o -name 'embedded.mobileprovision' \) -delete
rm -rf "$app_dir/SC_Info"

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

config = lief.MachO.ParserConfig.deep
parsed = lief.MachO.parse(str(executable), config=config)
if parsed is None:
    raise SystemExit(f"LIEF could not parse Mach-O executable: {executable}")

binaries = list(parsed)
if not binaries:
    raise SystemExit(f"LIEF returned no Mach-O slices for: {executable}")

for binary in binaries:
    binary.remove_signature()
    if binary.find_library(load_path) is None:
        command = binary.add_library(load_path)
        if command is None:
            raise SystemExit(
                f"Could not add LC_LOAD_DYLIB to architecture {binary.header.cpu_type}"
            )

temporary = executable.with_name(executable.name + ".p6ytmp")
parsed.write(str(temporary))
os.replace(temporary, executable)
os.chmod(executable, original_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

verified = lief.MachO.parse(str(executable), config=config)
if verified is None:
    raise SystemExit("LIEF could not reparse the modified executable")
for binary in verified:
    if binary.find_library(load_path) is None:
        raise SystemExit(
            f"LC_LOAD_DYLIB verification failed for architecture {binary.header.cpu_type}"
        )

for dylib in (app / "Frameworks").glob("*.dylib"):
    os.chmod(dylib, 0o755)

print(f"Injected {load_path} into {executable_name}")
PY

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_dir/Info.plist")"
if command -v otool >/dev/null 2>&1; then
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

rm -f "$output"
(
  cd "$workdir/unpacked"
  zip -qry "$output" . -x '*.DS_Store'
)

unzip -tq "$output" >/dev/null
verify_root="$workdir/verify"
unzip -q "$output" -d "$verify_root"
verify_apps=("$verify_root"/Payload/*.app)
if [ ${#verify_apps[@]} -ne 1 ]; then
  echo "Final IPA verification found ${#verify_apps[@]} app bundles." >&2
  exit 1
fi
verify_app="${verify_apps[0]}"
test -f "$verify_app/Frameworks/P6YBootstrap.dylib"
test -f "$verify_app/Frameworks/$(basename "$payload")"

if command -v otool >/dev/null 2>&1; then
  verify_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$verify_app/Info.plist")"
  otool -L "$verify_app/$verify_executable" | grep -Fq '@executable_path/Frameworks/P6YBootstrap.dylib'
fi

echo "Built and verified unsigned injected IPA: $output"
