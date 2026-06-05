#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Lyra OS — archiso profile definition
# Base: Arch Linux `releng` profile, adapted for a KDE Plasma 6 / GRUB / Btrfs live image.
#
iso_name="lyra"
iso_label="LYRA_$(date +%Y%m)"
iso_publisher="W3TI Serviços de Informática Ltda. <https://w3ti.com.br>"
iso_application="Lyra OS — Simples. Poderoso. Seu."
iso_version="$(date +%Y.%m.%d)"
install_dir="lyra"
buildmodes=('iso')
# Consolidated archiso 88 boot modes: syslinux for BIOS, GRUB for UEFI (x64).
# GRUB on the installed system is required for grub-btrfs snapshot boot (§4/§11),
# and we use GRUB on the live UEFI media too for consistency.
bootmodes=(
  'bios.syslinux'
  'uefi.grub'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')
# Only list files this profile actually ships in airootfs/ — mkarchiso aborts on
# permission targets that don't exist (unlike releng, we don't ship choose-mirror,
# livecd-sound, /root/.automated_script.sh, etc.). /etc/{shadow,gshadow} get
# correct perms from pacman.
file_permissions=(
  ["/usr/local/bin/lyra-live-setup"]="0:0:755"
  ["/usr/local/bin/lyra-flatpak-setup"]="0:0:755"
  ["/usr/local/bin/lyra-gpu-install"]="0:0:755"
  ["/usr/local/bin/lyra-live-cleanup"]="0:0:755"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/.snapshots"]="0:0:750"
  ["/etc/snapper/configs/root"]="0:0:644"
  ["/usr/bin/lyra-kernel-manager"]="0:0:755"
)
