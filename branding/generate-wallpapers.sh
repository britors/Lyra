#!/usr/bin/env bash
# Lyra OS — wallpaper pipeline (§10).
# 1. Fetch OpenBase.Wallpapers v1.0.0 (10 dark-neon SVGs).
# 2. Recolor the synthwave palette to the Lyra sapphire->violet palette
#    (aligned to the logo — §10 decision).
# 3. Rasterize each SVG to 1920x1080, 2560x1440, 3840x2160 PNG.
# 4. Repackage in KDE Plasma layout: <Name>/contents/images/<WxH>.png + metadata.
#    (The repo's install.sh is GNOME-specific and is NOT used.)
#
# Output: branding/wallpapers/generated/usr/share/wallpapers/<Name>/...
# Sources (SVGs) are kept under branding/wallpapers/src/ for reproducibility.
set -euo pipefail
shopt -s globstar nullglob
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${HERE}/wallpapers/src"
OUT_ROOT="${HERE}/wallpapers/generated/usr/share/wallpapers"
REPO_URL="https://github.com/britors/OpenBase.Wallpapers"
REPO_TAG="main"
SET_NAME="Lyra"   # §10: renamed from OpenBase

RES=("1920x1080" "2560x1440" "3840x2160")

# Synthwave -> Lyra (sapphire #6ea6ff/#3b82f6 -> violet #8b5cf6/#b44fff) (§10).
declare -A RECOLOR=(
  ["b44fff"]="8b5cf6"   # roxo  -> violet
  ["ff3fa4"]="6e6aff"   # rosa  -> sapphire-violet
  ["00d4aa"]="22b6ff"   # teal  -> sapphire cyan
  ["6ea6ff"]="3b82f6"   # azul  -> sapphire blue
)

msg() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }

# Pick a rasterizer.
if command -v rsvg-convert >/dev/null; then RASTER=rsvg
elif command -v inkscape >/dev/null;   then RASTER=inkscape
elif command -v magick >/dev/null;     then RASTER=magick
else die "Need one of: rsvg-convert (librsvg), inkscape, or imagemagick."; fi
command -v git >/dev/null || die "git required."

mkdir -p "${SRC_DIR}" "${OUT_ROOT}"
# Limpa resíduos de execuções anteriores que usavam o SRC_DIR como workspace
rm -f "${SRC_DIR}"/*.svg

# 1) Fetch SVG sources (shallow, pinned tag).
if [[ ! -d "${SRC_DIR}/.repo/.git" ]]; then
    msg "Cloning OpenBase.Wallpapers (${REPO_TAG})"
    git clone --depth 1 --branch "${REPO_TAG}" "${REPO_URL}" "${SRC_DIR}/.repo"
else
    msg "Updating OpenBase.Wallpapers to latest"
    git -C "${SRC_DIR}/.repo" fetch --depth 1 origin "${REPO_TAG}"
    git -C "${SRC_DIR}/.repo" reset --hard FETCH_HEAD
fi

svgs=("${SRC_DIR}"/.repo/**/*.svg)
[[ ${#svgs[@]} -gt 0 ]] || die "No SVGs found in the OpenBase repo checkout."

rasterize() {  # <in.svg> <out.png> <w> <h>
    local in="$1" out="$2" w="$3" h="$4"
    case "${RASTER}" in
      rsvg)     rsvg-convert -w "${w}" -h "${h}" "${in}" -o "${out}" ;;
      inkscape) inkscape "${in}" -w "${w}" -h "${h}" -o "${out}" >/dev/null 2>&1 ;;
      magick)   magick -background none -density 384 "${in}" -resize "${w}x${h}!" "${out}" ;;
    esac
}

for svg in "${svgs[@]}"; do
    base="$(basename "${svg}" .svg)"
    # Remove prefixos comuns (OpenBase ou Lyra) para normalizar o nome
    base="${base#[Oo]pen[Bb]ase-}"; base="${base#[Ll]yra-}"
    name="$(tr '[:lower:]' '[:upper:]' <<<"${base:0:1}")${base:1}"  # Capitalize

    # 2) Recolor into a temporary working copy.
    work="$(mktemp --suffix=.svg)"
    cp "${svg}" "${work}"
    for from in "${!RECOLOR[@]}"; do
        to="${RECOLOR[$from]}"
        sed -i "s/#${from}/#${to}/Ig" "${work}"
    done

    # 3+4) Rasterize into KDE layout.
    img_dir="${OUT_ROOT}/${SET_NAME}-${name}/contents/images"
    mkdir -p "${img_dir}"
    for r in "${RES[@]}"; do
        w="${r%x*}"; h="${r#*x}"
        msg "Rendering ${name} @ ${r}"
        rasterize "${work}" "${img_dir}/${r}.png" "${w}" "${h}"
    done

    cat > "${OUT_ROOT}/${SET_NAME}-${name}/metadata.json" <<EOF
{
    "KPlugin": {
        "Id": "${SET_NAME}-${name}",
        "Name": "Lyra ${name}",
        "License": "See OpenBase.Wallpapers ${REPO_TAG}",
        "Authors": [{ "Name": "britors / W3TI (Lyra recolor)" }]
    }
}
EOF
    rm -f "${work}"
done

msg "Wallpapers generated under ${OUT_ROOT}"
