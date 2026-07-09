#!/usr/bin/env bash
#
# debug-mkinitcpio.sh — roda mkinitcpio dentro do chroot do airootfs já
# montado em work/, para ver o erro real quando o build.sh falha com
# "cannot stat '.../boot/initramfs-*.img'" (o pacman hook do mkinitcpio
# pode falhar silenciosamente durante o pacstrap; o build.sh só percebe
# depois, na hora de copiar o kernel pro ISO).
#
# Uso (precisa rodar depois de um build.sh que já chegou a instalar os
# pacotes, ou seja, work/x86_64/airootfs precisa existir):
#   sudo ./scripts/debug-mkinitcpio.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AIROOTFS_DIR="$ISO_DIR/work/x86_64/airootfs"

if [[ "$EUID" -ne 0 ]]; then
    echo "Precisa rodar como root (arch-chroot exige)." >&2
    exit 1
fi

[[ -d "$AIROOTFS_DIR" ]] || { echo "Não encontrei $AIROOTFS_DIR — rode build.sh primeiro (pode falhar, só precisa ter chegado a instalar pacotes)." >&2; exit 1; }

echo "==> Rodando 'mkinitcpio -P' dentro de $AIROOTFS_DIR"
arch-chroot "$AIROOTFS_DIR" mkinitcpio -P
