#!/usr/bin/env bash
# Build the reproducible Source0 archive and commit evidence for OBS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALLER_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$INSTALLER_DIR")"
OUTPUT_DIR="${1:-$SCRIPT_DIR/output}"

for command in git tar zstd sha256sum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "required command not found: $command" >&2
    exit 1
  fi
done

if [ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=normal)" ]; then
  echo "source archive requires a clean committed working tree" >&2
  exit 1
fi

VERSION="$(awk -F '"' '/^version = / { print $2; exit }' "$INSTALLER_DIR/Cargo.toml")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "could not read the installer semantic version" >&2
  exit 1
fi

COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
SOURCE_EPOCH="$(git -C "$REPO_ROOT" show -s --format=%ct "$COMMIT")"
PREFIX="lyra-installer-$VERSION"
TEMPORARY="$(mktemp -d /tmp/lyra-installer-source.XXXXXX)"

cleanup() {
  case "$TEMPORARY" in
    /tmp/lyra-installer-source.*) rm -rf -- "$TEMPORARY" ;;
    *) echo "refusing to remove unexpected temporary path: $TEMPORARY" >&2 ;;
  esac
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$TEMPORARY/$PREFIX"
git -C "$REPO_ROOT" archive --format=tar "$COMMIT:installer" |
  tar -xf - -C "$TEMPORARY/$PREFIX"
git -C "$REPO_ROOT" show "$COMMIT:LICENSE" >"$TEMPORARY/$PREFIX/LICENSE"

ARCHIVE="$OUTPUT_DIR/$PREFIX.tar.zst"
TEMP_ARCHIVE="$OUTPUT_DIR/.$PREFIX.tar.zst.new"
tar \
  --sort=name \
  --mtime="@$SOURCE_EPOCH" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --pax-option=delete=atime,delete=ctime \
  -C "$TEMPORARY" \
  -cf - "$PREFIX" |
  zstd --quiet --threads=1 -19 -o "$TEMP_ARCHIVE"
mv -f -- "$TEMP_ARCHIVE" "$ARCHIVE"

LOCK_SHA256="$(sha256sum "$INSTALLER_DIR/Cargo.lock" | awk '{print $1}')"
cat >"$OUTPUT_DIR/build-source.txt" <<EOF
commit=$COMMIT
source_epoch=$SOURCE_EPOCH
cargo_lock_sha256=$LOCK_SHA256
EOF

printf '%s\n' "$ARCHIVE"
printf '%s\n' "$OUTPUT_DIR/build-source.txt"
