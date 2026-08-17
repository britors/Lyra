#!/usr/bin/env bash
# Real, destructive integration test for lyra-installer-service against a
# disposable disk image, via losetup — the "testes de integração sobre loop
# devices/imagens descartáveis" docs/installer-architecture.md already lists
# as a mandatory Beta 2 release requirement.
#
# Since service::operations::build() now covers partitioning (#40) AND
# rootfs deployment (#41), this exercises the whole thing: partition, format,
# extract the real live squashfs (needs an actual live/build session with
# /run/overlay/live populated - won't work from an arbitrary dev machine),
# create a user, chroot for dracut, and more. Meant to run inside the
# project's own live/KIWI test VM, not an arbitrary host.
#
# NOT run as part of `cargo test`: sgdisk/mkfs/mount/losetup/chroot all need
# root, which the sandbox this was written in doesn't have. Written but
# never executed in that session — run it yourself, e.g. in the project's
# own KIWI test VM (kiwi/test/build-and-run-vm.sh), and confirm end to end.
#
# Usage: sudo ./test-loop-device.sh

set -euo pipefail

# Discovery hides loop devices from the normal installer. This opt-in is
# intentionally scoped to the disposable integration-test process tree.
export LYRA_INSTALLER_ALLOW_LOOP_DEVICES=1

cd "$(dirname "$0")/.."  # installer/

if [ "$(id -u)" -ne 0 ]; then
    echo "precisa rodar como root (losetup/sgdisk/mkfs/mount exigem)" >&2
    exit 1
fi

IMAGE="$(mktemp /tmp/lyra-installer-test-XXXXXX.img)"
LOOP_DEV=""
AUDIT_MOUNT="$(mktemp -d /tmp/lyra-installer-audit-XXXXXX)"
AUDIT_MOUNTED=0

cleanup() {
    set +e
    if [ "$AUDIT_MOUNTED" -eq 1 ]; then
        umount "$AUDIT_MOUNT" 2>/dev/null
    fi
    if [ -n "$LOOP_DEV" ]; then
        umount -R /run/lyra-installer/target 2>/dev/null
        losetup -d "$LOOP_DEV" 2>/dev/null
    fi
    rm -f "$IMAGE"
    rmdir "$AUDIT_MOUNT" 2>/dev/null
}
trap cleanup EXIT

audit_fail() {
    echo "FALHA NA AUDITORIA: $*" >&2
    exit 1
}

echo "==> criando imagem descartável de 21G (sparse) em $IMAGE"
truncate -s 21G "$IMAGE"

echo "==> associando via losetup (-P para expor as partições depois do sgdisk)"
LOOP_DEV="$(losetup -f -P --show "$IMAGE")"
echo "    $LOOP_DEV"

echo "==> compilando lyra-installer-service e o exemplo sample_request"
cargo build -p lyra-installer-service
cargo build --example sample_request

echo "==> gerando e executando a requisição contra $LOOP_DEV"
REQUEST="$(./target/debug/examples/sample_request "$LOOP_DEV")"
set +e
echo "$REQUEST" | ./target/debug/lyra-installer-service
SERVICE_STATUS="${PIPESTATUS[1]}"
set -e
echo "==> saída do serviço: $SERVICE_STATUS"
if [ "$SERVICE_STATUS" -ne 0 ]; then
    echo "FALHA DO SERVIÇO: lyra-installer-service terminou com status $SERVICE_STATUS" >&2
    exit "$SERVICE_STATUS"
fi

echo "==> conferindo que nada ficou montado"
if findmnt --output TARGET --noheadings | grep -q '^/run/lyra-installer'; then
    echo "FALHA NA AUDITORIA: /run/lyra-installer ainda tem algo montado" >&2
    findmnt --output TARGET,SOURCE | grep '/run/lyra-installer'
    exit 1
fi

echo "==> tabela de partições resultante"
sgdisk -p "$LOOP_DEV"

echo "==> remontando brevemente para conferir fstab, usuário e initramfs"
mount -o subvol=/@ "${LOOP_DEV}p2" "$AUDIT_MOUNT"
AUDIT_MOUNTED=1
cat "$AUDIT_MOUNT/etc/fstab"
grep -q '^lyra:' "$AUDIT_MOUNT/etc/passwd" \
    || audit_fail "usuário lyra não encontrado"
grep -q '^%wheel' "$AUDIT_MOUNT/etc/sudoers.d/10-installer" \
    || audit_fail "sudoers não escrito"
compgen -G "$AUDIT_MOUNT/boot/initramfs-*.img" >/dev/null \
    || audit_fail "initramfs não encontrado com nome correto"
umount "$AUDIT_MOUNT"
AUDIT_MOUNTED=0

echo "==> ok: serviço e auditoria concluídos"
