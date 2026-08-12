#!/usr/bin/env bash
# Instala o módulo NVIDIA G06 assinado e o userspace correspondente no
# Lyra OS/openSUSE Leap 16. Mantê-los em lockstep evita que as saídas HDMI/DP
# ligadas à GPU dedicada desapareçam por incompatibilidade de firmware GSP.

set -Eeuo pipefail

readonly REPO_ALIAS="repo-nvidia"
readonly REPO_URL="https://download.nvidia.com/opensuse/leap/16.0/"
readonly KMP_META="nvidia-open-driver-G06-signed-kmp-meta"
readonly USERSPACE_META="nvidia-userspace-meta-G06"

DRY_RUN=0
CHECK_ONLY=0

usage() {
    cat <<'EOF'
Uso: install-nvidia-g06.sh [--dry-run | --check]

  --dry-run  mostra as alterações sem executá-las
  --check    valida o driver e os conectores depois do reinício
  -h, --help mostra esta ajuda
EOF
}

die() {
    printf 'erro: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '\n==> %s\n' "$*"
}

run() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
    if (( ! DRY_RUN )); then
        "$@"
    fi
}

run_root() {
    run sudo -- "$@"
}

parse_args() {
    while (( $# )); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --check) CHECK_ONLY=1 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "opção desconhecida: $1" ;;
        esac
        shift
    done
    (( ! DRY_RUN || ! CHECK_ONLY )) || die "use somente --dry-run ou --check"
}

check_system() {
    [[ $EUID -ne 0 ]] || die "execute como usuário normal, sem sudo antes do script"
    for command_name in lspci rpm sudo zypper; do
        command -v "$command_name" >/dev/null 2>&1 || die "$command_name não está instalado"
    done
    [[ -r /etc/os-release ]] || die "/etc/os-release não encontrado"

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ ${ID:-} != "lyra-os" && ! ( ${ID:-} == "opensuse-leap" && ${VERSION_ID:-} == "16.0" ) ]]; then
        die "suportado somente no Lyra OS/openSUSE Leap 16.0; encontrado: ${PRETTY_NAME:-desconhecido}"
    fi
    lspci -Dnnd 10de: | grep -Eqi '0300|0302' || die "nenhuma GPU NVIDIA foi detectada"
}

show_hardware() {
    log "Hardware detectado"
    lspci -nnk | sed -n '/VGA compatible controller\|3D controller\|Display controller/,+3p'
    if command -v mokutil >/dev/null 2>&1; then
        mokutil --sb-state || true
    fi
}

check_driver() {
    local nvidia_driver=""
    local status_file
    local connector_count=0

    show_hardware
    while IFS= read -r device; do
        [[ -L "$device/driver" ]] || continue
        if [[ $(basename "$(readlink -f "$device/driver")") == nvidia ]]; then
            nvidia_driver="$(readlink -f "$device/driver")"
            break
        fi
    done < <(find /sys/bus/pci/devices -mindepth 1 -maxdepth 1 -type l -print)

    [[ -n "$nvidia_driver" ]] || die "NVIDIA não está vinculada ao driver; reinicie se acabou de instalar"
    printf 'Driver ativo: %s\n' "$nvidia_driver"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    fi

    log "Conectores gráficos"
    for status_file in /sys/class/drm/card*-*/status; do
        [[ -r "$status_file" ]] || continue
        printf '%s: %s\n' "${status_file%/status}" "$(<"$status_file")"
        connector_count=$((connector_count + 1))
    done
    (( connector_count > 0 )) || die "nenhum conector DRM foi publicado"
}

create_snapshot() {
    command -v snapper >/dev/null 2>&1 || die "Snapper não está instalado; instalação abortada sem snapshot"
    log "Criando snapshot de recuperação"
    run_root snapper create --type single --read-only \
        --description "antes do driver NVIDIA G06" --cleanup-algorithm number
}

ensure_repository() {
    local existing_url=""

    log "Configurando o repositório oficial NVIDIA"
    if zypper --quiet lr "$REPO_ALIAS" >/dev/null 2>&1; then
        existing_url="$(zypper --xmlout lr -u "$REPO_ALIAS" 2>/dev/null | sed -n 's/.*url="\([^"]*\)".*/\1/p' | head -n 1)"
        [[ -z "$existing_url" || "$existing_url" == "$REPO_URL" ]] || \
            die "$REPO_ALIAS já aponta para outra URL: $existing_url"
    else
        run_root zypper addrepo --refresh --check "$REPO_URL" "$REPO_ALIAS"
    fi
    run_root zypper --gpg-auto-import-keys refresh "$REPO_ALIAS"
}

install_driver() {
    local individual_packages=""

    individual_packages="$(rpm -qa | grep -E '^nvidia-(driver|video|gl|common|compute)-G06' || true)"
    if [[ -n "$individual_packages" ]] && ! rpm -q "$KMP_META" "$USERSPACE_META" >/dev/null 2>&1; then
        printf '%s\n' "$individual_packages" >&2
        die "instalação G06 parcial encontrada; remova esses pacotes antes para evitar versões incompatíveis"
    fi

    create_snapshot
    ensure_repository
    log "Instalando módulo, userspace e firmware G06 em lockstep"
    run_root zypper --non-interactive install "$KMP_META" "$USERSPACE_META"
    log "Regenerando o initramfs"
    run_root dracut --force

    if (( DRY_RUN )); then
        printf '\nDry-run concluído; nenhuma alteração foi feita.\n'
    else
        printf '\nInstalação concluída. Reinicie e execute:\n  %q --check\n' "$0"
    fi
}

main() {
    parse_args "$@"
    check_system
    if (( CHECK_ONLY )); then
        check_driver
    else
        show_hardware
        install_driver
    fi
}

main "$@"
