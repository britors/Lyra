#!/usr/bin/env bash
# Prepara a dependência nativa do Tauri no Lyra OS/openSUSE Leap 16 e abre o
# Lyra Installer diretamente pelo workspace Cargo.

set -Eeuo pipefail

readonly WEBKIT_PACKAGE="webkit2gtk3-devel"
readonly WEBKIT_PKG_CONFIG="javascriptcoregtk-4.1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT
readonly INSTALLER_ROOT="$PROJECT_ROOT/installer"

DRY_RUN=0

usage() {
    cat <<'EOF'
Uso: run-installer-dev.sh [--dry-run]

Verifica e, se necessário, instala a biblioteca WebKitGTK 4.1 usada pelo
Tauri. Em seguida compila e abre o Lyra Installer.

  --dry-run  mostra o que seria executado sem instalar ou abrir o programa
  -h, --help mostra esta ajuda
EOF
}

die() {
    printf 'erro: %s\n' "$*" >&2
    exit 1
}

run() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
    if (( ! DRY_RUN )); then
        "$@"
    fi
}

parse_args() {
    while (( $# )); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "opção desconhecida: $1" ;;
        esac
        shift
    done
}

check_system() {
    [[ $EUID -ne 0 ]] || die "execute como usuário normal, sem sudo antes do script"
    [[ -f "$INSTALLER_ROOT/Cargo.toml" ]] || die "workspace do instalador não encontrado"
    for command_name in cargo pkg-config sudo zypper; do
        command -v "$command_name" >/dev/null 2>&1 || die "$command_name não está instalado"
    done
    [[ -r /etc/os-release ]] || die "/etc/os-release não encontrado"

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ ${ID:-} != "lyra-os" && ! ( ${ID:-} == "opensuse-leap" && ${VERSION_ID:-} == "16.0" ) ]]; then
        die "suportado somente no Lyra OS/openSUSE Leap 16.0; encontrado: ${PRETTY_NAME:-desconhecido}"
    fi
}

ensure_webkit() {
    if pkg-config --exists "$WEBKIT_PKG_CONFIG"; then
        printf 'WebKitGTK disponível: %s %s\n' \
            "$WEBKIT_PKG_CONFIG" "$(pkg-config --modversion "$WEBKIT_PKG_CONFIG")"
        return
    fi

    printf 'Instalando a dependência de desenvolvimento %s...\n' "$WEBKIT_PACKAGE"
    run sudo -- zypper --non-interactive install "$WEBKIT_PACKAGE"

    if (( ! DRY_RUN )); then
        pkg-config --exists "$WEBKIT_PKG_CONFIG" || \
            die "$WEBKIT_PACKAGE foi instalado, mas $WEBKIT_PKG_CONFIG continua indisponível"
    fi
}

run_installer() {
    printf 'Abrindo o Lyra Installer...\n'
    if (( DRY_RUN )); then
        printf '  + cd %q\n' "$INSTALLER_ROOT"
        printf '  + cargo run -p lyra-installer\n'
    else
        cd "$INSTALLER_ROOT"
        exec cargo run -p lyra-installer
    fi
}

main() {
    parse_args "$@"
    check_system
    ensure_webkit
    run_installer
}

main "$@"
