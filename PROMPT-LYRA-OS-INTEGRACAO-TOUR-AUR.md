# PROMPT DE IMPLEMENTAÇÃO — LYRA OS: INTEGRAÇÃO DO LYRA TOUR (AUR)

> **Versão:** 3.0
> **Status:** Especificação incremental, pronta para implementação
> **Supersede:** a parte referente ao Lyra Tour em `PROMPT-LYRA-OS-INTEGRACAO-TOUR-VEGA-v2.md`. A parte referente a Vega/vegad daquele documento **permanece válida** — eles continuam em build local (ainda não publicados). Este documento separa os dois fluxos porque agora têm canais diferentes.
> **Pré-requisitos:** `PROMPT-LYRA-OS.md` v2.1, `PROMPT-LYRA-TOUR-v2.md`, `PROMPT-LYRA-ISO-SETUP-HOST.md` v1.0
> **Escopo:** O pacote `lyra-tour` está publicado no AUR (`https://aur.archlinux.org/packages/lyra-tour`). Este documento integra o Lyra Tour ao build do ISO **pelo canal real**, saindo do mecanismo de build local usado até agora.

---

## 1. O que Muda

| Item | Antes (build local) | Agora |
|---|---|---|
| Canal do `lyra-tour` | checkout Git + `makepkg` manual | **AUR real**, via `yay -S lyra-tour` |
| Onde builda | `~/dev/lyra-tour` (placeholder) | irrelevante — o `yay` resolve sozinho a partir do AUR |
| Entra em `LYRA_LOCAL_SOURCE_PACKAGES`? | sim | **não** — remover de lá |
| Entra em `LYRA_AUR_PACKAGES`? | não | **sim** — mecanismo já existente desde Prosa/Fina |

Vega e vegad **não são afetados** por este documento — continuam no fluxo de build local (`LYRA_LOCAL_SOURCE_PACKAGES`) até serem publicados no repositório `lyra` oficial.

---

## 2. Alterações no `setup-build-host.sh`

### 2.1 Remover do bloco de build local

```diff
 LYRA_LOCAL_SOURCE_PACKAGES=(
     "vega:$HOME/dev/vega"
     "vegad:$HOME/dev/vegad"
-    "lyra-tour:$HOME/dev/lyra-tour"
 )
```

### 2.2 Adicionar ao bloco de build via AUR

```diff
 LYRA_AUR_PACKAGES=(
     "prosa"
     "fina"
+    "lyra-tour"
 )
```

- Nenhuma outra linha do script muda — o Passo 4 (`yay -S --needed --noconfirm <pacote>`) já trata `lyra-tour` exatamente como trata Prosa e Fina hoje, incluindo a cópia do `.pkg.tar.zst` do cache do `yay` para o repositório local (`~/.local/share/lyra-repo/`)
- **Efeito prático:** rodar o script atualizado builda o Lyra Tour puxando o PKGBUILD direto do AUR — não é mais necessário ter um checkout Git do projeto na máquina de build só para esse pacote

---

## 3. Alterações no Repositório `lyra-iso`

### 3.1 `packages.aur.lock`

Já previsto no documento anterior; confirmar que a versão travada corresponde à publicada no AUR:

```
lyra-tour=2.0.0
```

- Ajustar o número se a versão publicada no AUR for diferente (verificar a tag do `pkgver` no PKGBUILD publicado)

### 3.2 `packages.x86_64` e `lyra-desktop`

Sem mudança em relação ao já especificado — `lyra-tour` continua fora do meta-pacote `lyra-desktop` (é pacote AUR pré-instalado à parte, mesma decisão desde o `PROMPT-LYRA-TOUR-v2.md` §5.2), listado no `packages.aur.lock` do perfil archiso.

### 3.3 `build.sh`

Sem mudança — a validação de presença de `/etc/xdg/autostart/lyra-tour.desktop` no chroot já estava especificada e continua igual, independentemente de o pacote vir de build local ou do AUR real.

---

## 4. Ordem de Execução Recomendada

1. Atualizar `setup-build-host.sh` conforme §2
2. Rodar o script — `lyra-tour` agora vem do AUR real via `yay`; Vega e vegad continuam vindo do build local (`LYRA_LOCAL_SOURCE_PACKAGES`, inalterado)
3. Confirmar no repositório local: `pacman -Sl lyra` deve listar `prosa`, `fina`, `lyra-tour` (via AUR) e `vega`, `vegad` (via build local) — todos no mesmo `lyra.db.tar.gz`, indistinguíveis para o `mkarchiso`
4. Conferir `packages.aur.lock` com a versão correta (§3.1)
5. Rodar `mkarchiso`

---

## 5. Validação

- [ ] `yay -S lyra-tour` instala com sucesso a partir do AUR real (sem apontar para checkout local)
- [ ] `~/.local/share/lyra-repo/` contém `lyra-tour-*.pkg.tar.zst` proveniente do cache do `yay` (`~/.cache/yay/lyra-tour/`)
- [ ] `pacman -Sl lyra` lista os 5 pacotes esperados (`prosa`, `fina`, `lyra-tour`, `vega`, `vegad`)
- [ ] ISO gerado contém `/etc/xdg/autostart/lyra-tour.desktop`
- [ ] VM de teste: primeiro login abre o Tour automaticamente
- [ ] Versão do `lyra-tour` instalada na VM corresponde à travada em `packages.aur.lock`
- [ ] Rodar o script duas vezes seguidas (idempotência): `yay -S --needed` não força rebuild desnecessário de `lyra-tour` já atualizado

---

## 6. Fora de Escopo

- Publicação de Vega/vegad no repositório `lyra` oficial — continuam em build local até lá; quando publicados, aplicar o mesmo padrão deste documento a eles (mover de `LYRA_LOCAL_SOURCE_PACKAGES` para o mecanismo do repositório oficial, não mais para `LYRA_AUR_PACKAGES`, já que o destino final deles é o repo `lyra`, não o AUR)
- Calco e Pulso — entram no mesmo padrão deste documento assim que publicados no AUR

---

**Fim da especificação.**
