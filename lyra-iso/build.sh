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
  check_lyra_repo
}

# Verifica que o repositório local [lyra] (calamares, lyra-branding,
# calamares-lyra-winmigrate, prosa, fina, lyra-tour) existe e está populado,
# ANTES de baixar o resto do sistema — sem isso, o mkarchiso só falha depois
# de baixar vários GB, com "target not found" no meio do log do pacstrap.
check_lyra_repo() {
  local pacman_conf="$SCRIPT_DIR/pacman.conf"
  local setup_hint="Rode ./scripts/setup-build-host.sh (uma vez por máquina) antes de build.sh."

  grep -q '^\[lyra\]' "$pacman_conf" || fail "Seção [lyra] não encontrada em pacman.conf. $setup_hint"

  local server_line repo_path
  server_line="$(awk '/^\[lyra\]/{f=1; next} /^\[/{f=0} f && /^Server/{print; exit}' "$pacman_conf")"
  repo_path="${server_line#*file://}"
  repo_path="${repo_path%/\$arch}"

  [[ -n "$repo_path" && -d "$repo_path" ]] || fail "Repositório local [lyra] não encontrado em '$repo_path'. $setup_hint"
  ls "$repo_path"/lyra.db.tar.gz >/dev/null 2>&1 || fail "'$repo_path/lyra.db.tar.gz' não existe. $setup_hint"

  local pkg required_packages=(calamares lyra-branding calamares-lyra-winmigrate prosa fina lyra-tour linuxtoys-bin)
  for pkg in "${required_packages[@]}"; do
    ls "$repo_path/$pkg"-*.pkg.tar.zst >/dev/null 2>&1 \
      || fail "Pacote '$pkg' ausente de '$repo_path'. $setup_hint"
  done

  check_aur_lock_versions "$repo_path"
}

# Confere que os pacotes AUR presentes no repositório local batem com a
# versão travada em packages.aur.lock (PROMPT-LYRA-OS-INTEGRACAO-TOUR-AUR.md
# §3.1) — evita gerar um ISO com uma versão de pacote diferente da esperada
# porque o cache do yay tinha uma build mais nova (ou mais antiga) parada.
check_aur_lock_versions() {
  local repo_path="$1"
  local lock_file="$SCRIPT_DIR/packages.aur.lock"

  [[ -f "$lock_file" ]] || fail "packages.aur.lock não encontrado em $SCRIPT_DIR."

  local line pkg pinned_version found_file found_version
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    pkg="${line%%=*}"
    pinned_version="${line#*=}"

    found_file="$(ls "$repo_path/$pkg"-*.pkg.tar.zst 2>/dev/null | head -1)"
    [[ -n "$found_file" ]] || continue # já validado por required_packages acima, se aplicável

    found_version="$(basename "$found_file")"
    found_version="${found_version#"$pkg"-}"
    found_version="${found_version%-x86_64.pkg.tar.zst}"
    found_version="${found_version%-any.pkg.tar.zst}"

    [[ "$found_version" == "$pinned_version" ]] \
      || fail "Pacote '$pkg' no repositório local está em '$found_version', mas packages.aur.lock trava '$pinned_version'. Atualize packages.aur.lock ou rebuilde o pacote."
  done < "$lock_file"
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
  # mkarchiso reaproveita um work/ existente e pula pacstrap+customize_airootfs.sh
  # se já parecem feitos — o que significa que uma mudança no profile (ex.: um
  # fix no customize_airootfs.sh) fica invisível para sempre num work/ velho,
  # e o build só re-tenta a última etapa que falhou contra o mesmo chroot
  # desatualizado. Já causou build quebrado silenciosamente (vmlinuz nunca
  # copiado) até alguém apagar work/ à mão. Limpar sempre custa mais tempo
  # de build, mas garante que todo build reflita o profile atual.
  if [[ -d "$WORK_DIR" ]]; then
    log "Removendo work/ existente para garantir um build limpo"
    rm -rf "$WORK_DIR"
  fi

  log "Executando mkarchiso"
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$SCRIPT_DIR"
}

checksum_iso() {
  log "Gerando checksum SHA-256 do ISO"
  ( cd "$OUT_DIR" && sha256sum ./*.iso > SHA256SUMS )
}

# Confere que o pacote lyra-tour realmente registrou seu autostart no
# airootfs montado por mkarchiso (PROMPT-LYRA-OS-INTEGRACAO-TOUR-AUR.md §3.3)
# — sem isso o Tour não abre no primeiro login e o ISO seria gerado sem
# ninguém perceber até o teste manual em VM.
check_lyra_tour_autostart() {
  local desktop_file="$WORK_DIR/x86_64/airootfs/etc/xdg/autostart/lyra-tour.desktop"
  [[ -f "$desktop_file" ]] \
    || fail "$desktop_file não encontrado após mkarchiso — o pacote lyra-tour não registrou autostart."
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
  check_lyra_tour_autostart
  checksum_iso
  log "Build concluído. ISO em $OUT_DIR/"
}

main "$@"
