#!/usr/bin/env bash
# Prepare a Lyra OS / openSUSE Leap 16 workstation for Lyra development.
#
# Supported entry point:
#   curl -fsSL \
#     https://raw.githubusercontent.com/britors/Lyra/main/scripts/bootstrap-development.sh \
#     | bash

set -Eeuo pipefail

readonly OBS_API_URL="https://api.opensuse.org"
readonly OBS_CREDENTIALS_MANAGER="osc.credentials.KeyringCredentialsManager:keyring.backends.SecretService.Keyring"

DRY_RUN=0
REFRESH_REPOSITORIES=1
INSTALL_PACKAGES=1
INSTALL_RUSTUP=1
INSTALL_CODEX=1
INSTALL_VIRTUALIZATION=1

usage() {
    cat <<'EOF'
Usage: bootstrap-development.sh [options]

Install and configure the development workstation used by Lyra OS and its
applications on Lyra OS or openSUSE Leap 16.

Options:
  --dry-run             Print commands without changing the system.
  --no-refresh          Do not refresh Zypper repositories.
  --skip-packages       Do not install RPM packages.
  --skip-rustup         Keep only the distro Rust toolchain.
  --skip-codex          Do not install the Codex CLI.
  --skip-virtualization Do not install or configure QEMU/libvirt/KIWI.
  -h, --help            Show this help.

Environment:
  OBS_USER              OBS username written to the osc config.
                        Default: rodrigosbrito
EOF
}

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

print_command() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    print_command "$@"
    if (( ! DRY_RUN )); then
        "$@"
    fi
}

run_as_root() {
    run sudo -- "$@"
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --no-refresh) REFRESH_REPOSITORIES=0 ;;
            --skip-packages) INSTALL_PACKAGES=0 ;;
            --skip-rustup) INSTALL_RUSTUP=0 ;;
            --skip-codex) INSTALL_CODEX=0 ;;
            --skip-virtualization) INSTALL_VIRTUALIZATION=0 ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "unknown option: $1"
                ;;
        esac
        shift
    done
}

check_target_system() {
    [[ ${EUID} -ne 0 ]] || die "run this script as your regular user, without sudo"
    [[ -r /etc/os-release ]] || die "/etc/os-release is missing"
    command -v sudo >/dev/null 2>&1 || die "sudo is required"
    command -v zypper >/dev/null 2>&1 || die "zypper is required"

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ ${ID:-} == "lyra-os" ]]; then
        return
    fi

    if [[ ${ID:-} == "opensuse-leap" && ${VERSION_ID:-} == "16.0" ]]; then
        return
    fi

    die "supported systems are Lyra OS and openSUSE Leap 16.0 (found: ${PRETTY_NAME:-unknown})"
}

ensure_profile_path() {
    local profile_file="${HOME}/.profile"
    # Keep these variables literal: they must expand in each future shell.
    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"'

    log "Configuring the user PATH"
    if (( DRY_RUN )); then
        printf '  + ensure %q contains %q\n' "$profile_file" "$path_line"
    else
        mkdir -p "${HOME}/.local/bin" "${HOME}/.cargo"
        touch "$profile_file"
        if ! grep -Fqx "$path_line" "$profile_file"; then
            printf '\n# Lyra development tools\n%s\n' "$path_line" >> "$profile_file"
        fi
    fi

    export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"
}

install_system_packages() {
    local -a base_packages=(
        ca-certificates curl wget jq
        git git-lfs gh openssh-clients
        gcc gcc-c++ glibc-devel make cmake ninja meson pkgconf-pkg-config
        autoconf automake libtool bison flex patch diffutils
        clang clang-tools gdb lldb valgrind strace ccache
        python3 python3-devel python313-pip python313-virtualenv
        nodejs24 npm24 go
        rpm-build rpmdevtools rpmlint spec-cleaner osc
        rust cargo cargo-packaging
        gtk4-devel libadwaita-devel vte-devel
        webkit2gtk4-devel libsoup-devel
        libopenssl-devel sqlite3-devel dbus-1-devel systemd-devel polkit-devel
        libsecret-devel librsvg-devel gettext-tools
        desktop-file-utils appstream-glib fdupes
        ImageMagick rsvg-convert sassc zstd
        checkpolicy policycoreutils
        gnome-keyring python313-keyring
        ripgrep fd fzf bat tree tmux ShellCheck
        unzip zip
        podman buildah
    )
    local -a virtualization_packages=(
        python3-kiwi
        kiwi-systemdeps-core
        kiwi-systemdeps-filesystems
        kiwi-systemdeps-bootloaders
        kiwi-systemdeps-iso-media
        kiwi-systemdeps-disk-images
        kiwi-systemdeps-image-validation
        qemu-x86 qemu-img qemu-ovmf-x86_64
        qemu-ui-gtk qemu-ui-opengl qemu-hw-display-virtio-vga
        libvirt libvirt-daemon-qemu virt-manager
    )
    local -a packages=("${base_packages[@]}")

    if (( INSTALL_VIRTUALIZATION )); then
        packages+=("${virtualization_packages[@]}")
    fi

    if (( REFRESH_REPOSITORIES )); then
        log "Refreshing repositories"
        run_as_root zypper --non-interactive --gpg-auto-import-keys refresh
    fi

    log "Installing development RPMs"
    run_as_root zypper --non-interactive install --no-recommends "${packages[@]}"
}

configure_git() {
    log "Configuring Git defaults"
    # Keep the bootstrap independent of the directory from which it is invoked.
    run git lfs install --skip-repo
    run git config --global init.defaultBranch main
    run git config --global fetch.prune true
    run git config --global pull.ff only
}

install_user_rust_toolchain() {
    local installer

    log "Installing the current stable Rust toolchain with rustup"
    if command -v rustup >/dev/null 2>&1; then
        run rustup toolchain install stable --profile default
    elif (( DRY_RUN )); then
        printf '  + download https://sh.rustup.rs and run it with --profile default -y\n'
    else
        installer="$(mktemp /tmp/lyra-rustup-init.XXXXXX)"
        trap 'rm -f -- "${installer:-}"' EXIT
        curl --proto '=https' --tlsv1.2 --fail --silent --show-error \
            https://sh.rustup.rs --output "$installer"
        sh "$installer" -y --profile default --no-modify-path
        rm -f -- "$installer"
        trap - EXIT
    fi

    if (( DRY_RUN )) || command -v rustup >/dev/null 2>&1; then
        run rustup default stable
        run rustup component add rustfmt clippy
    fi
}

install_codex_cli() {
    log "Installing the Codex CLI"
    run npm config set prefix "${HOME}/.local"
    run npm install --global @openai/codex@latest
}

configure_osc() {
    local osc_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/osc"
    local osc_config="${osc_dir}/oscrc"
    local obs_user="${OBS_USER:-rodrigosbrito}"

    log "Configuring osc for the Open Build Service"
    if [[ ! -f "$osc_config" ]]; then
        if (( DRY_RUN )); then
            printf '  + create %q (mode 0600) for %s as %s\n' \
                "$osc_config" "$OBS_API_URL" "$obs_user"
        else
            umask 077
            mkdir -p "$osc_dir"
            {
                printf '[general]\n'
                printf 'apiurl = %s\n\n' "$OBS_API_URL"
                printf '[%s]\n' "$OBS_API_URL"
                printf 'user = %s\n' "$obs_user"
                printf 'credentials_mgr_class = %s\n' "$OBS_CREDENTIALS_MANAGER"
            } > "$osc_config"
            chmod 0600 "$osc_config"
        fi
    else
        print_command osc config general apiurl "$OBS_API_URL"
        print_command osc config "$OBS_API_URL" user "$obs_user"
        print_command osc config "$OBS_API_URL" credentials_mgr_class "$OBS_CREDENTIALS_MANAGER"
        if (( ! DRY_RUN )); then
            (
                cd /tmp
                osc config general apiurl "$OBS_API_URL"
                osc config "$OBS_API_URL" user "$obs_user"
                osc config "$OBS_API_URL" credentials_mgr_class "$OBS_CREDENTIALS_MANAGER"
            )
            chmod 0600 "$osc_config"
        fi
    fi

    log "Checking the public OBS endpoint"
    run curl --fail --silent --show-error --retry 3 --output /dev/null \
        "${OBS_API_URL}/about"
}

configure_virtualization() {
    local group_name
    local current_user

    current_user=$(id -un)

    log "Configuring local virtualization"
    if (( ! DRY_RUN )); then
        for group_name in kvm libvirt; do
            if getent group "$group_name" >/dev/null; then
                run_as_root usermod --append --groups "$group_name" "$current_user"
            fi
        done

        if systemctl list-unit-files libvirtd.service --no-legend 2>/dev/null \
            | grep -q '^libvirtd\.service'; then
            run_as_root systemctl enable --now libvirtd.service
        fi
    else
        printf '  + add %q to the kvm and libvirt groups when available\n' "$current_user"
        printf '  + enable libvirtd.service when available\n'
    fi
}

verify_commands() {
    (( INSTALL_PACKAGES )) || return 0

    local -a required_commands=(
        cc c++ make cmake ninja meson
        git git-lfs gh osc
        rustc cargo go node npm
        rpmbuild rpmlint shellcheck
    )
    local -a virtualization_commands=(kiwi-ng qemu-system-x86_64 qemu-img)
    local command_name
    local failures=0

    (( DRY_RUN )) && return

    if (( INSTALL_CODEX )); then
        required_commands+=(codex)
    fi
    if (( INSTALL_VIRTUALIZATION )); then
        required_commands+=("${virtualization_commands[@]}")
    fi

    if (( INSTALL_RUSTUP )); then
        required_commands+=(rustfmt clippy-driver)
    fi

    log "Verifying installed commands"
    for command_name in "${required_commands[@]}"; do
        if command -v "$command_name" >/dev/null 2>&1; then
            printf '  ok  %-24s %s\n' "$command_name" "$(command -v "$command_name")"
        else
            printf '  missing  %s\n' "$command_name" >&2
            failures=1
        fi
    done

    (( failures == 0 )) || die "one or more required commands are missing"
}

print_next_steps() {
    cat <<EOF

Bootstrap completed.

Open a new login session before using libvirt, then complete authentication:

  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  gh auth login --hostname github.com --git-protocol ssh --web
  gh auth setup-git
  osc config ${OBS_API_URL} --change-password
  osc my projects
  codex login
  codex login status

Credentials are intentionally not copied or embedded by this script.
EOF
}

main() {
    parse_args "$@"
    check_target_system
    ensure_profile_path

    if (( INSTALL_PACKAGES )); then
        if (( ! DRY_RUN )); then
            sudo -v
        fi
        install_system_packages
    fi

    configure_git

    if (( INSTALL_RUSTUP )); then
        install_user_rust_toolchain
    fi
    if (( INSTALL_CODEX )); then
        install_codex_cli
    fi

    configure_osc

    if (( INSTALL_VIRTUALIZATION )); then
        configure_virtualization
    fi

    verify_commands
    print_next_steps
}

main "$@"
