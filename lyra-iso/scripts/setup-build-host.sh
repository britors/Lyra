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
REPO_ROOT="$(cd "$LYRA_ISO_DIR/.." && pwd)"
PACMAN_CONF="$LYRA_ISO_DIR/pacman.conf"
LOG_FILE="$LYRA_REPO_DIR/setup.log"

# Pacotes AUR do ecossistema Lyra disponíveis para build local.
# Atualizar esta lista conforme novos pacotes forem publicados no AUR:
# calco, pulso, vega, vegad ainda NÃO estão aqui — adicionar quando publicados.
LYRA_AUR_PACKAGES=(
    "prosa"
    "fina"
    # calamares saiu dos repositórios oficiais (core/extra) e hoje só existe
    # no AUR — sem isso o build.sh falha com "target not found: calamares".
    # Compila do zero (kpmcore/Qt6), pode levar alguns minutos.
    "calamares"
    # Publicado no AUR real (https://aur.archlinux.org/packages/lyra-tour) —
    # ver PROMPT-LYRA-OS-INTEGRACAO-TOUR-AUR.md. Versão travada em
    # packages.aur.lock.
    "lyra-tour"
    # App de terceiros (mantido por psygreg), oferecido como conveniência —
    # ver PROMPT-LYRA-OS-ADICIONA-LINUXTOYS.md. Versão travada em
    # packages.aur.lock.
    "linuxtoys-bin"
)

# Pacotes com PKGBUILD dentro deste monorepo (não são AUR — o próprio yay não
# resolve). Build via makepkg direto, mesmo tratamento de repositório local
# dos pacotes AUR acima. Caminhos relativos à raiz do repo.
LOCAL_PACKAGE_DIRS=(
    "lyra-branding"
    "calamares-lyra-winmigrate"
)

SYSTEM_PACKAGES=(
    archiso
    git
    dosfstools
    grub
    xorriso
    base-devel
    cantarell-fonts
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
    # --rebuild (não --needed): precisamos do artefato .pkg.tar.zst desta
    # build no cache do yay mesmo que o pacote já esteja instalado no host
    # (--needed pula a build inteira nesse caso, deixando o cache vazio).
    yay -S --rebuild --noconfirm "$pkg"

    # "|| true" evita que um `find` sobre diretório de cache inexistente
    # aborte o script silenciosamente sob set -e/pipefail antes do check
    # de $pkgfile abaixo (é exatamente o que fazia o script morrer sem
    # nenhuma mensagem quando o cache não tinha o pacote esperado).
    #
    # "-name "$pkg-*"" (sem "*.pkg.tar.zst" genérico) + exclusão explícita
    # de "$pkg-debug-*": makepkg gera automaticamente um pacote "$pkg-debug"
    # com símbolos de depuração quando o PKGBUILD não desabilita (options
    # sem '!debug'). Sem o filtro, "sort -rn | head -1" por mtime pode
    # escolher o pacote de debug em vez do pacote real (foi o que aconteceu
    # com calamares e fina) — o repositório fica com o artefato errado.
    pkgfile="$(find "$HOME/.cache/yay/$pkg" -name "${pkg}-*.pkg.tar.zst" \
                ! -name "${pkg}-debug-*.pkg.tar.zst" -printf '%T@ %p\n' 2>/dev/null \
                | sort -rn | head -1 | cut -d' ' -f2- || true)"

    if [[ -z "$pkgfile" ]]; then
        fail "Não encontrei o pacote compilado de '$pkg' em $HOME/.cache/yay/$pkg"
    fi

    cp -f "$pkgfile" "$LYRA_REPO_DIR/"
    log "  -> copiado: $(basename "$pkgfile")"
done

# --- Passo 4b — build e cópia dos pacotes locais (PKGBUILD no monorepo) ---
for pkg_dir in "${LOCAL_PACKAGE_DIRS[@]}"; do
    full_path="$REPO_ROOT/$pkg_dir"
    log "Processando pacote local: $pkg_dir"

    if [[ ! -f "$full_path/PKGBUILD" ]]; then
        fail "Não encontrei $full_path/PKGBUILD"
    fi

    # -s/--syncdeps instala via pacman as dependências declaradas no PKGBUILD
    # (ex.: python-yaml, rsync, ntfs-3g do calamares-lyra-winmigrate) que não
    # estejam já instaladas no host — sem isso makepkg só verifica e aborta.
    #
    # -i instala o próprio pacote local no host logo após buildar. Sem isso,
    # calamares-lyra-winmigrate (que depende de lyra-branding, buildado
    # antes dele neste mesmo loop) nunca resolve essa dependência: o
    # repositório [lyra] só é registrado em pacman.conf no Passo 6, bem
    # depois deste loop, então "lyra-branding" não está instalado nem
    # disponível em nenhum repositório no momento em que é preciso. Os
    # pacotes AUR já não sofriam disso porque "yay -S" já instala no host
    # como efeito colateral.
    ( cd "$full_path" && makepkg -sfi --noconfirm )

    pkg="$(basename "$pkg_dir")"
    pkgfile="$(find "$full_path" -maxdepth 1 -name "${pkg}-*.pkg.tar.zst" \
                ! -name "${pkg}-debug-*.pkg.tar.zst" -printf '%T@ %p\n' 2>/dev/null \
                | sort -rn | head -1 | cut -d' ' -f2- || true)"

    if [[ -z "$pkgfile" ]]; then
        fail "makepkg não gerou um .pkg.tar.zst em $full_path"
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

for pkg_dir in "${LOCAL_PACKAGE_DIRS[@]}"; do
    pkg="$(basename "$pkg_dir")"
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
