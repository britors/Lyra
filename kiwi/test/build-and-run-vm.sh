#!/usr/bin/env bash
#
# Build the Lyra OS ISO with kiwi-ng, create a VM install-target disk if
# missing, and boot it in QEMU/KVM. Run this directly (not via `sudo`) --
# it escalates only the kiwi-ng build step itself, so QEMU still runs as
# your own user (needed for KVM access and the GTK display window).
#
# Usage:
#   ./build-and-run-vm.sh                 rebuild, then boot live with a fresh install disk
#   ./build-and-run-vm.sh --skip-build    boot the existing ISO with a fresh install disk
#   ./build-and-run-vm.sh --fresh-disk    accepted for compatibility; fresh is already the default
#   ./build-and-run-vm.sh --boot-disk     boot from the installed disk only, no ISO attached
#   ./build-and-run-vm.sh --secure-boot   use OVMF with Secure Boot and Microsoft keys
#
# Every run rebuilds the KIWI tree from a clean slate by default. The current
# ISO is kept until the replacement is ready and then archived under
# iso/archive. Every live-ISO run recreates the VM disk and OVMF state so a
# previous installation cannot silently intercept the boot. Pass --skip-build
# to re-boot the current ISO without rebuilding it; use --boot-disk only after
# completing an installation and closing the live VM.
#
# All output is logged (with timestamps) below a private per-user directory
# under kiwi/.kiwi, in addition to your terminal. Set LYRA_TEST_WORK_DIR to
# use another persistent location.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Don't run this script itself with sudo - it escalates only the" >&2
  echo "kiwi-ng build step internally. Running the whole thing as root" >&2
  echo "makes QEMU inherit root too, which usually can't open a window" >&2
  echo "on your desktop session. Run: ./$(basename "$0") [flags]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
KIWI_DESC="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$KIWI_DESC")"
RELEASE_TOOL="$REPO_ROOT/scripts/release.py"
CURRENT_UID="$(id -u)"
# Keep the large KIWI tree, ISO and VM disk on the persistent filesystem.
# On many systems /tmp is a small RAM-backed tmpfs and cannot hold a full
# image build plus an expanding qcow2 installation disk.
WORK_DIR="${LYRA_TEST_WORK_DIR:-$KIWI_DESC/.kiwi/test-$CURRENT_UID}"
BUILD_DIR="$WORK_DIR/build"
ISO_DIR="$WORK_DIR/iso"
ISO_ARCHIVE_DIR="$ISO_DIR/archive"
VM_DIR="$WORK_DIR/vm"
DISK_IMG="$VM_DIR/lyra-os-install.qcow2"
DISK_SIZE="20G"
OVMF_VARS_STANDARD="$VM_DIR/ovmf-vars.bin"
OVMF_VARS_SECURE="$VM_DIR/ovmf-secure-vars.bin"
LOG="$WORK_DIR/lyra-os-test.log"
# The last locally verified Live + Calamares run used 8 GiB. Keep the VM at
# that known-good allocation while installer regressions are being isolated.
RAM_MB=8192
SMP=4

SKIP_BUILD=0
FRESH_DISK=0
BOOT_DISK_ONLY=0
SECURE_BOOT=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --fresh-disk) FRESH_DISK=1 ;;
    --boot-disk) BOOT_DISK_ONLY=1 ;;
    --secure-boot) SECURE_BOOT=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ "$BOOT_DISK_ONLY" -eq 1 ] && [ "$FRESH_DISK" -eq 1 ]; then
  echo "--boot-disk and --fresh-disk cannot be used together" >&2
  exit 1
fi

# Booting an already-installed disk never needs to build or locate an ISO.
if [ "$BOOT_DISK_ONLY" -eq 1 ]; then
  SKIP_BUILD=1
fi

if [ "$BOOT_DISK_ONLY" -eq 0 ]; then
  if [ ! -x "$RELEASE_TOOL" ]; then
    echo "release metadata tool is missing or not executable: $RELEASE_TOOL" >&2
    exit 1
  fi
  "$RELEASE_TOOL" check
  EXPECTED_ISO_NAME="$("$RELEASE_TOOL" field iso_filename)"
  BUILD_SOURCE_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  BUILD_SOURCE_EPOCH="$(git -C "$REPO_ROOT" show -s --format=%ct "$BUILD_SOURCE_COMMIT")"
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=normal)" ]; then
    BUILD_SOURCE_DIRTY=1
  else
    BUILD_SOURCE_DIRTY=0
  fi
  IMAGE_BUILT_AT="$(date -u -d "@$BUILD_SOURCE_EPOCH" +%Y-%m-%dT%H:%M:%SZ)"
fi

if [ "$SECURE_BOOT" -eq 1 ]; then
  OVMF_CODE="/usr/share/qemu/ovmf-x86_64-smm-ms-code.bin"
  OVMF_VARS_TEMPLATE="/usr/share/qemu/ovmf-x86_64-smm-ms-vars.bin"
  OVMF_VARS="$OVMF_VARS_SECURE"
  MACHINE="q35,accel=kvm,smm=on"
else
  OVMF_CODE="/usr/share/qemu/ovmf-x86_64-4m-code.bin"
  OVMF_VARS_TEMPLATE="/usr/share/qemu/ovmf-x86_64-4m-vars.bin"
  OVMF_VARS="$OVMF_VARS_STANDARD"
  MACHINE="q35,accel=kvm"
fi

for command in qemu-img qemu-system-x86_64; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "required command not found: $command" >&2
    exit 1
  fi
done

if [ "$SKIP_BUILD" -eq 0 ]; then
  for command in kiwi-ng lsinitrd sudo xorriso; do
    if ! command -v "$command" >/dev/null 2>&1; then
      echo "required build command not found: $command" >&2
      exit 1
    fi
  done
fi

if [ ! -r "$OVMF_CODE" ] || [ ! -r "$OVMF_VARS_TEMPLATE" ]; then
  echo "OVMF firmware files not found or unreadable:" >&2
  echo "  $OVMF_CODE" >&2
  echo "  $OVMF_VARS_TEMPLATE" >&2
  exit 1
fi

if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  echo "KVM is unavailable to the current user (/dev/kvm is not readable/writable)." >&2
  echo "Check that the KVM module is loaded and log in again after joining the kvm group." >&2
  exit 1
fi

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "No graphical display found (DISPLAY and WAYLAND_DISPLAY are unset)." >&2
  exit 1
fi

# The build runs partly through sudo. Keep every root-written path below a
# directory owned by this user and inaccessible to other local users.
if [ -L "$WORK_DIR" ]; then
  echo "Refusing symbolic-link work directory: $WORK_DIR" >&2
  exit 1
fi
if [ -e "$WORK_DIR" ] && [ "$(stat -c '%u' "$WORK_DIR")" -ne "$CURRENT_UID" ]; then
  echo "Work directory is not owned by the current user: $WORK_DIR" >&2
  exit 1
fi
mkdir -p -m 0700 "$WORK_DIR"
chmod 0700 "$WORK_DIR"

# Timestamp every line, tee to log file and terminal.
exec > >(while IFS= read -r line; do printf '%s %s\n' "$(date '+%H:%M:%S')" "$line"; done | tee -a "$LOG") 2>&1

echo "=== $(date -Iseconds) run start (args: $*) ==="
echo "--- using KIWI description: $KIWI_DESC ---"

mkdir -p "$VM_DIR" "$ISO_DIR"

# Never carry a VM installation or firmware state into a live-ISO run. Do
# this before either reusing an ISO or starting a full build, so even a failed
# build cannot leave stale VM state waiting for the next test.
if [ "$BOOT_DISK_ONLY" -eq 0 ]; then
  echo "--- live ISO run: discarding the previous VM disk and UEFI NVRAM ---"
  rm -f "$DISK_IMG" "$OVMF_VARS_STANDARD" "$OVMF_VARS_SECURE"
fi

ISO_PATH=""

if [ "$BOOT_DISK_ONLY" -eq 0 ] && [ "$SKIP_BUILD" -eq 1 ]; then
  ISO_CANDIDATES=()
  mapfile -d '' -t ISO_CANDIDATES < <(
    find "$ISO_DIR" -maxdepth 1 -type f -name '*.iso' -print0 2>/dev/null
  )
  if [ "${#ISO_CANDIDATES[@]}" -gt 1 ]; then
    echo "!!! multiple ISO files found in $ISO_DIR; refusing an ambiguous boot:" >&2
    printf '  %s\n' "${ISO_CANDIDATES[@]}" >&2
    exit 1
  elif [ "${#ISO_CANDIDATES[@]}" -eq 1 ]; then
    ISO_PATH="${ISO_CANDIDATES[0]}"
    if [ "$(basename "$ISO_PATH")" != "$EXPECTED_ISO_NAME" ]; then
      echo "!!! cached ISO does not match release.toml:" >&2
      echo "  expected: $EXPECTED_ISO_NAME" >&2
      echo "  found:    $(basename "$ISO_PATH")" >&2
      exit 1
    fi
  fi
fi

if [ "$BOOT_DISK_ONLY" -eq 0 ] && [ "$SKIP_BUILD" -eq 0 ]; then
  echo "--- wiping the previous build dir; preserving the current ISO ---"
  sudo rm -rf "$BUILD_DIR"
  ISO_PATH=""

  echo "--- building ISO with kiwi-ng (will prompt for sudo password) ---"
  if sudo kiwi-ng \
      --setenv="LYRA_BUILD_SOURCE_COMMIT=$BUILD_SOURCE_COMMIT" \
      --setenv="LYRA_BUILD_SOURCE_DIRTY=$BUILD_SOURCE_DIRTY" \
      --setenv="LYRA_BUILD_SOURCE_EPOCH=$BUILD_SOURCE_EPOCH" \
      --setenv="LYRA_IMAGE_BUILT_AT=$IMAGE_BUILT_AT" \
      system build \
      --description "$KIWI_DESC" \
      --target-dir "$BUILD_DIR"; then
    BUILD_STATUS=0
  else
    BUILD_STATUS=$?
    echo "!!! kiwi-ng build failed with exit code $BUILD_STATUS, see log above"
    exit "$BUILD_STATUS"
  fi

  IMAGE_MTAB="$BUILD_DIR/build/image-root/etc/mtab"
  if [ ! -L "$IMAGE_MTAB" ] || [ "$(readlink "$IMAGE_MTAB")" != "../proc/self/mounts" ]; then
    echo "!!! built image has no valid /etc/mtab -> ../proc/self/mounts symlink" >&2
    echo "!!! Snapper cannot detect the installed root filesystem without it" >&2
    exit 1
  fi

  IMAGE_OS_RELEASE="$BUILD_DIR/build/image-root/etc/os-release"
  if ! grep -Fx "VERSION_ID=\"$("$RELEASE_TOOL" field version_id)\"" \
      "$IMAGE_OS_RELEASE" >/dev/null; then
    echo "!!! built image /etc/os-release does not match release.toml" >&2
    exit 1
  fi
  if ! grep -Fx "LYRA_SOURCE_COMMIT=\"$BUILD_SOURCE_COMMIT\"" \
      "$BUILD_DIR/build/image-root/usr/lib/lyra-os/build-info" >/dev/null; then
    echo "!!! built image does not identify source commit $BUILD_SOURCE_COMMIT" >&2
    exit 1
  fi

  BUILT_ISO="$(sudo find "$BUILD_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit)"
  if [ -z "$BUILT_ISO" ]; then
    echo "!!! kiwi-ng reported success but no .iso found under $BUILD_DIR"
    exit 1
  fi
  if [ "$(basename "$BUILT_ISO")" != "$EXPECTED_ISO_NAME" ]; then
    echo "!!! KIWI generated an unexpected ISO name:" >&2
    echo "  expected: $EXPECTED_ISO_NAME" >&2
    echo "  found:    $(basename "$BUILT_ISO")" >&2
    exit 1
  fi

  ISO_GRUB_CFG="$WORK_DIR/iso-grub.cfg"
  ISO_GRUB_THEME="$WORK_DIR/iso-grub-theme.txt"
  ISO_INITRD="$WORK_DIR/iso-initrd"
  rm -f "$ISO_GRUB_CFG" "$ISO_GRUB_THEME" "$ISO_INITRD"
  xorriso -osirrox on -indev "$BUILT_ISO" \
    -extract /boot/grub2/grub.cfg "$ISO_GRUB_CFG" >/dev/null 2>&1
  xorriso -osirrox on -indev "$BUILT_ISO" \
    -extract /boot/grub2/themes/Lyra-OS/theme.txt \
    "$ISO_GRUB_THEME" >/dev/null 2>&1
  xorriso -osirrox on -indev "$BUILT_ISO" \
    -extract /boot/x86_64/loader/initrd "$ISO_INITRD" >/dev/null 2>&1

  if ! grep -F 'set theme=($root)/boot/grub2/themes/Lyra-OS/theme.txt' \
      "$ISO_GRUB_CFG" >/dev/null; then
    echo "!!! generated GRUB config does not activate the Lyra-OS theme" >&2
    exit 1
  fi
  if ! grep -F 'desktop-image: "background.png"' "$ISO_GRUB_THEME" >/dev/null; then
    echo "!!! generated ISO contains an invalid Lyra-OS GRUB theme" >&2
    exit 1
  fi
  if grep -Eq '^[[:space:]]*linux .* (quiet|splash)( |$)' "$ISO_GRUB_CFG"; then
    echo "!!! live GRUB entry unexpectedly hides boot diagnostics with quiet/splash" >&2
    exit 1
  fi
  if lsinitrd -m "$ISO_INITRD" | grep -Fx 'plymouth' >/dev/null; then
    echo "!!! Plymouth was included in the generic live initrd" >&2
    echo "!!! this regresses boot by pulling the complete DRM/firmware set" >&2
    exit 1
  fi
  echo "--- validated live initrd without Plymouth ($(du -h "$ISO_INITRD" | cut -f1)) ---"

  ISO_NAME="$(basename "$BUILT_ISO")"
  ISO_PATH="$ISO_DIR/$ISO_NAME"
  ISO_STAGED="$ISO_DIR/.$ISO_NAME.new"
  rm -f "$ISO_STAGED"
  echo "--- staging $BUILT_ISO -> $ISO_STAGED ---"
  sudo cp "$BUILT_ISO" "$ISO_STAGED"
  sudo chown "$(id -u):$(id -g)" "$ISO_STAGED"

  EXISTING_ISOS=()
  mapfile -d '' -t EXISTING_ISOS < <(
    find "$ISO_DIR" -maxdepth 1 -type f -name '*.iso' -print0 2>/dev/null
  )
  for EXISTING_ISO in "${EXISTING_ISOS[@]}"; do
    mkdir -p "$ISO_ARCHIVE_DIR"
    ARCHIVE_STAMP="$(date '+%Y%m%d-%H%M%S')"
    EXISTING_NAME="$(basename "$EXISTING_ISO")"
    ARCHIVED_ISO="$ISO_ARCHIVE_DIR/${EXISTING_NAME%.iso}-$ARCHIVE_STAMP.iso"
    if [ -e "$ARCHIVED_ISO" ]; then
      ARCHIVED_ISO="$ISO_ARCHIVE_DIR/${EXISTING_NAME%.iso}-$ARCHIVE_STAMP-$$.iso"
    fi
    echo "--- archiving previous ISO -> $ARCHIVED_ISO ---"
    mv "$EXISTING_ISO" "$ARCHIVED_ISO"
    if [ -f "$EXISTING_ISO.manifest.json" ]; then
      mv "$EXISTING_ISO.manifest.json" "$ARCHIVED_ISO.manifest.json"
    fi
  done

  echo "--- promoting new ISO -> $ISO_PATH ---"
  mv -f "$ISO_STAGED" "$ISO_PATH"
  echo "--- writing build traceability manifest ---"
  "$RELEASE_TOOL" build-manifest --iso "$ISO_PATH"
elif [ "$BOOT_DISK_ONLY" -eq 0 ]; then
  echo "--- skipping build, reusing existing ISO ---"
fi

if [ "$BOOT_DISK_ONLY" -eq 0 ] && { [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; }; then
  echo "!!! no ISO available (build skipped and none found in $ISO_DIR)"
  exit 1
fi

if [ "$BOOT_DISK_ONLY" -eq 0 ]; then
  echo "--- ISO ready: $ISO_PATH ($(du -h "$ISO_PATH" | cut -f1)) ---"
fi

if [ "$BOOT_DISK_ONLY" -eq 1 ] && [ ! -f "$DISK_IMG" ]; then
  echo "!!! --boot-disk requested, but no installed disk exists at $DISK_IMG" >&2
  exit 1
fi

if [ ! -f "$DISK_IMG" ]; then
  echo "--- creating install-target disk: $DISK_IMG ($DISK_SIZE) ---"
  # A new disk must not inherit boot entries from a previous installation.
  rm -f "$OVMF_VARS_STANDARD" "$OVMF_VARS_SECURE"
  qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
else
  echo "--- reusing existing install-target disk: $DISK_IMG ---"
fi

if [ ! -f "$OVMF_VARS" ]; then
  echo "--- seeding OVMF UEFI vars ---"
  cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
fi

if [ "$SECURE_BOOT" -eq 1 ]; then
  echo "--- Secure Boot enabled (OVMF with Microsoft keys) ---"
else
  echo "--- Secure Boot disabled (standard OVMF UEFI) ---"
fi

QEMU_ARGS=(
  -name lyra-os-test
  -machine "$MACHINE"
  -cpu host
  -smp "$SMP"
  -m "$RAM_MB"
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
  -drive if=pflash,format=raw,file="$OVMF_VARS"
  -drive if=virtio,format=qcow2,file="$DISK_IMG"
  -device virtio-net-pci,netdev=net0
  -netdev user,id=net0
  -vga virtio
  -display gtk
)

if [ "$SECURE_BOOT" -eq 1 ]; then
  QEMU_ARGS+=(-global driver=cfi.pflash01,property=secure,value=on)
fi

if [ "$BOOT_DISK_ONLY" -eq 1 ]; then
  echo "--- booting from installed disk only (no ISO attached) ---"
  QEMU_ARGS+=(-boot order=c,menu=on)
else
  echo "--- booting live ISO (disk also attached as install target) ---"
  QEMU_ARGS+=(-cdrom "$ISO_PATH")
  QEMU_ARGS+=(-boot order=d,menu=on)
fi

echo "--- launching: qemu-system-x86_64 ${QEMU_ARGS[*]} ---"
if qemu-system-x86_64 "${QEMU_ARGS[@]}"; then
  QEMU_STATUS=0
else
  QEMU_STATUS=$?
fi
echo "=== qemu exited with status $QEMU_STATUS ==="
exit "$QEMU_STATUS"
