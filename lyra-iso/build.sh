#!/usr/bin/env bash
#
# build.sh — orquestra o build do ISO do Lyra OS (archiso)
#
# Passos (PROMPT-LYRA-OS.md §11.1):
#   1. Copiar assets/wallpaper/* para airootfs/usr/share/backgrounds/lyra/
#   2. Extrair assets/Lyra-Dark.tar.xz em airootfs/usr/share/themes/
#   3. Extrair assets/Lyra-Icons-v2.tar.xz em airootfs/usr/share/icons/
#   4. Gerar airootfs/usr/share/gnome-background-properties/lyra.xml
#   5. Rodar gtk-update-icon-cache (dentro do chroot, via customize_airootfs.sh)
#   6. Rodar dconf update (dentro do chroot, via customize_airootfs.sh)
#   7. Habilitar systemd units (dentro do chroot, via customize_airootfs.sh)
#   8. Executar mkarchiso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"
AIROOTFS_DIR="$SCRIPT_DIR/airootfs"
WORK_DIR="$SCRIPT_DIR/work"
OUT_DIR="$SCRIPT_DIR/out"

WALLPAPER_SRC="$ASSETS_DIR/wallpaper"
BACKGROUNDS_DST="$AIROOTFS_DIR/usr/share/backgrounds/lyra"
THEMES_DST="$AIROOTFS_DIR/usr/share/themes"
ICONS_DST="$AIROOTFS_DIR/usr/share/icons"
BG_PROPERTIES_DST="$AIROOTFS_DIR/usr/share/gnome-background-properties"

THEME_ARCHIVE="$ASSETS_DIR/Lyra-Dark.tar.xz"
ICONS_ARCHIVE="$ASSETS_DIR/Lyra-Icons-v2.tar.xz"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31m==> ERRO:\033[0m %s\n' "$1" >&2; exit 1; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    fail "este script precisa rodar como root (necessário para mkarchiso)."
  fi
}

check_prereqs() {
  command -v mkarchiso >/dev/null 2>&1 || fail "mkarchiso não encontrado. Instale o pacote 'archiso'."
  command -v gtk-update-icon-cache >/dev/null 2>&1 || fail "gtk-update-icon-cache não encontrado. Instale 'gtk-update-icon-cache' / 'hicolor-icon-theme'."
  [[ -f "$ASSETS_DIR/wallpaper/default.png" ]] || fail "assets/wallpaper/default.png não existe (§12.5 — build falha explicitamente)."
  [[ -f "$THEME_ARCHIVE" ]] || fail "assets/Lyra-Dark.tar.xz não encontrado."
  [[ -f "$ICONS_ARCHIVE" ]] || fail "assets/Lyra-Icons-v2.tar.xz não encontrado."
}

# 1. Wallpapers
install_wallpapers() {
  log "Copiando wallpapers para airootfs/usr/share/backgrounds/lyra/"
  mkdir -p "$BACKGROUNDS_DST"
  find "$BACKGROUNDS_DST" -mindepth 1 -delete
  cp "$WALLPAPER_SRC"/*.png "$BACKGROUNDS_DST/"
}

# 2. Shell theme
install_shell_theme() {
  log "Extraindo Lyra-Dark.tar.xz em airootfs/usr/share/themes/"
  mkdir -p "$THEMES_DST"
  rm -rf "$THEMES_DST/Lyra-Dark"
  tar -xJf "$THEME_ARCHIVE" -C "$THEMES_DST"
  [[ -f "$THEMES_DST/Lyra-Dark/gnome-shell/gnome-shell.css" ]] \
    || fail "extração de Lyra-Dark.tar.xz não produziu gnome-shell/gnome-shell.css"
}

# 3. Ícones
install_icon_theme() {
  log "Extraindo Lyra-Icons-v2.tar.xz em airootfs/usr/share/icons/"
  mkdir -p "$ICONS_DST"
  rm -rf "$ICONS_DST/Lyra-Icons-v2"
  tar -xJf "$ICONS_ARCHIVE" -C "$ICONS_DST"
  [[ -f "$ICONS_DST/Lyra-Icons-v2/index.theme" ]] \
    || fail "extração de Lyra-Icons-v2.tar.xz não produziu index.theme"
}

# 4. gnome-background-properties/lyra.xml
generate_wallpaper_collection() {
  log "Gerando gnome-background-properties/lyra.xml"
  mkdir -p "$BG_PROPERTIES_DST"
  local xml="$BG_PROPERTIES_DST/lyra.xml"

  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">\n'
    printf '<wallpapers>\n'
    for path in "$WALLPAPER_SRC"/*.png; do
      local file base name
      file="$(basename "$path")"
      base="${file%.png}"
      if [[ "$file" == "default.png" ]]; then
        name="Lyra Default"
      else
        # Título a partir do nome do arquivo (primeira letra maiúscula)
        name="Lyra $(tr '[:lower:]' '[:upper:]' <<<"${base:0:1}")${base:1}"
      fi
      printf '  <wallpaper deleted="false">\n'
      printf '    <name>%s</name>\n' "$name"
      printf '    <filename>/usr/share/backgrounds/lyra/%s</filename>\n' "$file"
      printf '    <options>zoom</options>\n'
      printf '    <pcolor>#1a1a2e</pcolor>\n'
      printf '    <scolor>#1a1a2e</scolor>\n'
      printf '    <shade_type>solid</shade_type>\n'
      printf '  </wallpaper>\n'
    done
    printf '</wallpapers>\n'
  } > "$xml"
}

# 8. mkarchiso
run_mkarchiso() {
  log "Executando mkarchiso"
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$SCRIPT_DIR"
}

checksum_iso() {
  log "Gerando checksum SHA-256 do ISO"
  ( cd "$OUT_DIR" && sha256sum ./*.iso > SHA256SUMS )
}

main() {
  check_prereqs
  install_wallpapers
  install_shell_theme
  install_icon_theme
  generate_wallpaper_collection

  # Passos 5, 6 e 7 (gtk-update-icon-cache, dconf update, enable de units)
  # rodam dentro do chroot via airootfs/root/customize_airootfs.sh,
  # executado automaticamente pelo mkarchiso durante _mkairootfs_pacman.

  require_root
  run_mkarchiso
  checksum_iso
  log "Build concluído. ISO em $OUT_DIR/"
}

main "$@"
