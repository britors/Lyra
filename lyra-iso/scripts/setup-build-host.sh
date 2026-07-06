#!/usr/bin/env bash
# Prepara uma máquina Arch Linux para buildar o ISO do Lyra OS localmente.
# Ver PROMPT-LYRA-ISO-SETUP-HOST.md para a especificação completa.
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
    echo "Não execute este script como root. Ele usa sudo internamente quando necessário." >&2
    exit 1
fi

LYRA_REPO_DIR="$HOME/.local/share/lyra-repo"
LYRA_ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACMAN_CONF="$LYRA_ISO_DIR/pacman.conf"
LOG_FILE="$LYRA_REPO_DIR/setup.log"

# Pacotes AUR do ecossistema Lyra disponíveis para build local.
# Atualizar esta lista conforme novos pacotes forem publicados no AUR:
# calco, pulso, lyra-tour, vega, vegad ainda NÃO estão aqui — adicionar quando publicados.
LYRA_AUR_PACKAGES=(
    "prosa"
    "fina"
)

SYSTEM_PACKAGES=(
    archiso
    git
    dosfstools
    grub
    xorriso
    base-devel
)

mkdir -p "$LYRA_REPO_DIR"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
fail() { echo "ERRO: $*" | tee -a "$LOG_FILE" >&2; exit 1; }

# --- Passo 1 — pacotes de sistema ---------------------------------------
log "Instalando dependências de sistema: ${SYSTEM_PACKAGES[*]}"
if ! sudo pacman -S --needed --noconfirm "${SYSTEM_PACKAGES[@]}"; then
    fail "Falha ao instalar pacotes de sistema (ver mensagem do pacman acima para identificar qual pacote não foi encontrado)."
fi

# --- Passo 3 — yay --------------------------------------------------------
if command -v yay >/dev/null 2>&1; then
    log "yay já instalado, pulando."
else
    log "yay não encontrado, instalando..."
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# --- Passo 4 — build e cópia dos pacotes AUR ------------------------------
for pkg in "${LYRA_AUR_PACKAGES[@]}"; do
    log "Processando pacote AUR: $pkg"
    yay -S --needed --noconfirm "$pkg"

    pkgfile="$(find "$HOME/.cache/yay/$pkg" -name '*.pkg.tar.zst' -printf '%T@ %p\n' 2>/dev/null \
                | sort -rn | head -1 | cut -d' ' -f2-)"

    if [[ -z "$pkgfile" ]]; then
        fail "Não encontrei o pacote compilado de '$pkg' em $HOME/.cache/yay/$pkg"
    fi

    cp -f "$pkgfile" "$LYRA_REPO_DIR/"
    log "  -> copiado: $(basename "$pkgfile")"
done

# --- Passo 5 — repositório de arquivo local -------------------------------
log "Atualizando repositório local em $LYRA_REPO_DIR"
if [[ -f "$LYRA_REPO_DIR/lyra.db.tar.gz" ]]; then
    repo-add "$LYRA_REPO_DIR/lyra.db.tar.gz" "$LYRA_REPO_DIR"/*.pkg.tar.zst
else
    repo-add --new "$LYRA_REPO_DIR/lyra.db.tar.gz" "$LYRA_REPO_DIR"/*.pkg.tar.zst
fi

# --- Passo 6 — pacman.conf do perfil archiso ------------------------------
if [[ ! -f "$PACMAN_CONF" ]]; then
    fail "Arquivo não encontrado: $PACMAN_CONF"
fi

if ! grep -q '^\[lyra\]' "$PACMAN_CONF"; then
    log "Adicionando seção [lyra] em $PACMAN_CONF"
    {
        echo ""
        echo "# ATENÇÃO: repositório local de desenvolvimento (TrustAll)."
        echo "# Ao publicar o repositório 'lyra' oficial com assinatura GPG própria,"
        echo "# substituir este bloco pela configuração de produção do PROMPT-LYRA-OS.md §10.1."
        echo "[lyra]"
        echo "SigLevel = Optional TrustAll"
        echo "Server = file://$LYRA_REPO_DIR"
    } >> "$PACMAN_CONF"
else
    existing_server="$(awk '/^\[lyra\]/{f=1; next} /^\[/{f=0} f && /^Server/{print; exit}' "$PACMAN_CONF")"
    expected_server="Server = file://$LYRA_REPO_DIR"
    if [[ "$existing_server" == "$expected_server" ]]; then
        log "Seção [lyra] já existe em $PACMAN_CONF e já aponta para o repositório local."
    else
        log "AVISO: seção [lyra] já existe em $PACMAN_CONF mas aponta para um caminho diferente do esperado."
        log "  Esperado: $expected_server"
        log "  Encontrado: ${existing_server:-<nenhuma linha Server>}"
        log "  Nenhuma alteração automática foi feita — revise manualmente se necessário."
    fi
fi

# --- Passo 7 — validação final --------------------------------------------
log "Validando..."
validation_failed=0

if command -v mkarchiso >/dev/null 2>&1; then
    echo "[ok] archiso instalado (mkarchiso encontrado em \$PATH)"
else
    echo "[FALHA] archiso não encontrado (mkarchiso ausente do \$PATH)"
    validation_failed=1
fi

if command -v yay >/dev/null 2>&1; then
    echo "[ok] yay instalado"
else
    echo "[FALHA] yay não encontrado"
    validation_failed=1
fi

for pkg in "${LYRA_AUR_PACKAGES[@]}"; do
    if ls "$LYRA_REPO_DIR/$pkg"-*.pkg.tar.zst >/dev/null 2>&1; then
        echo "[ok] $pkg: pacote presente no repositório local"
    else
        echo "[FALHA] $pkg: pacote ausente do repositório local"
        validation_failed=1
    fi
done

if grep -q '^\[lyra\]' "$PACMAN_CONF"; then
    echo "[ok] $LYRA_ISO_DIR/pacman.conf contém seção [lyra]"
else
    echo "[FALHA] $LYRA_ISO_DIR/pacman.conf não contém seção [lyra]"
    validation_failed=1
fi

if [[ -f "$LYRA_REPO_DIR/lyra.db.tar.gz" ]]; then
    echo "[ok] repo-add executado sem erros — lyra.db.tar.gz presente"
else
    echo "[FALHA] lyra.db.tar.gz não encontrado em $LYRA_REPO_DIR"
    validation_failed=1
fi

if [[ "$validation_failed" -ne 0 ]]; then
    echo "" >&2
    echo "Setup incompleto — corrija os itens marcados [FALHA] acima e rode o script novamente." >&2
    exit 1
fi

echo ""
echo "Pronto. Rode ./build.sh dentro de $LYRA_ISO_DIR para gerar o ISO."
