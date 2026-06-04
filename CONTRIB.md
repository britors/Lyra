<p align="center">
  <img src="branding/assets/logo.svg" alt="Lyra OS" width="90">
</p>

# Contribuindo com a Lyra OS

Obrigado por querer ajudar! Este guia cobre como o repositório é organizado, como
adicionar pacotes e branding, e os padrões de código e de PR.

## Filosofia

Lyra OS esconde a complexidade do Arch atrás de bons padrões, para um usuário
final que **não quer usar o terminal**. Ao propor algo, pergunte-se:

- Isso funciona "de fábrica", sem configuração manual?
- Um usuário leigo consegue se recuperar se der errado (snapshots, §4)?
- O poder continua acessível para quem quiser, mas sem atrapalhar o resto?

Decisões de arquitetura ficam registradas em [`docs/DECISIONS.md`](docs/DECISIONS.md).
Mudanças que contrariem uma decisão registrada devem discutir o trade-off lá.

## Preparando o ambiente

Host **Arch Linux**. Veja o [README](README.md#como-gerar-a-iso) para gerar a ISO.
Para desenvolvimento, prefira rodar por etapas (`./build.sh assets|aur|assemble`,
`sudo ./build.sh iso`) em vez do `create_iso.sh` inteiro.

A etapa `aur` é **incremental**: ela pula pacotes já presentes em
`out/lyra-local/`. Use `REBUILD=1 ./build.sh aur` (ou apague o `.pkg.tar.zst`
específico) quando alterar um pacote local e quiser recompilá-lo.

## Onde mexer

| Quero… | Edite |
|--------|-------|
| Adicionar/remover um app dos repositórios oficiais | `profile/packages.x86_64` |
| Adicionar um pacote do AUR (curado) | `aur/packages.list` |
| Configurar a imagem live/instalada (serviços, sysctl, skel…) | `profile/airootfs/` |
| Mudar o instalador (partição, GPU, bootloader) | `calamares/` |
| Wallpapers, tema, Plymouth, SDDM, logo | `branding/` |
| O trocador de kernel | `packages/lyra-kernel-manager/` |
| Boot da ISO (menus, boot modes) | `profile/grub/`, `profile/syslinux/`, `profile/profiledef.sh` |

### Adicionar um pacote dos repositórios oficiais

Acrescente o nome em `profile/packages.x86_64`, **um por linha**.

> ⚠️ **Sem comentário na mesma linha do pacote.** O `archiso` deixaria o espaço
> em branco grudado no nome e o pacote vira "target not found". Comentários só em
> linhas próprias (começando com `#`).

### Adicionar um pacote do AUR

O AUR é **curado**: só entra o que o mantenedor escolhe. Em `aur/packages.list`:

```
<pkgname>  <url-git-do-aur>  [dep-local-1 dep-local-2 ...]
```

- A ordem importa: dependências antes dos dependentes.
- As colunas de dep-local nomeiam pacotes **construídos antes nesta mesma lista**
  que precisam ser instalados no chroot (via `makechrootpkg -I`) antes deste —
  ou seja, a cadeia de dependência interna do AUR. Deps de repositório oficial
  são resolvidas sozinhas dentro do chroot.
- Tudo é compilado num **chroot limpo** (não toca no host). Se o pacote também
  deve ser instalado na imagem, adicione o nome em `profile/packages.x86_64`
  (ele resolve a partir do repo local `lyra-local`).

### Branding

- `branding/assets/logo.svg` é a fonte oficial do logo. Após editá-lo, rode
  `./build.sh assets` para rasterizar a arte derivada (SDDM, Plymouth, boot).
- Wallpapers: `branding/generate-wallpapers.sh` (recolore + rasteriza o conjunto
  para o layout do KDE). Mantenha os SVGs como fonte.
- O metapacote `lyra-branding` é construído por `aur/build-aur.sh`; rode com
  `REBUILD=1` após mexer nos assets.

## Padrões de código

- **Shell:** `#!/usr/bin/env bash`, `set -euo pipefail`. Passe pelo `shellcheck`
  e por `bash -n` antes de commitar. Caminhos sempre entre aspas.
- **PKGBUILD:** siga as convenções do Arch (campos na ordem usual, `sha256sums`,
  `arch=()` correto). Pacotes DKMS para kernel não precisam de headers em tempo
  de build.
- **Pacotes de kernel/driver:** todo kernel deve vir com seu `*-headers` (§6/§7).
- **Sem segredos** no repositório. Nada de binários grandes — arte é gerada a
  partir de fontes (SVG) pelos scripts.
- **`out/`** é saída de build e é ignorada pelo git; nunca a commite.

## Fluxo de Pull Request

1. Crie um branch a partir do `main` (`feat/…`, `fix/…`, `docs/…`).
2. Faça commits focados. Mensagens no formato `tipo(escopo): resumo`
   (ex.: `feat(aur): adiciona heroic-games-launcher`), corpo explicando o porquê.
3. Garanta que o que você mexeu pelo menos **monta** (`./build.sh assemble`) e,
   idealmente, que a ISO gera. Descreva no PR o que testou.
4. Atualize `docs/DECISIONS.md` se a mudança envolve uma decisão de arquitetura,
   e o `README`/`CONTRIB` se muda o fluxo.
5. Abra o PR contra `main` descrevendo a motivação e o impacto no usuário final.

## Testar a ISO

Depois de gerar `out/iso/lyra-*.iso`, teste em VM antes de gravar em pendrive:

```fish
qemu-system-x86_64 -enable-kvm -m 4096 -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -cdrom out/iso/lyra-*.iso
```

(UEFI via OVMF; tire o `-bios` para testar boot BIOS/syslinux.)

## Reportar problemas

Abra uma issue descrevendo: hardware (GPU em especial), etapa onde falhou, e a
saída relevante do `build.sh`/`mkarchiso`. Para bugs da ISO já gerada, diga se
foi no boot live, no Calamares, ou no sistema instalado.

## Licença

Ao contribuir, você concorda em licenciar sua contribuição sob a **GPL-3.0**, a
mesma licença do projeto.
