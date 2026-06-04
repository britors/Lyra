#!/usr/bin/env bash
# Lyra OS — build the curated AUR packages + local Lyra packages into a single
# `lyra-local` pacman repository that mkarchiso consumes (§5/§9/§12).
#
# Runs as a NORMAL user (makepkg refuses root). Output goes to:
#   <repo>/out/lyra-local/   (the *.pkg.tar.zst files + lyra-local.db)
#
# Idempotent: skips packages whose built artifact already matches the PKGBUILD
# version, so re-running only rebuilds what changed.
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

# Build one PKGBUILD dir into REPO_DIR (resolving deps from the system + repo).
build_pkgdir() {
    local name="$1" dir="$2"
    msg "Building ${name}"
    (
        cd "${dir}"
        # --syncdeps installs missing deps (will prompt for sudo password once),
        # --noconfirm keeps it non-interactive, --clean tidies afterwards.
        PKGDEST="${REPO_DIR}" makepkg --syncdeps --noconfirm --clean --force
    )
}

# 1) AUR packages from the curated list.
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
        build_pkgdir "$(basename "${localpkg}")" "${localpkg}"
    fi
done

# 3) (Re)generate the repository database.
msg "Generating ${DB_NAME} repo database"
shopt -s nullglob
pkgs=("${REPO_DIR}"/*.pkg.tar.zst)
[[ ${#pkgs[@]} -gt 0 ]] || die "No packages were built into ${REPO_DIR}."
repo-add --new --remove "${REPO_DIR}/${DB_NAME}.db.tar.zst" "${pkgs[@]}"

msg "Done. lyra-local repo ready at: ${REPO_DIR}"
printf '   %d package(s).\n' "${#pkgs[@]}"
