#!/usr/bin/env bash
#
# Executado automaticamente pelo mkarchiso dentro do chroot do airootfs,
# depois da instalação dos pacotes. Removido do ISO final pelo próprio archiso.
#
# Passos 5 e 6 de PROMPT-LYRA-OS.md §11.1.

set -e -u

echo "==> Copiando kernels instalados para /boot/vmlinuz-<pkgbase>"
# O hook do pacman que faz essa cópia automaticamente (90-mkinitcpio-install.hook)
# depende da ordem em que os pacotes aparecem na transação do pacstrap e não é
# confiável com múltiplos kernels (linux-zen + linux-lts) neste perfil — feito
# explicitamente aqui para garantir que /etc/mkinitcpio.d/<pkgbase>.preset
# sempre encontre o vmlinuz esperado.
for module_dir in /usr/lib/modules/*/; do
    pkgbase_file="${module_dir}pkgbase"
    [[ -f "$pkgbase_file" ]] || continue
    pkgbase="$(<"$pkgbase_file")"
    install -Dm644 -- "${module_dir}vmlinuz" "/boot/vmlinuz-${pkgbase}"
done

echo "==> Gerando initramfs para todos os presets (/etc/mkinitcpio.d/*.preset)"
mkinitcpio -P

echo "==> Criando usuário live 'lyra'"
useradd -m -G wheel,audio,video,storage,optical,network,power -s /bin/bash lyra
echo "lyra:lyra" | chpasswd

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
# lyraed.service fica desativado ate o pacote lyraed existir em algum
# repositorio resolvivel (ver nota sobre lyrae/lyraed em packages.x86_64)
#systemctl enable lyraed.service
