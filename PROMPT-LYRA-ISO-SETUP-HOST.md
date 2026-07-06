# PROMPT DE IMPLEMENTAÇÃO — LYRA OS: SETUP DA MÁQUINA HOST PARA BUILD DO ISO

> **Versão:** 1.0
> **Status:** Especificação incremental, pronta para implementação
> **Pré-requisitos:** `PROMPT-LYRA-OS.md` v2.1 (estrutura do `lyra-iso/` já existente, §11)
> **Escopo:** Este documento especifica um script de automação que prepara qualquer máquina Arch Linux para buildar o ISO do Lyra OS localmente, **antes** de existir um repositório `lyra` publicado com assinatura própria. Cobre apenas os pacotes já disponíveis no AUR neste momento: **Prosa** e **Fina**. Calco, Pulso, Lyra Tour e Vega/vegad entram neste mesmo mecanismo assim que estiverem publicados — sem necessidade de reescrever o script, apenas atualizar uma lista (§3.2).

---

## 1. Objetivo

Um único script idempotente que, executado do zero em uma máquina Arch limpa, deixa tudo pronto para rodar `mkarchiso` sobre o perfil `lyra-iso/`:

1. Instala as ferramentas de build do sistema (archiso e dependências)
2. Instala o `yay` se ausente
3. Compila os pacotes AUR do ecossistema Lyra disponíveis hoje (Prosa, Fina)
4. Monta um repositório Pacman de arquivo local com esses pacotes
5. Gera/atualiza o `pacman.conf` do perfil archiso apontando para esse repositório
6. Valida que tudo está pronto para o build

**Não** é escopo deste script: rodar o `mkarchiso` em si (isso é o `build.sh` do perfil, já especificado no prompt base) — este script apenas prepara o terreno na máquina host.

---

## 2. Localização e Convenções

| Item | Valor |
|---|---|
| Nome do script | `setup-build-host.sh` |
| Localização no repositório | `lyra-iso/scripts/setup-build-host.sh` |
| Repositório local de pacotes | `~/.local/share/lyra-repo/` (por usuário, não versionado) |
| Log de execução | `~/.local/share/lyra-repo/setup.log` |

- O script deve ser **idempotente**: rodar duas vezes não deve falhar nem duplicar trabalho — pacotes já instalados são pulados, repositório existente é atualizado (`repo-add` com a flag adequada), não recriado do zero
- Deve rodar com o usuário comum, **nunca como root diretamente** (`sudo` é invocado internamente apenas nos passos que exigem, via `pacman`; `makepkg`/`yay` nunca rodam como root — o script deve abortar com mensagem clara se detectar `EUID=0`)

---

## 3. Especificação do Script

### 3.1 Passo 1 — Pacotes de sistema (build do ISO)

Verificar e instalar, via `pacman -S --needed` (a flag `--needed` já garante idempotência nativa do Pacman — não reinstala o que já está atualizado):

```bash
archiso git dosfstools grub xorriso base-devel
```

- Usar `--needed` explicitamente para não forçar reinstalação
- Se algum pacote não for encontrado (histórico já mostrou isso acontecer com `bridge-utils`), o script deve reportar exatamente qual pacote falhou e abortar — nunca tentar adivinhar substituto silenciosamente

### 3.2 Passo 2 — Lista de pacotes AUR do ecossistema Lyra

Lista mantida em variável no topo do script, fácil de estender quando novos pacotes forem publicados:

```bash
# Pacotes AUR do ecossistema Lyra disponíveis para build local.
# Atualizar esta lista conforme novos pacotes forem publicados no AUR:
# calco, pulso, lyra-tour, vega, vegad ainda NÃO estão aqui — adicionar quando publicados.
LYRA_AUR_PACKAGES=(
    "prosa"
    "fina"
)
```

- O restante do script **nunca** deve hardcodar "prosa" ou "fina" fora desta variável — todo loop itera sobre `LYRA_AUR_PACKAGES`, para que adicionar um pacote no futuro seja uma edição de uma linha

### 3.3 Passo 3 — Instalação do yay

- Verificar se `yay` já está no `PATH`; se sim, pular
- Se ausente, instalar a partir do AUR pelo processo padrão (`git clone` + `makepkg -si`), em diretório temporário descartável (`mktemp -d`), nunca poluindo o diretório de trabalho do usuário

### 3.4 Passo 4 — Build dos pacotes AUR

Para cada pacote em `LYRA_AUR_PACKAGES`:

- Rodar `yay -S --needed --noconfirm <pacote>` **apenas para instalar no sistema do host** (necessário para o passo seguinte conseguir localizar o `.pkg.tar.zst` gerado)

  > Nota de design: instalar no host é intencional e inofensivo — Prosa e Fina são aplicativos normais, e o repo local reaproveita exatamente o pacote binário que o `yay` já constrói e assina localmente, evitando build duplicado.

- Localizar o arquivo de pacote resultante em `~/.cache/yay/<pacote>/*.pkg.tar.zst` (caminho padrão do cache do yay)
- Se múltiplas versões estiverem em cache, usar a mais recente por data de modificação
- Copiar (não mover) o arquivo para `~/.local/share/lyra-repo/`

### 3.5 Passo 5 — Repositório de arquivo local

```bash
repo-add --new ~/.local/share/lyra-repo/lyra.db.tar.gz ~/.local/share/lyra-repo/*.pkg.tar.zst
```

- Usar `--new` apenas na primeira criação; em execuções seguintes, `repo-add` sem essa flag já atualiza o banco existente incrementalmente — o script deve detectar se o `.db.tar.gz` já existe para decidir a flag correta
- Ao final, rodar `repo-add` novamente sempre que houver pacote novo copiado, mesmo que o banco já exista (garante que atualizações de versão de Prosa/Fina entrem no índice)

### 3.6 Passo 6 — `pacman.conf` do perfil archiso

- Arquivo alvo: `lyra-iso/pacman.conf` (já existente conforme `PROMPT-LYRA-OS.md` §11)
- O script verifica se a seção `[lyra]` já existe; se não existir, **acrescenta** ao final do arquivo (nunca sobrescreve o arquivo inteiro — outros repositórios/config podem já estar lá):

```ini
[lyra]
SigLevel = Optional TrustAll
Server = file:///home/SEU_USUARIO/.local/share/lyra-repo
```

- O caminho do `Server` deve ser gerado dinamicamente a partir de `$HOME` no momento da execução (`file://$HOME/.local/share/lyra-repo`), nunca hardcodado com um nome de usuário específico — para o script funcionar em qualquer máquina de qualquer contribuidor do projeto
- Se a seção `[lyra]` já existir mas apontar para um caminho diferente, avisar o usuário e não sobrescrever automaticamente (evitar corromper configuração feita manualmente) — apenas reportar a divergência

> **Aviso permanente no arquivo `pacman.conf` gerado, como comentário acima da seção:** `# ATENÇÃO: repositório local de desenvolvimento (TrustAll). Ao publicar o repositório "lyra" oficial com assinatura GPG própria, substituir este bloco pela configuração de produção do PROMPT-LYRA-OS.md §10.1.`

### 3.7 Passo 7 — Validação final

O script encerra confirmando, em ordem, e reportando sucesso/falha de cada item:

```
[ok] archiso instalado (mkarchiso encontrado em $PATH)
[ok] yay instalado
[ok] prosa: pacote presente no repositório local
[ok] fina: pacote presente no repositório local
[ok] lyra-iso/pacman.conf contém seção [lyra] válida
[ok] repo-add executado sem erros — lyra.db.tar.gz atualizado
```

- Se qualquer item falhar, o script **não** deve prosseguir para os seguintes de forma silenciosa — reportar o erro específico e sair com código de saída não-zero
- Mensagem final de sucesso deve indicar o próximo passo: `Pronto. Rode ./build.sh dentro de lyra-iso/ para gerar o ISO.`

---

## 4. Estrutura de Arquivos

```
lyra-iso/
├── scripts/
│   └── setup-build-host.sh
├── pacman.conf              # editado em-lugar pelo script (Passo 6)
└── ... (demais arquivos já especificados no PROMPT-LYRA-OS.md §11)
```

---

## 5. Esqueleto do Script

Estrutura mínima esperada (o implementador preenche a lógica de cada passo conforme §3):

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
    echo "Não execute este script como root. Ele usa sudo internamente quando necessário." >&2
    exit 1
fi

LYRA_REPO_DIR="$HOME/.local/share/lyra-repo"
LYRA_ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$LYRA_REPO_DIR/setup.log"

# Pacotes AUR do ecossistema Lyra disponíveis para build local.
# Atualizar esta lista conforme novos pacotes forem publicados no AUR:
# calco, pulso, lyra-tour, vega, vegad ainda NÃO estão aqui.
LYRA_AUR_PACKAGES=(
    "prosa"
    "fina"
)

mkdir -p "$LYRA_REPO_DIR"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }

# Passo 1 — pacotes de sistema
log "Instalando dependências de sistema..."
sudo pacman -S --needed --noconfirm archiso git dosfstools grub xorriso base-devel

# Passo 3 — yay
if ! command -v yay >/dev/null 2>&1; then
    log "yay não encontrado, instalando..."
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
else
    log "yay já instalado, pulando."
fi

# Passo 4 — build e cópia dos pacotes AUR
for pkg in "${LYRA_AUR_PACKAGES[@]}"; do
    log "Processando pacote AUR: $pkg"
    yay -S --needed --noconfirm "$pkg"

    pkgfile="$(find "$HOME/.cache/yay/$pkg" -name '*.pkg.tar.zst' -printf '%T@ %p\n' \
                | sort -rn | head -1 | cut -d' ' -f2-)"

    if [[ -z "$pkgfile" ]]; then
        echo "Falha: não encontrei o pacote compilado de $pkg em ~/.cache/yay/$pkg" >&2
        exit 1
    fi

    cp -f "$pkgfile" "$LYRA_REPO_DIR/"
    log "  -> copiado: $(basename "$pkgfile")"
done

# Passo 5 — repositório local
cd "$LYRA_REPO_DIR"
if [[ -f "lyra.db.tar.gz" ]]; then
    repo-add lyra.db.tar.gz ./*.pkg.tar.zst
else
    repo-add --new lyra.db.tar.gz ./*.pkg.tar.zst
fi

# Passo 6 — pacman.conf do perfil
PACMAN_CONF="$LYRA_ISO_DIR/pacman.conf"
if ! grep -q '^\[lyra\]' "$PACMAN_CONF" 2>/dev/null; then
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
    log "Seção [lyra] já existe em $PACMAN_CONF — verifique manualmente se o Server está correto."
fi

# Passo 7 — validação final
log "Validando..."
command -v mkarchiso >/dev/null && echo "[ok] archiso instalado"
command -v yay >/dev/null && echo "[ok] yay instalado"
for pkg in "${LYRA_AUR_PACKAGES[@]}"; do
    ls "$LYRA_REPO_DIR"/"$pkg"-*.pkg.tar.zst >/dev/null 2>&1 \
        && echo "[ok] $pkg: pacote presente no repositório local" \
        || echo "[FALHA] $pkg: pacote ausente"
done
grep -q '^\[lyra\]' "$PACMAN_CONF" && echo "[ok] pacman.conf contém seção [lyra]"

echo ""
echo "Pronto. Rode ./build.sh dentro de $LYRA_ISO_DIR para gerar o ISO."
```

---

## 6. Validação

- [ ] Executar em máquina Arch limpa (VM de teste): script completa sem erro do início ao fim
- [ ] Executar novamente logo em seguida (idempotência): nenhum erro, nenhuma duplicação no `pacman.conf`, repositório atualizado sem recriação
- [ ] Rodar como root diretamente: script aborta com mensagem clara antes de qualquer ação
- [ ] `~/.local/share/lyra-repo/` contém `prosa-*.pkg.tar.zst`, `fina-*.pkg.tar.zst` e `lyra.db.tar.gz`
- [ ] `lyra-iso/pacman.conf` contém a seção `[lyra]` com caminho `file://` correto para o `$HOME` de quem rodou
- [ ] Simular pacote de sistema ausente do repositório (renomear temporariamente um dos nomes na lista do Passo 1): script reporta o pacote exato que falhou e aborta, sem prosseguir
- [ ] Adicionar um pacote fictício à lista `LYRA_AUR_PACKAGES` (ex.: um pacote AUR qualquer de teste) sem alterar mais nada no script: build e cópia funcionam sem edição adicional
- [ ] Rodar `mkarchiso` em seguida (fora do escopo deste script, mas como teste de integração): pacotes `prosa` e `fina` resolvem corretamente via o repositório `[lyra]` local

---

## 7. Fora de Escopo

- Publicação do repositório `lyra` oficial com assinatura GPG (permanece manual/futuro, conforme `PROMPT-LYRA-OS.md` §10.1)
- Build de Calco, Pulso, Lyra Tour, Vega e vegad — entram na lista `LYRA_AUR_PACKAGES` (ou em `packages.x86_64` diretamente, no caso de Vega/vegad se não forem AUR) assim que publicados; nenhuma mudança estrutural no script é necessária
- Execução do `mkarchiso` em si — coberto pelo `build.sh` já especificado
- Assinatura GPG de pacotes individuais no repositório local (aceitável usar `TrustAll` apenas em ambiente de desenvolvimento)

---

**Fim da especificação.**
