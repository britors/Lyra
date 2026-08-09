#!/usr/bin/env bash
#
# Build the Lyra OS ISO with kiwi-ng, replace any previous test VM with a fresh
# install-target disk, and boot it in QEMU/KVM. Run this directly (not via `sudo`) --
# it escalates only the kiwi-ng build step itself, so QEMU still runs as
# your own user (needed for KVM access and the GTK display window).
#
# Usage:
#   ./build-and-run-vm.sh                 rebuild, then boot live with a fresh install disk
#   ./build-and-run-vm.sh --skip-build    boot the existing ISO with a fresh install disk
#   ./build-and-run-vm.sh --fresh-disk    accepted for compatibility; fresh is always enforced
#   ./build-and-run-vm.sh --published-installer
#                                        use the installer RPM from OBS instead of local sources
#   ./build-and-run-vm.sh --secure-boot   use OVMF with Secure Boot and Microsoft keys
#   ./build-and-run-vm.sh --help          show every option and environment override
#
# Every run rebuilds the KIWI tree from a clean slate by default. The current
# ISO is kept until the replacement is ready and then archived under
# iso/archive. Every invocation stops a previous QEMU instance started by this
# helper, if one still exists, and recreates the VM disk and OVMF state. The
# ISO is first in the boot order only once; reboot inside the same QEMU session
# after installation to validate the installed disk.
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
INSTALLER_DIR="$REPO_ROOT/installer"
CURRENT_UID="$(id -u)"
# Keep the large KIWI tree, ISO and VM disk on the persistent filesystem.
# On many systems /tmp is a small RAM-backed tmpfs and cannot hold a full
# image build plus an expanding qcow2 installation disk.
WORK_DIR="${LYRA_TEST_WORK_DIR:-$KIWI_DESC/.kiwi/test-$CURRENT_UID}"
BUILD_DIR="$WORK_DIR/build"
BUILD_DESCRIPTION_DIR="$WORK_DIR/description"
ISO_DIR="$WORK_DIR/iso"
ISO_ARCHIVE_DIR="$ISO_DIR/archive"
VM_DIR="$WORK_DIR/vm"
DISK_IMG="$VM_DIR/lyra-os-install.qcow2"
DISK_SIZE="${LYRA_VM_DISK_SIZE:-24G}"
OVMF_VARS_STANDARD="$VM_DIR/ovmf-vars.bin"
OVMF_VARS_SECURE="$VM_DIR/ovmf-secure-vars.bin"
VM_PID_FILE="$VM_DIR/qemu.pid"
LOG="$WORK_DIR/lyra-os-test.log"
# Keep enough memory for the live GNOME session and the Rust installer while
# installer regressions are being isolated.
RAM_MB="${LYRA_VM_RAM_MB:-8192}"
SMP="${LYRA_VM_CPUS:-4}"

SKIP_BUILD=0
SECURE_BOOT=0
USE_LOCAL_INSTALLER=1

usage() {
  cat <<'EOF'
Uso: ./kiwi/test/build-and-run-vm.sh [opções]

Sem opções, valida e constrói a ISO, cria uma VM descartável nova e a inicia.

Opções:
  --skip-build    reutiliza a ISO já construída
  --fresh-disk    compatibilidade; disco/NVRAM novos são sempre obrigatórios
  --published-installer
                  usa somente o RPM publicado no OBS (obrigatório para release)
  --secure-boot   usa OVMF Secure Boot com chaves Microsoft
  -h, --help      mostra esta ajuda

Recursos podem ser ajustados sem editar o script:
  LYRA_VM_DISK_SIZE=32G  tamanho do disco de instalação (padrão: 24G)
  LYRA_VM_RAM_MB=8192    memória da VM em MiB (padrão: 8192)
  LYRA_VM_CPUS=4         CPUs virtuais (padrão: 4)
  LYRA_TEST_WORK_DIR=... diretório persistente de build, ISO, VM e logs

Cada execução encerra a VM anterior e apaga seu disco e estado UEFI. Depois
da instalação, reinicie dentro da mesma janela do QEMU para testar o primeiro
boot pelo disco instalado.

Por padrão, um novo build compila e injeta os binários do instalador deste
workspace. --skip-build apenas reinicia a ISO já existente e não recompila.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --fresh-disk) : ;;
    --published-installer) USE_LOCAL_INSTALLER=0 ;;
    --secure-boot) SECURE_BOOT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

case "$RAM_MB" in
  ''|*[!0-9]*) echo "LYRA_VM_RAM_MB must be a positive integer" >&2; exit 1 ;;
esac
case "$SMP" in
  ''|*[!0-9]*) echo "LYRA_VM_CPUS must be a positive integer" >&2; exit 1 ;;
esac
if [ "$RAM_MB" -eq 0 ] || [ "$SMP" -eq 0 ]; then
  echo "LYRA_VM_RAM_MB and LYRA_VM_CPUS must be greater than zero" >&2
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

stop_previous_vm() {
  if [ ! -f "$VM_PID_FILE" ]; then
    return
  fi

  PREVIOUS_VM_PID="$(head -n 1 "$VM_PID_FILE" 2>/dev/null || true)"
  case "$PREVIOUS_VM_PID" in
    ''|*[!0-9]*) return ;;
  esac
  if ! kill -0 "$PREVIOUS_VM_PID" 2>/dev/null; then
    return
  fi

  PREVIOUS_VM_CMDLINE="$(tr '\0' '\n' < "/proc/$PREVIOUS_VM_PID/cmdline" 2>/dev/null || true)"
  if ! grep -F 'qemu-system-x86_64' <<<"$PREVIOUS_VM_CMDLINE" >/dev/null ||
     ! grep -F "$DISK_IMG" <<<"$PREVIOUS_VM_CMDLINE" >/dev/null; then
    echo "!!! refusing to stop PID $PREVIOUS_VM_PID: it is not this Lyra VM" >&2
    exit 1
  fi

  echo "--- stopping previous Lyra VM (PID $PREVIOUS_VM_PID) ---"
  kill "$PREVIOUS_VM_PID"
  for _ in {1..50}; do
    if ! kill -0 "$PREVIOUS_VM_PID" 2>/dev/null; then
      return
    fi
    sleep 0.1
  done
  echo "--- previous VM did not stop; forcing termination ---"
  kill -KILL "$PREVIOUS_VM_PID"
}

stop_previous_vm
echo "--- deleting previous VM disk and UEFI state ---"
rm -f "$DISK_IMG" "$OVMF_VARS_STANDARD" "$OVMF_VARS_SECURE" "$VM_PID_FILE"

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
  if [ "$USE_LOCAL_INSTALLER" -eq 1 ]; then
    for command in cargo install sha256sum; do
      if ! command -v "$command" >/dev/null 2>&1; then
        echo "required local-installer command not found: $command" >&2
        exit 1
      fi
    done
  fi
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

ISO_PATH=""

if [ "$SKIP_BUILD" -eq 1 ]; then
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

if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "--- wiping the previous build dir; preserving the current ISO ---"
  sudo rm -rf "$BUILD_DIR"
  ISO_PATH=""

  BUILD_DESCRIPTION="$KIWI_DESC"
  LOCAL_INSTALLER_GUI_SHA256=""
  LOCAL_INSTALLER_SERVICE_SHA256=""
  if [ "$USE_LOCAL_INSTALLER" -eq 1 ]; then
    echo "--- compiling current Lyra Installer workspace ---"
    cargo build \
      --manifest-path "$INSTALLER_DIR/Cargo.toml" \
      --workspace \
      --release \
      --locked

    echo "--- staging KIWI description with local installer binaries ---"
    rm -rf "$BUILD_DESCRIPTION_DIR"
    mkdir -p "$BUILD_DESCRIPTION_DIR"
    cp "$KIWI_DESC/config.xml" "$KIWI_DESC/config.sh" "$BUILD_DESCRIPTION_DIR/"
    cp -a "$KIWI_DESC/root" "$BUILD_DESCRIPTION_DIR/root"
    cp -a "$KIWI_DESC/keys" "$BUILD_DESCRIPTION_DIR/keys"

    install -Dm0755 "$INSTALLER_DIR/target/release/lyra-installer" \
      "$BUILD_DESCRIPTION_DIR/root/usr/bin/lyra-installer"
    install -Dm0755 "$INSTALLER_DIR/target/release/lyra-installer-service" \
      "$BUILD_DESCRIPTION_DIR/root/usr/libexec/lyra-installer-service"
    install -Dm0644 "$INSTALLER_DIR/packaging/io.lyra.Installer.policy" \
      "$BUILD_DESCRIPTION_DIR/root/usr/share/polkit-1/actions/io.lyra.Installer.policy"
    install -Dm0644 "$INSTALLER_DIR/packaging/01-lyra-installer-service.rules" \
      "$BUILD_DESCRIPTION_DIR/root/etc/polkit-1/rules.d/01-lyra-installer-service.rules"

    INSTALLER_BUILD_SOURCE="$BUILD_DESCRIPTION_DIR/root/usr/share/lyra-installer/build-source.txt"
    install -d "$(dirname "$INSTALLER_BUILD_SOURCE")"
    {
      printf 'commit=%s\n' "$BUILD_SOURCE_COMMIT"
      printf 'dirty=%s\n' "$BUILD_SOURCE_DIRTY"
      printf 'cargo_lock_sha256=%s\n' \
        "$(sha256sum "$INSTALLER_DIR/Cargo.lock" | awk '{print $1}')"
      printf 'source=local-worktree\n'
    } >"$INSTALLER_BUILD_SOURCE"
    install -Dm0644 /dev/null \
      "$BUILD_DESCRIPTION_DIR/root/usr/lib/lyra-os/local-installer-build"
    printf 'commit=%s\ndirty=%s\n' "$BUILD_SOURCE_COMMIT" "$BUILD_SOURCE_DIRTY" \
      >"$BUILD_DESCRIPTION_DIR/root/usr/lib/lyra-os/local-installer-build"

    LOCAL_INSTALLER_GUI_SHA256="$(sha256sum "$INSTALLER_DIR/target/release/lyra-installer" | awk '{print $1}')"
    LOCAL_INSTALLER_SERVICE_SHA256="$(sha256sum "$INSTALLER_DIR/target/release/lyra-installer-service" | awk '{print $1}')"
    BUILD_DESCRIPTION="$BUILD_DESCRIPTION_DIR"
    echo "--- DEVELOPMENT IMAGE: local installer override is not releasable ---"
  else
    echo "--- using published Lyra Installer RPM from OBS ---"
  fi

  echo "--- building ISO with kiwi-ng (will prompt for sudo password) ---"
  if sudo kiwi-ng \
      --setenv="LYRA_BUILD_SOURCE_COMMIT=$BUILD_SOURCE_COMMIT" \
      --setenv="LYRA_BUILD_SOURCE_DIRTY=$BUILD_SOURCE_DIRTY" \
      --setenv="LYRA_BUILD_SOURCE_EPOCH=$BUILD_SOURCE_EPOCH" \
      --setenv="LYRA_IMAGE_BUILT_AT=$IMAGE_BUILT_AT" \
      system build \
      --description "$BUILD_DESCRIPTION" \
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

  IMAGE_INSTALLER_GUI="$BUILD_DIR/build/image-root/usr/bin/lyra-installer"
  IMAGE_INSTALLER_LOCK="$BUILD_DIR/build/image-root/usr/bin/lyra-install-lock"
  IMAGE_INSTALLER_SERVICE="$BUILD_DIR/build/image-root/usr/libexec/lyra-installer-service"
  IMAGE_LIVE_SMOKE="$BUILD_DIR/build/image-root/usr/bin/lyra-live-smoke"
  IMAGE_UPDATE_SMOKE="$BUILD_DIR/build/image-root/usr/bin/lyra-update-smoke"
  IMAGE_INSTALLER_AUTOSTART="$BUILD_DIR/build/image-root/etc/xdg/autostart/lyra-installer-autostart.desktop"
  IMAGE_INSTALLER_LAUNCHER="$BUILD_DIR/build/image-root/usr/share/applications/org.lyraos.LyraInstaller.desktop"
  IMAGE_INSTALLER_ICON="$BUILD_DIR/build/image-root/usr/share/icons/hicolor/256x256/apps/org.lyraos.LyraInstaller.png"
  for INSTALLER_EXECUTABLE in \
      "$IMAGE_INSTALLER_GUI" \
      "$IMAGE_INSTALLER_LOCK" \
      "$IMAGE_INSTALLER_SERVICE" \
      "$IMAGE_LIVE_SMOKE" \
      "$IMAGE_UPDATE_SMOKE"; do
    if [ ! -x "$INSTALLER_EXECUTABLE" ]; then
      echo "!!! built image is missing an executable installer component:" >&2
      echo "  $INSTALLER_EXECUTABLE" >&2
      exit 1
    fi
  done
  if [ "$USE_LOCAL_INSTALLER" -eq 1 ]; then
    IMAGE_INSTALLER_GUI_SHA256="$(sha256sum "$IMAGE_INSTALLER_GUI" | awk '{print $1}')"
    IMAGE_INSTALLER_SERVICE_SHA256="$(sha256sum "$IMAGE_INSTALLER_SERVICE" | awk '{print $1}')"
    if [ "$IMAGE_INSTALLER_GUI_SHA256" != "$LOCAL_INSTALLER_GUI_SHA256" ] ||
       [ "$IMAGE_INSTALLER_SERVICE_SHA256" != "$LOCAL_INSTALLER_SERVICE_SHA256" ]; then
      echo "!!! built image did not preserve the current local installer binaries" >&2
      exit 1
    fi
    if [ ! -f "$BUILD_DIR/build/image-root/usr/lib/lyra-os/local-installer-build" ]; then
      echo "!!! built development image lost local installer provenance" >&2
      exit 1
    fi
  fi
  if [ ! -f "$IMAGE_INSTALLER_AUTOSTART" ] ||
     ! grep -Fx 'TryExec=/usr/bin/lyra-installer' "$IMAGE_INSTALLER_AUTOSTART" >/dev/null ||
     ! grep -Fx 'Exec=/usr/bin/lyra-install-lock /usr/bin/lyra-installer' \
        "$IMAGE_INSTALLER_AUTOSTART" >/dev/null ||
     ! grep -Fx 'StartupWMClass=lyra-installer' \
        "$IMAGE_INSTALLER_AUTOSTART" >/dev/null; then
    echo "!!! built image has no valid GNOME autostart for Lyra Installer" >&2
    exit 1
  fi
  if [ ! -f "$IMAGE_INSTALLER_LAUNCHER" ] || [ ! -s "$IMAGE_INSTALLER_ICON" ]; then
    echo "!!! built image is missing the Lyra Installer launcher or icon" >&2
    exit 1
  fi
  if ! grep -Fx 'TryExec=/usr/bin/lyra-installer' "$IMAGE_INSTALLER_LAUNCHER" >/dev/null ||
     ! grep -Fx 'Exec=/usr/bin/lyra-install-lock /usr/bin/lyra-installer' \
        "$IMAGE_INSTALLER_LAUNCHER" >/dev/null ||
     ! grep -Fx 'Icon=org.lyraos.LyraInstaller' "$IMAGE_INSTALLER_LAUNCHER" >/dev/null ||
     ! grep -Fx 'StartupWMClass=lyra-installer' \
        "$IMAGE_INSTALLER_LAUNCHER" >/dev/null; then
    echo "!!! built image has an inconsistent Lyra Installer desktop identity" >&2
    exit 1
  fi
  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$IMAGE_INSTALLER_AUTOSTART" "$IMAGE_INSTALLER_LAUNCHER"
  fi
  echo "--- validated Lyra Installer executable and GNOME autostart chain ---"

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
else
  echo "--- skipping build, reusing existing ISO ---"
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
  echo "!!! no ISO available (build skipped and none found in $ISO_DIR)"
  exit 1
fi

echo "--- ISO ready: $ISO_PATH ($(du -h "$ISO_PATH" | cut -f1)) ---"

echo "--- creating install-target disk: $DISK_IMG ($DISK_SIZE) ---"
qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"

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
  -pidfile "$VM_PID_FILE"
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

echo "--- booting live ISO once; subsequent reboot uses the installed disk ---"
QEMU_ARGS+=(-cdrom "$ISO_PATH")
QEMU_ARGS+=(-boot order=c,once=d,menu=on)

echo "--- launching: qemu-system-x86_64 ${QEMU_ARGS[*]} ---"
if qemu-system-x86_64 "${QEMU_ARGS[@]}"; then
  QEMU_STATUS=0
else
  QEMU_STATUS=$?
fi
rm -f "$VM_PID_FILE"
echo "=== qemu exited with status $QEMU_STATUS ==="
exit "$QEMU_STATUS"
