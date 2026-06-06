#!/usr/bin/env bash
# Script para testar o ISO gerado no QEMU com suporte a UEFI

ISO_PATH="out/lyra-2026.06.06-x86_64.iso"

if [ ! -f "$ISO_PATH" ]; then
    echo "ISO não encontrado em $ISO_PATH. Execute o build.sh primeiro."
    exit 1
fi

qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -cdrom "$ISO_PATH" \
  -boot d
