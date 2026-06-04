#!/usr/bin/env bash
# Lyra OS — sequência completa para gerar a ISO, do zero (§12).
#
#   chmod +x .create_iso.sh
#   ./.create_iso.sh
#
# Rode como USUÁRIO NORMAL (não com sudo). O script pede a senha de sudo apenas
# nas etapas que precisam de root: instalar dependências, registrar o repositório
# local em /etc/pacman.conf, e rodar o mkarchiso.
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
bold "1/5  Instalando dependências de build"
# archiso  -> mkarchiso (gera a ISO)         | base-devel -> makepkg
# git      -> clonar pacotes do AUR          | imagemagick + librsvg -> wallpapers/arte
sudo pacman -S --needed --noconfirm archiso base-devel git imagemagick librsvg

# ---------------------------------------------------------------------------
bold "2/5  Gerando arte e wallpapers (paleta safira->violeta)"
./build.sh assets

# ---------------------------------------------------------------------------
bold "3/5  Compilando pacotes AUR + locais -> repositório lyra-local"
# Constrói na ordem de dependência (libpamac-aur antes de pamac-aur, etc.),
# registra [lyra-local] em /etc/pacman.conf e dá pacman -Sy entre as builds.
# Pede senha de sudo para instalar dependências de compilação.
./build.sh aur

# ---------------------------------------------------------------------------
bold "4/5  Montando o perfil archiso (injeta lyra-local, Calamares, boot art)"
./build.sh assemble

# ---------------------------------------------------------------------------
bold "5/5  Gerando a ISO com mkarchiso (root; baixa vários GB)"
sudo ./build.sh iso

bold "Concluído"
echo "ISO em: $(pwd)/out/iso/"
ls -lh out/iso/*.iso 2>/dev/null || echo "(verifique a saída do mkarchiso acima)"
