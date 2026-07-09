#!/usr/bin/env bash
#
# diag-kernel.sh — descobre por que /boot/vmlinuz-<kernel> e
# /boot/initramfs-<kernel>.img nao aparecem em work/x86_64/airootfs/boot
# depois de um build.sh que falhou em "Preparing kernel and initramfs".
#
# Nao refaz o pacstrap: opera no chroot que ja esta montado em work/.
#
# Uso: sudo ./scripts/diag-kernel.sh
# Resultado impresso na tela E salvo em lyra-iso/diag-kernel.log.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AIROOTFS_DIR="$ISO_DIR/work/x86_64/airootfs"
OUT_FILE="$ISO_DIR/diag-kernel.log"

if [[ "$EUID" -ne 0 ]]; then
    echo "Precisa rodar como root (arch-chroot exige): sudo $0" >&2
    exit 1
fi

if [[ ! -d "$AIROOTFS_DIR" ]]; then
    echo "Não encontrei $AIROOTFS_DIR — rode sudo ./build.sh primeiro (pode falhar, só precisa ter chegado a instalar pacotes)." >&2
    exit 1
fi

arch-chroot "$AIROOTFS_DIR" bash -c '
echo "=== /usr/lib/modules ==="
ls -la /usr/lib/modules/ 2>&1

for module_dir in /usr/lib/modules/*/; do
    echo ""
    echo "--- $module_dir ---"
    ls -la "$module_dir" 2>&1 | grep -i vmlinuz || echo "(nenhum arquivo vmlinuz aqui)"
    pkgbase_file="${module_dir}pkgbase"
    if [[ -f "$pkgbase_file" ]]; then
        echo -n "pkgbase: "; cat "$pkgbase_file"; echo
    else
        echo "(sem arquivo pkgbase)"
    fi
done

echo ""
echo "=== /boot ANTES de tentar copiar ==="
ls -la /boot/ 2>&1

echo ""
echo "=== Reproduzindo o loop de copia do customize_airootfs.sh (idempotente) ==="
for module_dir in /usr/lib/modules/*/; do
    pkgbase_file="${module_dir}pkgbase"
    if [[ ! -f "$pkgbase_file" ]]; then
        echo "SKIP $module_dir (sem pkgbase)"
        continue
    fi
    pkgbase="$(<"$pkgbase_file")"
    echo "Tentando: install -Dm644 -- \"${module_dir}vmlinuz\" \"/boot/vmlinuz-${pkgbase}\""
    install -Dvm644 -- "${module_dir}vmlinuz" "/boot/vmlinuz-${pkgbase}" 2>&1
done

echo ""
echo "=== /boot DEPOIS de tentar copiar ==="
ls -la /boot/ 2>&1

echo ""
echo "=== mkinitcpio -P (verboso) ==="
mkinitcpio -P 2>&1

echo ""
echo "=== /boot FINAL ==="
ls -la /boot/ 2>&1
' > "$OUT_FILE" 2>&1

chmod 644 "$OUT_FILE"
echo ""
echo "==> Diagnóstico salvo em: $OUT_FILE"
echo ""
cat "$OUT_FILE"
