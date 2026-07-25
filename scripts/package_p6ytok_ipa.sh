#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/package_p6ytok_ipa.sh --ipa TikTok.decrypted.ipa --dylib P6YTOK.dylib --output P6YTOK-login-safe.ipa [--frameworks-dir Frameworks]

This helper packages a user-provided decrypted TikTok IPA with a compiled P6YTOK dylib.
It does not download, include, or distribute TikTok IPAs or signing assets.

You still need to sign the output IPA with your own signing tool/profile after packaging.
EOF
}

ipa=""
dylib=""
output=""
frameworks_dir="Frameworks"

while [ $# -gt 0 ]; do
  case "$1" in
    --ipa) ipa="${2:-}"; shift 2 ;;
    --dylib) dylib="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    --frameworks-dir) frameworks_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$ipa" ] || [ -z "$dylib" ] || [ -z "$output" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$ipa" ]; then
  echo "IPA not found: $ipa" >&2
  exit 1
fi

if [ ! -f "$dylib" ]; then
  echo "dylib not found: $dylib" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

unzip -q "$ipa" -d "$workdir/unpacked"
app_dir="$(find "$workdir/unpacked/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1)"

if [ -z "$app_dir" ]; then
  echo "No .app bundle found inside IPA Payload." >&2
  exit 1
fi

mkdir -p "$app_dir/$frameworks_dir"
cp "$dylib" "$app_dir/$frameworks_dir/$(basename "$dylib")"

cat > "$workdir/README-P6YTOK.txt" <<EOF
P6YTOK dylib copied into: Payload/$(basename "$app_dir")/$frameworks_dir/$(basename "$dylib")

Next step: inject a load command for the dylib and sign the IPA using your own local signing flow.
This helper deliberately does not spoof auth state, tokens, device identifiers, App Store receipts, or server-side integrity checks.
EOF
cp "$workdir/README-P6YTOK.txt" "$workdir/unpacked/README-P6YTOK.txt"

(
  cd "$workdir/unpacked"
  zip -qry "$output" Payload README-P6YTOK.txt
)

echo "Packaged unsigned IPA payload: $output"
echo "You still need to add the dylib load command and sign with your own signing tool."
