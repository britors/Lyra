#!/usr/bin/env bash
# Lyra OS — build the curated AUR packages + local Lyra packages into a single
# `lyra-local` pacman repository that mkarchiso consumes (§5/§9/§12).
#
# Runs as a NORMAL user (makepkg refuses root). Output goes to:
#   <repo>/out/lyra-local/   (the *.pkg.tar.zst files + lyra-local.db)
#
# Inter-package AUR deps (e.g. pamac-aur -> libpamac-aur) are handled by
# registering lyra-local in /etc/pacman.conf and `pacman -Sy`'ing after every
# build, so makepkg --syncdeps can resolve from the packages we just built.
# This is the standard "local repo" approach (à la aurutils). Build packages in
# dependency order in aur/packages.list.
set -euo pipefail

LYRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${LYRA_ROOT}/out/lyra-local"
WORK_DIR="${LYRA_ROOT}/out/aur-build"
PKG_LIST="${LYRA_ROOT}/aur/packages.list"
DB_NAME="lyra-local"

msg()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Do not run as root — makepkg must run as a normal user."
command -v makepkg >/dev/null || die "makepkg not found (install base-devel)."
command -v repo-add >/dev/null || die "repo-add not found (install pacman)."
command -v git >/dev/null || die "git not found."

mkdir -p "${REPO_DIR}" "${WORK_DIR}"

# The lyra-local DB is created by `repo-add` on the first built package (never
# hand-rolled — pacman is picky about the db archive). It is then registered in
# /etc/pacman.conf and `pacman -Sy`'d so makepkg can pull AUR-internal deps we
# build along the way. The first package in packages.list must have only
# official-repo deps (libpamac-aur does), so it builds before the repo is needed.
register_repo() {
    if ! grep -q '^\[lyra-local\]' /etc/pacman.conf 2>/dev/null; then
        msg "Registering [lyra-local] in /etc/pacman.conf (needs sudo, one time)"
        printf '\n[lyra-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n' \
            "${REPO_DIR}" | sudo tee -a /etc/pacman.conf >/dev/null
        warn "Added [lyra-local] -> file://${REPO_DIR} to /etc/pacman.conf."
        warn "Remove that block by hand if you ever relocate/delete the build tree."
    fi
}

sync_db() { sudo pacman -Sy --noconfirm >/dev/null; }

# Build one PKGBUILD dir into REPO_DIR, then publish it to the local repo.
build_pkgdir() {
    local name="$1" dir="$2"
    msg "Building ${name}"
    (
        cd "${dir}"
        PKGDEST="${REPO_DIR}" makepkg --syncdeps --noconfirm --clean --force --needed
    )
    # Ask makepkg for the exact artifact paths it produced (handles split
    # packages and pkgname != dirname). Keep only the ones that exist.
    local listed newpkgs=()
    mapfile -t listed < <(cd "${dir}" && PKGDEST="${REPO_DIR}" makepkg --packagelist 2>/dev/null)
    local p
    for p in "${listed[@]}"; do
        [[ -f "${p}" ]] && newpkgs+=("${p}")
    done
    if (( ${#newpkgs[@]} )); then
        repo-add "${REPO_DIR}/${DB_NAME}.db.tar.zst" "${newpkgs[@]}" >/dev/null
        # Register the repo (idempotent) now that a valid db exists, then refresh
        # so the freshly built package is visible to the next build.
        register_repo
        sync_db
    else
        warn "No artifact found for ${name} after build — skipping repo-add."
    fi
}

# 1) AUR packages from the curated list (already in dependency order).
if [[ -f "${PKG_LIST}" ]]; then
    while read -r name url _; do
        [[ -z "${name}" || "${name}" == \#* ]] && continue
        local_clone="${WORK_DIR}/${name}"
        if [[ -d "${local_clone}/.git" ]]; then
            git -C "${local_clone}" pull --ff-only || warn "pull failed for ${name}, using cached"
        else
            git clone "${url}" "${local_clone}"
        fi
        build_pkgdir "${name}" "${local_clone}"
    done < "${PKG_LIST}"
fi

# 2) Local Lyra packages shipped in this repo (kernel manager + branding meta).
for localpkg in "${LYRA_ROOT}/packages/lyra-kernel-manager" "${LYRA_ROOT}/branding"; do
    if [[ -f "${localpkg}/PKGBUILD" ]]; then
        pkgname="$(sed -n 's/^pkgname=//p' "${localpkg}/PKGBUILD" | head -1)"
        build_pkgdir "${pkgname:-$(basename "${localpkg}")}" "${localpkg}"
    fi
done

# 3) Final consistency pass on the repo database.
msg "Finalizing ${DB_NAME} repo database"
shopt -s nullglob
pkgs=("${REPO_DIR}"/*.pkg.tar.zst)
[[ ${#pkgs[@]} -gt 0 ]] || die "No packages were built into ${REPO_DIR}."
repo-add --new --remove "${REPO_DIR}/${DB_NAME}.db.tar.zst" "${pkgs[@]}" >/dev/null
sync_db

msg "Done. lyra-local repo ready at: ${REPO_DIR}"
printf '   %d package(s).\n' "${#pkgs[@]}"
