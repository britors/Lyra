#!/usr/bin/env bash
# Lyra OS — top-level build orchestrator (§12).
#
# Pipeline:
#   1. preflight  — check tools (archiso, makepkg, magick, git)
#   2. assets     — generate brand assets + recolored/rasterized wallpapers (§10)
#   3. aur        — build curated AUR + local packages into out/lyra-local (§5/§9)
#   4. assemble   — stage a working archiso profile (inject lyra-local repo path,
#                   sync Calamares config + boot backgrounds into the profile)
#   5. iso        — run mkarchiso (REQUIRES ROOT) -> out/iso/lyra-*.iso (§11/§12)
#
# Usage:
#   ./build.sh            # full pipeline (steps 1-4 as user; step 5 needs sudo)
#   ./build.sh assets     # run a single stage
#   ./build.sh aur
#   ./build.sh assemble
#   ./build.sh iso        # must be run as root (mkarchiso requirement)
#
# mkarchiso must run as root and downloads several GB; run the whole thing on a
# build host with the `archiso` package installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${ROOT}/out"
WORK_PROFILE="${OUT}/profile-work"
LOCAL_REPO="${OUT}/lyra-local"
WORKDIR="${OUT}/archiso-work"
ISO_OUT="${OUT}/iso"

msg()  { printf '\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m==> WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

preflight() {
    msg "Preflight checks"
    local missing=()
    command -v makepkg     >/dev/null || missing+=("base-devel (makepkg)")
    command -v makechrootpkg >/dev/null || missing+=("devtools (makechrootpkg)  ->  sudo pacman -S devtools")
    command -v git         >/dev/null || missing+=("git")
    command -v magick      >/dev/null || missing+=("imagemagick (magick)")
    command -v rsvg-convert>/dev/null || warn "librsvg (rsvg-convert) absent — wallpaper SVG rasterizing will fall back to imagemagick"
    command -v mkarchiso   >/dev/null || missing+=("archiso (mkarchiso)  ->  sudo pacman -S archiso")
    command -v grub-install>/dev/null || missing+=("grub (grub-install, host-side UEFI boot)  ->  sudo pacman -S grub")
    command -v mcopy       >/dev/null || missing+=("mtools (host-side UEFI FAT image)  ->  sudo pacman -S mtools")
    if (( ${#missing[@]} )); then
        warn "Missing build dependencies:"
        printf '       - %s\n' "${missing[@]}" >&2
        [[ "${1:-}" == "soft" ]] || die "Install the above, then re-run."
    else
        msg "All build tools present."
    fi
}

stage_assets() {
    msg "Generating brand assets + wallpapers (§10)"
    "${ROOT}/branding/generate-wallpapers.sh"
    "${ROOT}/branding/generate-brand-assets.sh"
}

stage_aur() {
    msg "Building curated AUR + local packages -> ${LOCAL_REPO} (§5/§9)"
    [[ $EUID -ne 0 ]] || die "Run the 'aur' stage as a NORMAL user (makepkg refuses root)."
    "${ROOT}/aur/build-aur.sh"
}

stage_assemble() {
    msg "Assembling working archiso profile -> ${WORK_PROFILE}"
    rm -rf "${WORK_PROFILE}"
    cp -a "${ROOT}/profile" "${WORK_PROFILE}"

    # 1) Repositório local
    [[ -f "${LOCAL_REPO}/lyra-local.db" || -L "${LOCAL_REPO}/lyra-local.db" ]] \
        || warn "lyra-local repo not built yet — run './build.sh aur' first."
    sed -i "s|file:///__LYRA_LOCAL_REPO__|file://${LOCAL_REPO}|" \
        "${WORK_PROFILE}/pacman.conf"

    # 2) Calamares Config (limpa e organizada)
    install -d "${WORK_PROFILE}/airootfs/etc/calamares"
    cp -r "${ROOT}/calamares/modules" "${WORK_PROFILE}/airootfs/etc/calamares/"
    cp "${ROOT}/calamares/settings.conf" "${WORK_PROFILE}/airootfs/etc/calamares/" 2>/dev/null || true

    # 2.1) Setup Lyra branding & System Backgrounds
    local brand_dir="${WORK_PROFILE}/airootfs/etc/calamares/branding/lyra"
    mkdir -p "${brand_dir}" "${WORK_PROFILE}/airootfs/usr/share/pixmaps" "${WORK_PROFILE}/airootfs/etc/sddm.conf.d" "${WORK_PROFILE}/grub"

    # Copia o descritor de branding e o arquivo de slideshow
    cp "${ROOT}/calamares/branding/branding.desc" "${brand_dir}/"
    [[ -f "${ROOT}/calamares/branding/show.qml" ]] && cp "${ROOT}/calamares/branding/show.qml" "${brand_dir}/"

    cp "${ROOT}/branding/assets/logo.png" "${brand_dir}/logo.png"

    # Configura SDDM para usar o wallpaper da Lyra
    printf "[Theme]\nCurrent=breeze\nCursorTheme=breeze_cursors\n" > "${WORK_PROFILE}/airootfs/etc/sddm.conf.d/lyra.conf"

    # Tenta usar o Cosmos como identidade padrão. Se não existir, tenta o primeiro wallpaper gerado.
    local cosmos_wallpaper="${ROOT}/branding/wallpapers/generated/usr/share/wallpapers/Lyra-Cosmos/contents/images/1920x1080.png"
    if [[ ! -f "${cosmos_wallpaper}" ]]; then
        # Busca qualquer outro wallpaper gerado (o primeiro que aparecer)
        cosmos_wallpaper=$(find "${ROOT}/branding/wallpapers/generated" -name "1920x1080.png" | head -n 1)
    fi

    if [[ -f "${cosmos_wallpaper}" ]]; then
        cp "${cosmos_wallpaper}" "${brand_dir}/wallpaper.png"
        cp "${cosmos_wallpaper}" "${WORK_PROFILE}/airootfs/usr/share/pixmaps/lyra-background.png"
        cp "${cosmos_wallpaper}" "${WORK_PROFILE}/grub/lyra-boot-bg.png"
        # Força o Breeze a usar o wallpaper da Lyra
        mkdir -p "${WORK_PROFILE}/airootfs/usr/share/sddm/themes/breeze/"
        printf "[General]\nbackground=/usr/share/pixmaps/lyra-background.png\n" > "${WORK_PROFILE}/airootfs/usr/share/sddm/themes/breeze/theme.conf.user"
    else
        warn "Lyra-Cosmos não encontrado. Usando fallback de gradiente."
        cp "${ROOT}/branding/assets/background.png" "${brand_dir}/wallpaper.png"
        cp "${ROOT}/branding/assets/background.png" "${WORK_PROFILE}/airootfs/usr/share/pixmaps/lyra-background.png"
        cp "${ROOT}/branding/assets/lyra-boot-bg.png" "${WORK_PROFILE}/grub/lyra-boot-bg.png"
    fi

    # 3) Boot menu background for syslinux.
    local syslinux_bg_path="${ROOT}/branding/assets/lyra-boot-bg.png"
    if [[ -f "${syslinux_bg_path}" ]]; then
        cp "${syslinux_bg_path}" "${WORK_PROFILE}/syslinux/lyra-boot-bg.png"
    fi
    msg "Profile staged."
}

stage_iso() {
    command -v mkarchiso >/dev/null || die "mkarchiso not found — sudo pacman -S archiso"
    [[ $EUID -eq 0 ]] || die "The 'iso' stage must run as root: sudo ./build.sh iso"
    [[ -d "${WORK_PROFILE}" ]] || die "Run './build.sh assemble' first."
    msg "Running mkarchiso (this downloads several GB and takes a while)"
    # mkarchiso wants a clean work dir; a leftover from a previous/aborted run
    # makes it fail. Safe to wipe — it is pure build scratch space.
    rm -rf "${WORKDIR}"
    mkdir -p "${ISO_OUT}" "${WORKDIR}"
    mkarchiso -v -w "${WORKDIR}" -o "${ISO_OUT}" "${WORK_PROFILE}"
    msg "ISO(s) written to ${ISO_OUT}:"
    ls -lh "${ISO_OUT}"/*.iso 2>/dev/null || warn "No ISO produced — check mkarchiso output."
}

main() {
    local stage="${1:-all}"
    case "${stage}" in
        preflight) preflight ;;
        assets)    stage_assets ;;
        aur)       stage_aur ;;
        assemble)  stage_assemble ;;
        iso)       stage_iso ;;
        all)
            preflight
            stage_assets
            stage_aur
            stage_assemble
            msg "Stages 1-4 done. Final step needs root:"
            printf '       sudo %s iso\n' "${BASH_SOURCE[0]}"
            ;;
        *) die "Unknown stage '${stage}'. Use: preflight|assets|aur|assemble|iso|all" ;;
    esac
}

main "$@"
