#!/usr/bin/env bash
# Lyra OS — generate raster brand assets (§10).
# Produces placeholder logo + backgrounds in the sapphire->violet palette so the
# build is self-contained. REPLACE branding/assets/logo.svg with the real Lyra
# lyre logo and re-run to ship the final artwork (the script prefers logo.svg if
# present).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/assets"
mkdir -p "${OUT}"

command -v magick >/dev/null || { echo "imagemagick (magick) required" >&2; exit 1; }

# Sapphire->violet gradient background (reused for SDDM + boot menu).
gradient_bg() {  # <out> <w> <h>
    magick -size "${2}x${3}" \
        gradient:'#0a0a1f-#1a1140' \
        -fill '#6e6aff' -draw "circle $(( $2/2 )),$(( $3/3 )) $(( $2/2 )),$(( $3/3 - 2 ))" \
        "$1"
}

# Logo: use the real SVG if provided, else render a placeholder wordmark.
if [[ -f "${OUT}/logo.svg" ]] && command -v rsvg-convert >/dev/null; then
    rsvg-convert -w 512 -h 512 "${OUT}/logo.svg" -o "${OUT}/logo.png"
else
    magick -size 512x512 xc:none \
        -gravity center \
        -fill '#6e6aff' -pointsize 120 -annotate 0 'Lyra' \
        "${OUT}/logo.png"
fi

gradient_bg "${OUT}/background.png" 1920 1080      # SDDM
gradient_bg "${OUT}/lyra-boot-bg.png" 1920 1080    # GRUB/syslinux menu bg

echo ":: Brand assets in ${OUT} (placeholder unless logo.svg supplied)."
