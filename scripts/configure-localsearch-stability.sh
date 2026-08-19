#!/usr/bin/env bash
# Install Lyra's LocalSearch containment policy on an existing system.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
readonly REPO_ROOT
readonly SOURCE_PREFLIGHT="${REPO_ROOT}/kiwi/root/usr/libexec/lyra-localsearch-preflight"
readonly SOURCE_DROP_IN="${REPO_ROOT}/kiwi/root/usr/lib/systemd/user/localsearch-3.service.d/90-lyra-stability.conf"
readonly TARGET_PREFLIGHT="/usr/libexec/lyra-localsearch-preflight"
readonly TARGET_DROP_IN="/usr/lib/systemd/user/localsearch-3.service.d/90-lyra-stability.conf"
readonly BACKUP_ROOT="/var/lib/lyra/localsearch-policy-backups"

DRY_RUN=0
RESTORE_DIR=""

usage() {
    cat <<'EOF'
Uso: configure-localsearch-stability.sh [opções]

Instala a política de contenção do LocalSearch em uma máquina já instalada.

Opções:
  --dry-run            mostra as alterações sem modificar o sistema
  --restore DIRETÓRIO  restaura um backup criado por este script
  -h, --help           mostra esta ajuda
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
    while (( $# > 0 )); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --restore)
                (( $# >= 2 )) || die "--restore exige o diretório do backup"
                RESTORE_DIR="$2"
                shift
                ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "opção desconhecida: $1" ;;
        esac
        shift
    done
}

check_system() {
    [[ $EUID -ne 0 ]] || die "execute como usuário normal, sem sudo antes do script"
    command -v sudo >/dev/null 2>&1 || die "sudo não está instalado"
    command -v systemctl >/dev/null 2>&1 || die "systemctl não está instalado"
    [[ -x /usr/libexec/localsearch-extractor-3 ]] || \
        die "localsearch-extractor-3 não está instalado"
    [[ -x $SOURCE_PREFLIGHT ]] || die "fonte ausente: $SOURCE_PREFLIGHT"
    [[ -r $SOURCE_DROP_IN ]] || die "fonte ausente: $SOURCE_DROP_IN"
}

backup_file() {
    local source=$1 destination=$2 absent_marker=$3
    if [[ -e $source ]]; then
        run_root cp -a "$source" "$destination"
    else
        run_root touch "$absent_marker"
    fi
}

create_backup() {
    local backup_id backup_dir
    backup_id="$(date -u +%Y%m%dT%H%M%SZ)"
    backup_dir="${BACKUP_ROOT}/${backup_id}"
    log "Criando backup em ${backup_dir}"
    run_root install -d -m 0755 "$backup_dir"
    backup_file "$TARGET_PREFLIGHT" "${backup_dir}/lyra-localsearch-preflight" \
        "${backup_dir}/preflight-was-absent"
    backup_file "$TARGET_DROP_IN" "${backup_dir}/90-lyra-stability.conf" \
        "${backup_dir}/drop-in-was-absent"
}

install_policy() {
    log "Validando dependências atuais do extractor"
    run "$SOURCE_PREFLIGHT"

    log "Instalando preflight e limites de recursos"
    run_root install -D -m 0755 "$SOURCE_PREFLIGHT" "$TARGET_PREFLIGHT"
    run_root install -D -m 0644 "$SOURCE_DROP_IN" "$TARGET_DROP_IN"
}

restore_file() {
    local backup=$1 absent_marker=$2 target=$3 mode=$4
    if [[ -e $absent_marker ]]; then
        run_root rm -f -- "$target"
    elif [[ -e $backup ]]; then
        run_root install -D -m "$mode" "$backup" "$target"
    fi
}

restore_backup() {
    local canonical_backup canonical_root
    [[ -d $RESTORE_DIR ]] || die "backup inexistente: $RESTORE_DIR"
    canonical_backup="$(readlink -f -- "$RESTORE_DIR")"
    canonical_root="$(readlink -f -- "$BACKUP_ROOT")"
    [[ $canonical_backup == "$canonical_root"/* ]] || \
        die "o backup deve estar dentro de $BACKUP_ROOT"

    log "Restaurando ${canonical_backup}"
    restore_file "${canonical_backup}/lyra-localsearch-preflight" \
        "${canonical_backup}/preflight-was-absent" "$TARGET_PREFLIGHT" 0755
    restore_file "${canonical_backup}/90-lyra-stability.conf" \
        "${canonical_backup}/drop-in-was-absent" "$TARGET_DROP_IN" 0644
}

reload_service() {
    log "Recarregando o serviço do usuário"
    run systemctl --user daemon-reload
    run systemctl --user reset-failed localsearch-3.service
    run systemctl --user restart localsearch-3.service
}

main() {
    parse_args "$@"
    check_system
    if [[ -n $RESTORE_DIR ]]; then
        restore_backup
    else
        create_backup
        install_policy
    fi
    reload_service

    if (( DRY_RUN )); then
        printf '\nDry-run concluído; nenhuma alteração foi feita.\n'
    else
        printf '\nPolítica aplicada. Verifique com:\n'
        printf '  systemctl --user status localsearch-3.service\n'
        printf '  systemctl --user show localsearch-3.service -p CPUWeight -p MemoryHigh -p MemoryMax -p TasksMax\n'
    fi
}

main "$@"
