#!/usr/bin/env bash
#
# Executado automaticamente pelo mkarchiso dentro do chroot do airootfs,
# depois da instalação dos pacotes. Removido do ISO final pelo próprio archiso.
#
# Passos 5 e 6 de PROMPT-LYRA-OS.md §11.1.

set -e -u

echo "==> Atualizando cache de ícones (Lyra-Icons-v2)"
gtk-update-icon-cache -f -t /usr/share/icons/Lyra-Icons-v2/

echo "==> Atualizando cache de ícones (hicolor / lyra-logo)"
gtk-update-icon-cache -f -t /usr/share/icons/hicolor/

echo "==> Aplicando defaults do dconf"
dconf update

echo "==> Aplicando tema Plymouth padrao (lyra)"
plymouth-set-default-theme -R lyra

echo "==> Habilitando serviços systemd padrão"
systemctl enable gdm.service
systemctl enable NetworkManager.service
systemctl enable firewalld.service
systemctl enable bluetooth.service
systemctl enable cups.socket
systemctl enable lyraed.service
