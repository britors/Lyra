#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="lyra"
iso_label="LYRA_$(date +%Y%m)"
iso_publisher="Lyra OS <https://lyraos.org>"
iso_application="Lyra OS Live/Rescue ISO"
iso_version="$(date +%Y.%m.%d)-alpha1"
install_dir="lyra"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/sudoers.d/wheel"]="0:0:0440"
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
