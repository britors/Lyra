#!/usr/bin/env bash
# Lyra OS — build the curated AUR packages + local Lyra packages into a single
# `lyra-local` pacman repository that mkarchiso consumes (§5/§9/§12).
#
# Builds AUR packages in a CLEAN CHROOT via makechrootpkg (devtools), which:
#   - never edits the host /etc/pacman.conf,
#   - never installs the NVIDIA 580xx driver onto your real system,
#   - resolves AUR-internal dep chains via `-I` (install an already-built dep
#     into the chroot before building the dependent — see aur/packages.list).
#
# Local Lyra packages (lyra-kernel-manager, lyra-branding) have only official
# deps and reference files from this tree, so they build on the host with
# makepkg. Everything is published into out/lyra-local/ via repo-add.
#
# Run as a NORMAL user (makepkg refuses root); sudo is used only for the chroot.
set -euo pipefail

LYRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REPO_DIR="${LYRA_ROOT}/out/lyra-local"
WORK_DIR="${LYRA_ROOT}/out/aur-build"
CHROOT="${LYRA_ROOT}/out/chroot"
PKG_LIST="${LYRA_ROOT}/aur/packages.list"
# Clean pacman.conf for the chroot: core/extra/multilib, NO lyra-local. We reuse
# the installed-system config we ship in the profile (it has multilib for lib32).
CHROOT_PACMAN_CONF="${LYRA_ROOT}/profile/airootfs/etc/pacman.conf"
DB_NAME="lyra-local"

msg()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Do not run as root — makepkg/makechrootpkg need a normal user."
command -v makepkg   >/dev/null || die "makepkg not found (install base-devel)."
command -v repo-add  >/dev/null || die "repo-add not found (install pacman)."
command -v git       >/dev/null || die "git not found."
command -v makechrootpkg >/dev/null || die "makechrootpkg not found — sudo pacman -S devtools"
command -v mkarchroot    >/dev/null || die "mkarchroot not found — sudo pacman -S devtools"

mkdir -p "${REPO_DIR}" "${WORK_DIR}" "${CHROOT}"

# --- Undo the mistake of earlier versions: a [lyra-local] file:// entry left in
# /etc/pacman.conf breaks `pacman -S`/`-Sy` when its db is absent. Remove it. ----
clean_host_pacman_conf() {
    if grep -q '^\[lyra-local\]' /etc/pacman.conf 2>/dev/null; then
        msg "Removing stale [lyra-local] block from /etc/pacman.conf (needs sudo)"
        sudo sed -i '/^\[lyra-local\]/,/^Server[[:space:]]*=[[:space:]]*file:\/\/.*lyra-local/d' \
            /etc/pacman.conf
    fi
}

# --- Create or refresh the build chroot. ---------------------------------------
ensure_chroot() {
    # Self-heal a chroot left with a corrupt makepkg.conf by the earlier -M bug
    # (a mirrorlist got written as makepkg.conf). A valid makepkg.conf has CARCH=;
    # a mirrorlist doesn't. Repair in place from the host's real makepkg.conf —
    # no need to rebuild/re-download. makechrootpkg -c re-syncs the copy from root.
    if [[ -d "${CHROOT}/root" ]] && \
       ! grep -q '^[[:space:]]*CARCH=' "${CHROOT}/root/etc/makepkg.conf" 2>/dev/null; then
        warn "Chroot makepkg.conf is corrupt (old -M bug) — repairing from /etc/makepkg.conf"
        sudo cp /etc/makepkg.conf "${CHROOT}/root/etc/makepkg.conf"
    fi

    if [[ ! -d "${CHROOT}/root" ]]; then
        msg "Creating clean build chroot (downloads base-devel; needs sudo)"
        mkdir -p "${CHROOT}"
        # -C is the pacman.conf (its Include pulls the host mirrorlist). Do NOT
        # pass -M here: -M is the makepkg.conf, and pointing it at a mirrorlist
        # corrupts the chroot's makepkg.conf ("Server: command not found").
        sudo mkarchroot -C "${CHROOT_PACMAN_CONF}" \
            "${CHROOT}/root" base-devel multilib-devel
    else
        msg "Updating build chroot"
        sudo arch-nspawn -C "${CHROOT_PACMAN_CONF}" "${CHROOT}/root" \
            pacman -Syu --noconfirm || warn "chroot update failed; continuing"
    fi
}

# Newest built artifact for a given pkgname in the local repo.
dep_pkgfile() {
    ls -1t "${REPO_DIR}/${1}"-*.pkg.tar.zst 2>/dev/null | head -1
}

# repo-add every artifact a PKGBUILD dir just produced (handles split packages).
publish() {
    local dir="$1" listed b newpkgs=()
    mapfile -t listed < <(cd "${dir}" && makepkg --packagelist 2>/dev/null)
    for b in "${listed[@]}"; do
        b="${REPO_DIR}/$(basename "${b}")"
        [[ -f "${b}" ]] && newpkgs+=("${b}")
    done
    (( ${#newpkgs[@]} )) || { warn "no artifacts published for ${dir}"; return; }
    repo-add "${REPO_DIR}/${DB_NAME}.db.tar.zst" "${newpkgs[@]}" >/dev/null
}

# Build an AUR package in the chroot, installing its already-built local deps.
build_chroot() {
    local name="$1" dir="$2"; shift 2
    # Incremental: skip if already in the local repo (set REBUILD=1 to force).
    # The existing artifact stays available for later -I deps and the final
    # repo-add pass. Delete out/lyra-local/<pkg>* or set REBUILD=1 to rebuild.
    if [[ -z "${REBUILD:-}" && -n "$(dep_pkgfile "${name}")" ]]; then
        msg "${name} already built — skipping (REBUILD=1 to force)"
        return
    fi
    local d Iargs=() f
    for d in "$@"; do
        f="$(dep_pkgfile "${d}")"
        [[ -n "${f}" ]] || die "dep '${d}' for '${name}' not built yet (check order in packages.list)"
        Iargs+=(-I "${f}")
    done
    msg "Building ${name} in chroot"
    (
        cd "${dir}"
        rm -f ./*.pkg.tar.zst
        # makechrootpkg leaves artifacts in $PWD; -c uses a fresh copy each time.
        makechrootpkg -c -r "${CHROOT}" "${Iargs[@]}"
        mv -f ./*.pkg.tar.zst "${REPO_DIR}/" 2>/dev/null || true
    )
    publish "${dir}"
}

# Build a local Lyra package on the host (only official deps; no host risk).
build_host() {
    local name="$1" dir="$2"
    if [[ -z "${REBUILD:-}" && -n "$(dep_pkgfile "${name}")" ]]; then
        msg "${name} already built — skipping (REBUILD=1 to force)"
        return
    fi
    msg "Building ${name} on host"
    ( cd "${dir}" && PKGDEST="${REPO_DIR}" makepkg --syncdeps --noconfirm --clean --force --needed )
    publish "${dir}"
}

# Retry a (network) command a few times — the AUR over TLS occasionally drops
# connections ("unexpected eof while reading"); a transient blip shouldn't kill
# a long build run.
retry() {
    local n=0 max=4
    until "$@"; do
        n=$((n + 1))
        (( n >= max )) && return 1
        warn "command failed (transient?), retry ${n}/${max} in $((n * 5))s: $*"
        sleep $((n * 5))
    done
}

# Clone (or update) an AUR package, removing a partial checkout left by a failed
# clone so the retry starts clean.
fetch_aur() {
    local url="$1" dest="$2"
    if [[ -d "${dest}/.git" ]]; then
        retry git -C "${dest}" pull --ff-only || warn "pull failed for ${dest}, using cached"
    else
        rm -rf "${dest}"
        retry git clone --depth 1 "${url}" "${dest}" \
            || die "could not clone ${url} after retries (AUR/network down?)"
    fi
}

clean_host_pacman_conf
ensure_chroot

# 1) AUR packages, in dependency order, with their local-dep columns.
if [[ -f "${PKG_LIST}" ]]; then
    while read -r name url deps; do
        [[ -z "${name}" || "${name}" == \#* ]] && continue
        local_clone="${WORK_DIR}/${name}"
        fetch_aur "${url}" "${local_clone}"
        # shellcheck disable=SC2086
        build_chroot "${name}" "${local_clone}" ${deps}
    done < "${PKG_LIST}"
fi

# 2) Local Lyra packages shipped in this repo.
for localpkg in "${LYRA_ROOT}/packages/lyra-kernel-manager" "${LYRA_ROOT}/branding"; do
    if [[ -f "${localpkg}/PKGBUILD" ]]; then
        pkgname="$(sed -n 's/^pkgname=//p' "${localpkg}/PKGBUILD" | head -1)"
        build_host "${pkgname:-$(basename "${localpkg}")}" "${localpkg}"
    fi
done

# 3) Final consistency pass on the repo database (this db is what mkarchiso reads).
msg "Finalizing ${DB_NAME} repo database"
shopt -s nullglob
pkgs=("${REPO_DIR}"/*.pkg.tar.zst)
[[ ${#pkgs[@]} -gt 0 ]] || die "No packages were built into ${REPO_DIR}."
repo-add --new --remove "${REPO_DIR}/${DB_NAME}.db.tar.zst" "${pkgs[@]}" >/dev/null

msg "Done. lyra-local repo ready at: ${REPO_DIR}"
printf '   %d package(s).\n' "${#pkgs[@]}"
