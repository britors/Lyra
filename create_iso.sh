#!/usr/bin/env bash
# Lyra OS — sequência completa para gerar a ISO, do zero (§12).
#
#   chmod +x create_iso.sh
#   ./create_iso.sh
#
# Rode como USUÁRIO NORMAL (não com sudo). O script pede a senha de sudo apenas
# nas etapas que precisam de root: instalar dependências, criar/usar o chroot de
# build e rodar o mkarchiso.
#
# É re-executável: a etapa 3 pula pacotes AUR já compilados (incremental) e a
# etapa 5 limpa a work dir do mkarchiso sozinha. Para forçar a recompilação de
# tudo no AUR: REBUILD=1 ./create_iso.sh
#
# Requisitos: host Arch Linux com internet. O mkarchiso baixa vários GB.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

bold() { printf '\n\033[1;35m========== %s ==========\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    echo "Não rode como root. Rode como usuário normal; o script usa sudo onde precisa." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
bold "0/5  Limpando entrada [lyra-local] obsoleta do /etc/pacman.conf"
# Versões antigas registravam um repo file:// sem .db, o que faz QUALQUER
# operação do pacman abortar com "não foi possível encontrar a base de dados".
# Precisa sair daqui ANTES de instalar dependências.
if grep -q '^\[lyra-local\]' /etc/pacman.conf; then
    sudo sed -i '/^\[lyra-local\]/,/^Server.*lyra-local$/d' /etc/pacman.conf
    echo "Removido. (lyra-local só é consumido pelo mkarchiso, via o pacman.conf do perfil.)"
else
    echo "Nada a remover."
fi

# ---------------------------------------------------------------------------
bold "1/5  Instalando dependências de build"
# archiso  -> mkarchiso (gera a ISO)         | base-devel -> makepkg
# devtools -> makechrootpkg (compila o AUR em chroot limpo, sem tocar no host)
# grub + mtools -> mkarchiso usa grub-install/mtools do HOST p/ o boot UEFI (uefi.grub)
# git      -> clonar pacotes do AUR          | imagemagick + librsvg -> wallpapers/arte
sudo pacman -S --needed --noconfirm archiso base-devel devtools grub mtools git imagemagick librsvg

# ---------------------------------------------------------------------------
bold "2/5  Gerando arte e wallpapers (paleta safira->violeta)"
./build.sh assets

# ---------------------------------------------------------------------------
bold "3/5  Compilando pacotes AUR + locais -> repositório lyra-local"
# Pacotes AUR são compilados num CHROOT LIMPO (makechrootpkg): não mexe no
# /etc/pacman.conf e não instala o driver NVIDIA 580xx no seu sistema real.
# A ordem/dependências internas vêm de aur/packages.list (coluna de deps).
# Inclui o calamares (saiu dos repos oficiais -> AUR). Incremental: o que já
# está em out/lyra-local é pulado. Pede senha de sudo para criar/usar o chroot.
./build.sh aur

# ---------------------------------------------------------------------------
bold "4/5  Montando o perfil archiso (injeta lyra-local, Calamares, boot art)"
./build.sh assemble

# ---------------------------------------------------------------------------
bold "5/5  Gerando a ISO com mkarchiso (root; baixa vários GB)"
# build.sh iso já limpa out/archiso-work antes de rodar (re-execução segura).
sudo ./build.sh iso

bold "Concluído"
echo "ISO em: $(pwd)/out/iso/"
ls -lh out/iso/*.iso 2>/dev/null || echo "(verifique a saída do mkarchiso acima)"
