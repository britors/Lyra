# Lyra OS

**Harmonia. Performance. Liberdade.**

Lyra OS é uma distribuição Linux baseada em Arch Linux, com ambiente
gráfico GNOME vanilla e identidade visual própria (tema, ícones,
wallpapers, mascote e branding de boot/instalador). A especificação
completa do build está em [`PROMPT-LYRA-OS.md`](PROMPT-LYRA-OS.md) e a
especificação de identidade visual em
[`PROMPT-LYRA-IDENTIDADE.md`](PROMPT-LYRA-IDENTIDADE.md).

## Estrutura do repositório

```
lyra-iso/            Perfil archiso usado para gerar o ISO instalável
├── profiledef.sh    Metadados do perfil (nome, modos de boot, permissões)
├── packages.x86_64  Lista consolidada de pacotes Pacman
├── pacman.conf      Repositórios habilitados, incluindo o repo `lyra`
├── build.sh         Orquestra o build (assets → airootfs → mkarchiso)
├── assets/          Wallpapers e temas fornecidos (entrada do build)
└── airootfs/         Overlay do sistema de arquivos live

branding/             Fonte única de verdade da identidade visual
├── palette.json     Tokens de cor (lyra-sapphire, lyra-violet, ...)
├── logo/            Logo master em SVG (cor, mono, dark) + wordmark + PNGs
├── mascot/          Lyro (mascote): SVG, PNG transparente e avatar circular
└── slogan/          slogan.txt — fonte única do texto do slogan

lyra-branding/        Pacote Pacman que instala a identidade no sistema
├── PKGBUILD         Empacota branding/ + os temas abaixo (§5)
├── grub-theme/      Tema GRUB (theme.txt, fundo, wordmark)
├── plymouth-theme/  Tema Plymouth script-based (logo, pulso, spinner)
├── calamares-branding/  branding.desc + show.qml (slideshow de 6 slides)
└── fastfetch/       config.jsonc + ASCII art da marca Lyra

calamares-lyra-winmigrate/   Módulo Calamares de migração assistida do
                              Windows (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md)
├── PKGBUILD
├── settings.conf    Sequência do instalador com os módulos abaixo
├── winmigrate-mapping.conf  Mapeamento origem (Windows) → destino (§4)
├── winmigrate-detect/   job python — detecção e montagem NTFS (§3)
├── winmigrate/          view qml   — tela de seleção (§6.1)
├── winmigrate-copy/     job python — cópia via rsync + favoritos (§5)
└── tests/           detection.test.py, copy_job.test.py
```

## Pré-requisitos

- Arch Linux (ou derivada) com o pacote `archiso` instalado
- `gtk-update-icon-cache` disponível (pacote `hicolor-icon-theme` ou `gtk-update-icon-cache`)
- Privilégios de root para rodar `mkarchiso`
- Os arquivos de assets já presentes em `lyra-iso/assets/`:
  - `wallpaper/default.png` (obrigatório) e demais wallpapers
  - `Lyra-Dark.tar.xz`
  - `Lyra-Icons-v2.tar.xz`

## Como rodar o build

```bash
cd lyra-iso
sudo ./build.sh
```

O script:

1. Copia os wallpapers de `assets/wallpaper/` para o rootfs live
2. Extrai o tema `Lyra-Dark` e o tema de ícones `Lyra-Icons-v2`
3. Gera o `gnome-background-properties/lyra.xml` a partir dos wallpapers presentes
4. Executa `mkarchiso`, que por sua vez aplica `airootfs/root/customize_airootfs.sh`
   (atualização de cache de ícones, `dconf update` e habilitação dos serviços systemd)
5. Gera o checksum SHA-256 do ISO resultante

O ISO final e o arquivo `SHA256SUMS` ficam em `lyra-iso/out/`.

## Testando a ISO em uma VM

```bash
cd lyra-iso
./scripts/run-qemu.sh
```

Sobe a ISO mais recente de `out/` numa VM QEMU (usa aceleração KVM
automaticamente se disponível), com um disco alvo de teste para quem
quiser rodar a instalação completa via Calamares. Login da sessão live:
usuário `lyra`, senha `lyra` (autologin habilitado).

## Validação pós-build

Ver checklist completo em `PROMPT-LYRA-OS.md` §11.2. Pontos principais:

- Boot do live USB abre o GDM com o wallpaper padrão
- Tema `Lyra-Dark` e ícones `Lyra-Icons-v2` aplicados
- Calamares abre em português com a marca Lyra
- `os-release` reporta `ID=lyra`

Checklist de identidade visual: `PROMPT-LYRA-IDENTIDADE.md` §6 (tema
GRUB, Plymouth, slideshow do Calamares, ASCII art do fastfetch, slogan
idêntico em todos os pontos de contato).

## Empacotando a identidade visual (`lyra-branding`)

```bash
cd lyra-branding
makepkg -si
```

O `PKGBUILD` lê os assets de `branding/` (logo, mascote, paleta,
slogan) e instala tema GRUB, tema Plymouth, branding do Calamares e a
configuração do fastfetch. Não gera arte — os SVGs/PNGs já vêm prontos
no repositório. O pacote `lyra-branding` está listado em
`lyra-iso/packages.x86_64`, então um build normal do ISO já o inclui
sem passos manuais adicionais.

## Migração assistida do Windows (`calamares-lyra-winmigrate`)

```bash
cd calamares-lyra-winmigrate
makepkg -si
```

Instala os módulos Calamares `winmigrate-detect`, `winmigrate` e
`winmigrate-copy` em `/usr/share/calamares/modules/`, o mapeamento
origem→destino em `/etc/calamares/modules/winmigrate-mapping.conf` e o
`settings.conf` que os posiciona na sequência do instalador (ver
`PROMPT-CALAMARES-MIGRACAO-WINDOWS.md` §2). `makepkg` roda os testes em
`tests/` durante o `check()`. O pacote está listado em
`lyra-iso/packages.x86_64`, então um build normal do ISO já o inclui.

## Escopo

Este repositório cobre a geração do ISO. Os componentes `Lyrae`
(painel de controle) e `lyraed` (daemon privilegiado) têm specs de
build separadas e são consumidos aqui apenas como pacotes Pacman do
repositório do projeto (ver `PROMPT-LYRA-OS.md` §9).

A arte vetorial do logo e do mascote Lyro em `branding/` é uma
primeira versão funcional (gerada proceduralmente), não uma peça
final aprovada por um designer — serve para destravar o build e pode
ser substituída sem alterar a estrutura de arquivos esperada pelo
`lyra-branding/PKGBUILD`.
