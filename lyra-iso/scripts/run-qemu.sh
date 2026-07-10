#!/usr/bin/env bash
#
# run-qemu.sh — sobe a ISO mais recente gerada por build.sh em uma VM QEMU,
# para testar o boot/instalador localmente sem gravar em mídia física.
#
# Uso:
#   ./scripts/run-qemu.sh [caminho/para/algum.iso]
#
# Sem argumento, usa o .iso mais recente em out/. Usa aceleração KVM
# automaticamente se /dev/kvm estiver acessível (senão cai para emulação
# por software, bem mais lenta, com um aviso).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$ISO_DIR/out"
# out/ é gerado por "sudo ./build.sh" (dono root) — um disco de teste criado
# ali por este script (rodando sem sudo, de propósito) esbarraria em
# "Permission denied" ao tentar criar o arquivo. Fica num diretório à parte,
# de propriedade do usuário normal.
QEMU_SCRATCH_DIR="$ISO_DIR/.qemu"
DISK_IMAGE="$QEMU_SCRATCH_DIR/qemu-target-disk.qcow2"
DISK_SIZE="20G"

mkdir -p "$QEMU_SCRATCH_DIR"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31m==> ERRO:\033[0m %s\n' "$1" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "qemu-system-x86_64 não encontrado. Instale o pacote 'qemu-full' ou 'qemu-desktop'."

if [[ $# -ge 1 ]]; then
    iso_path="$1"
else
    iso_path="$(find "$OUT_DIR" -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
fi

[[ -n "${iso_path:-}" && -f "$iso_path" ]] || fail "Nenhuma ISO encontrada em $OUT_DIR. Rode ./build.sh primeiro (ou passe o caminho como argumento)."

log "ISO: $iso_path"

kvm_args=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    log "Usando aceleração KVM"
    kvm_args=(-enable-kvm -cpu host)
else
    log "AVISO: /dev/kvm não acessível — rodando em emulação por software (bem mais lento)."
fi

if [[ ! -f "$DISK_IMAGE" ]]; then
    log "Criando disco alvo de teste ($DISK_SIZE) em $DISK_IMAGE"
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE" >/dev/null
fi

log "Login da sessão live: usuário 'lyra', senha 'lyra' (autologin habilitado por padrão)"
log "Iniciando QEMU..."

exec qemu-system-x86_64 \
    -name "Lyra OS (QEMU test)" \
    -m 4096 -smp 4 \
    "${kvm_args[@]}" \
    -machine q35 \
    -drive file="$iso_path",media=cdrom \
    -drive file="$DISK_IMAGE",if=virtio,format=qcow2 \
    -boot order=d \
    -vga virtio -display gtk,gl=on \
    -device virtio-net,netdev=net0 -netdev user,id=net0
