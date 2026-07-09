#!/usr/bin/env bash
#
# quickstart.sh — ponto de entrada único para quem quer buildar e testar o
# Lyra OS pela primeira vez, em qualquer máquina Arch Linux.
#
# Encadeia os três passos documentados no README/CONTRIBUTING:
#   1. setup-build-host.sh — dependências de sistema + repositório local [lyra]
#   2. build.sh (sudo)     — gera o ISO via mkarchiso
#   3. run-qemu.sh         — sobe o ISO gerado numa VM QEMU para validar
#
# Uso (a partir de qualquer diretório, não precisa estar dentro de lyra-iso/):
#   ./lyra-iso/scripts/quickstart.sh              # build completo + QEMU
#   ./lyra-iso/scripts/quickstart.sh --no-qemu     # só builda o ISO
#
# Não rode como root — os passos que precisam de root chamam sudo sozinhos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "$EUID" -eq 0 ]]; then
    echo "Não execute como root. O script chama sudo internamente quando necessário." >&2
    exit 1
fi

run_qemu=1
for arg in "$@"; do
    case "$arg" in
        --no-qemu) run_qemu=0 ;;
        *)
            echo "Opção desconhecida: $arg (use --no-qemu ou nenhum argumento)" >&2
            exit 1
            ;;
    esac
done

echo "==> [1/3] Preparando o host de build (pacotes de sistema + repositório local [lyra])"
"$SCRIPT_DIR/setup-build-host.sh"

echo "==> [2/3] Gerando o ISO (mkarchiso, precisa de sudo)"
sudo "$ISO_DIR/build.sh"

if [[ "$run_qemu" -eq 1 ]]; then
    echo "==> [3/3] Subindo o ISO no QEMU para teste"
    "$SCRIPT_DIR/run-qemu.sh"
else
    echo "==> [3/3] Pulado (--no-qemu). ISO pronto em $ISO_DIR/out/"
fi
