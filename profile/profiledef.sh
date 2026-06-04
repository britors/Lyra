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
# GRUB for both UEFI and BIOS, plus syslinux as BIOS fallback. GRUB on the installed
# system is required for grub-btrfs snapshot boot entries (see spec §4/§11).
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-ia32.grub.esp'
  'uefi-x64.grub.esp'
  'uefi-ia32.grub.eltorito'
  'uefi-x64.grub.eltorito'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/lyra-live-setup"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
