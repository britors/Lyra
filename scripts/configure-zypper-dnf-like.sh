#!/usr/bin/env bash
# Configure Zypper with cache and refresh defaults close to DNF5.

set -Eeuo pipefail

readonly CONFIG_DIR="/etc/zypp/zypp.conf.d"
readonly CONFIG_FILE="${CONFIG_DIR}/90-lyra-dnf-like.conf"
readonly REPOS_DIR="/etc/zypp/repos.d"
readonly BACKUP_ROOT="/var/lib/lyra/zypper-policy-backups"

DRY_RUN=0
CLEAN_PACKAGES=1
RESTORE_DIR=""

usage() {
    cat <<'EOF'
Uso: configure-zypper-dnf-like.sh [opções]

Configura o Zypper para se comportar de forma semelhante ao DNF5:
  - metadados válidos por 48 horas;
  - até 5 downloads concorrentes;
  - sem Delta RPM;
  - sem retenção de RPMs depois de transações bem-sucedidas.

Opções:
  --dry-run   mostra as alterações sem modificar o sistema
  --no-clean  não remove os RPMs que já estão no cache
  --restore DIRETÓRIO
              restaura um backup criado por este script
  -h, --help  mostra esta ajuda
EOF
}

die() {
    printf 'erro: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '\n==> %s\n' "$*"
}

print_command() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
}

run_root() {
    print_command sudo -- "$@"
    if (( ! DRY_RUN )); then
        sudo -- "$@"
    fi
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --no-clean) CLEAN_PACKAGES=0 ;;
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

restore_backup() {
    local canonical_backup canonical_root

    [[ -d $RESTORE_DIR/repos.d ]] || die "backup inválido: $RESTORE_DIR"
    canonical_backup="$(readlink -f -- "$RESTORE_DIR")"
    canonical_root="$(readlink -f -- "$BACKUP_ROOT")"
    [[ $canonical_backup == "$canonical_root"/* ]] || \
        die "o backup deve estar dentro de $BACKUP_ROOT"

    log "Restaurando repositórios de ${canonical_backup}"
    run_root cp -a "${canonical_backup}/repos.d/." "${REPOS_DIR}/"
    if [[ -e $canonical_backup/config-was-absent ]]; then
        run_root rm -f -- "$CONFIG_FILE"
    elif [[ -f $canonical_backup/90-lyra-dnf-like.conf ]]; then
        run_root cp -a "$canonical_backup/90-lyra-dnf-like.conf" "$CONFIG_FILE"
    fi
    printf '\nBackup restaurado. Repositórios adicionados depois do backup foram preservados.\n'
}

check_system() {
    [[ $EUID -ne 0 ]] || die "execute como usuário normal, sem sudo antes do script"
    command -v sudo >/dev/null 2>&1 || die "sudo não está instalado"
    command -v zypper >/dev/null 2>&1 || die "zypper não está instalado"
    [[ -d $REPOS_DIR ]] || die "$REPOS_DIR não existe"
}

create_backup() {
    local backup_id backup_dir

    backup_id="$(date -u +%Y%m%dT%H%M%SZ)"
    backup_dir="${BACKUP_ROOT}/${backup_id}"
    log "Criando backup em ${backup_dir}"
    run_root install -d -m 0755 "$backup_dir"
    run_root cp -a "$REPOS_DIR" "${backup_dir}/repos.d"
    if [[ -e $CONFIG_FILE ]]; then
        run_root cp -a "$CONFIG_FILE" "${backup_dir}/90-lyra-dnf-like.conf"
    elif (( ! DRY_RUN )); then
        sudo -- touch "${backup_dir}/config-was-absent"
    else
        print_command sudo -- touch "${backup_dir}/config-was-absent"
    fi
}

write_policy() {
    local temporary

    temporary="$(mktemp /tmp/lyra-zypper-policy.XXXXXX)"
    trap 'rm -f -- "${temporary:-}"' EXIT
    printf '%s\n' \
        '[main]' \
        '# Lyra: cache policy aligned with DNF5 defaults.' \
        '# Vega may still perform an explicit refresh when checking for updates.' \
        'repo.refresh.delay = 2880' \
        'download.max_concurrent_connections = 5' \
        'download.use_deltarpm = false' > "$temporary"

    log "Instalando política de metadados e downloads"
    run_root install -D -m 0644 "$temporary" "$CONFIG_FILE"
    rm -f -- "$temporary"
    trap - EXIT
}

configure_repositories() {
    log "Desativando a retenção de RPMs em todos os repositórios"
    run_root zypper --non-interactive modifyrepo --no-keep-packages --all

    if (( CLEAN_PACKAGES )); then
        log "Removendo somente os RPMs já acumulados no cache"
        # On Leap 16, `clean` without cache-selection flags removes downloaded
        # packages. `--all` would also discard metadata and force a full refresh.
        run_root zypper --non-interactive clean
    fi
}

show_result() {
    if (( DRY_RUN )); then
        printf '\nDry-run concluído; nenhuma alteração foi feita.\n'
        return
    fi

    log "Configuração resultante"
    grep -Ev '^[[:space:]]*(#|$)' "$CONFIG_FILE"
    zypper --no-refresh lr -d
    printf '\nConcluído. O autorefresh continua habilitado, mas os metadados são\n'
    printf 'revalidados no máximo após 48 horas. O Vega pode forçar refresh antes\n'
    printf 'de verificar ou instalar atualizações.\n'
}

main() {
    parse_args "$@"
    check_system
    if [[ -n $RESTORE_DIR ]]; then
        restore_backup
        return
    fi
    create_backup
    write_policy
    configure_repositories
    show_result
}

main "$@"
