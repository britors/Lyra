# Lyra OS

**Simples. Poderoso. Seu.** — uma distribuição Linux baseada em Arch, com KDE
Plasma 6 enxuto, voltada ao usuário final que quer "ligou, funcionou".
Mantida pela **W3TI**.

Este repositório contém os perfis `archiso`, os pacotes curados e a configuração
do instalador necessários para gerar a ISO da Lyra OS.

## Como gerar a ISO

Pré-requisitos (host **Arch Linux**):

```fish
sudo pacman -S archiso base-devel git imagemagick librsvg
```

Pipeline completo:

```fish
# Etapas 1–4 como usuário normal (gera assets, pacotes AUR e monta o perfil):
./build.sh

# Etapa final (mkarchiso precisa de root e baixa vários GB):
sudo ./build.sh iso
```

A ISO sai em `out/iso/lyra-AAAA.MM.DD-x86_64.iso`.

Cada etapa pode ser executada isolada: `./build.sh assets|aur|assemble`,
`sudo ./build.sh iso`.

> **Importante:** `mkarchiso` **exige root** e baixa pacotes da rede; rode num
> host Arch com `archiso` instalado. As etapas 1–4 não precisam de root (o
> `makepkg`, inclusive, recusa rodar como root).

## Estrutura

| Caminho | Conteúdo |
|---------|----------|
| `build.sh` | Orquestrador (preflight → assets → aur → assemble → iso) |
| `profile/` | Perfil `archiso` (profiledef, packages, pacman.conf, airootfs, boot menus) |
| `profile/airootfs/` | Sistema de arquivos da imagem live/instalada (configs, serviços, scripts) |
| `aur/` | Lista curada de pacotes AUR + `build-aur.sh` (gera o repo `lyra-local`) |
| `packages/lyra-kernel-manager/` | Trocador de kernel gráfico próprio (§7) |
| `branding/` | Wallpapers, Plymouth, tema SDDM, defaults do Plasma + metapacote `lyra-branding` |
| `calamares/` | Configuração do instalador Calamares (Btrfs, GRUB, módulo de GPU) |
| `docs/` | Decisões e notas de build |
| `out/` | Saída do build (gerado; ignorado pelo git) |

## Decisões de build

As pendências do prompt original (§13) foram resolvidas — ver
[`docs/DECISIONS.md`](docs/DECISIONS.md).

## Pendências externas

- **Calco** (planilhas) e **Pulso** (apresentações): aguardando publicação no
  AUR para entrar em `aur/packages.list` e `profile/packages.x86_64` (§9).
- **Logo real:** `branding/generate-brand-assets.sh` gera um placeholder. Coloque
  o SVG oficial em `branding/assets/logo.svg` e rode de novo para a arte final.
- **`fina`:** confirmar o nome exato do pacote no AUR (§9).
