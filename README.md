# Lyra OS

**Harmonia. Performance. Liberdade.**

Lyra OS é uma distribuição Linux baseada em Arch Linux, com ambiente
gráfico GNOME vanilla e identidade visual própria (tema, ícones,
wallpapers, mascote e branding de boot/instalador). O pipeline de build
(`lyra-iso/`) está validado de ponta a ponta: gera o ISO, boota em
QEMU/hardware real e instala via Calamares com a marca Lyra aplicada.

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
                              Windows
├── PKGBUILD
├── settings.conf    Sequência do instalador com os módulos abaixo
├── winmigrate-mapping.conf  Mapeamento origem (Windows) → destino
├── winmigrate-detect/   job python — detecção e montagem NTFS
├── winmigrate/          main.qml da tela de seleção (hospedado pelo notesqml)
├── winmigrate-copy/     job python — cópia via rsync + favoritos
└── tests/           detection.test.py, copy_job.test.py
```

## Pré-requisitos

- Arch Linux (ou derivada), com acesso a `sudo`
- Os arquivos de assets já presentes em `lyra-iso/assets/`:
  - `wallpaper/default.png` (obrigatório) e demais wallpapers
  - `Lyra-Dark.tar.xz`
  - `Lyra-Icons-v2.tar.xz`

Tudo o mais (`archiso`, `yay`, dependências de build, o repositório
local `[lyra]` com os pacotes AUR/monorepo do ecossistema) é resolvido
pelo próprio fluxo abaixo — não precisa instalar nada manualmente antes.

## Build rápido (recomendado para quem está começando)

```bash
cd lyra-iso
./scripts/quickstart.sh
```

Um único comando que faz tudo: prepara o host de build, gera o ISO e
sobe a VM QEMU para você validar o resultado. Não rode como root — ele
usa `sudo` internamente só onde precisa (instalação de pacotes de
sistema e o `mkarchiso`). Para só gerar o ISO sem abrir o QEMU:

```bash
./scripts/quickstart.sh --no-qemu
```

Login da sessão live no QEMU: usuário `lyra`, senha `lyra` (autologin
habilitado).

## Passo a passo manual

Útil se você já tem o host preparado e quer rodar só uma etapa, ou
está depurando uma delas isoladamente.

### 1. Preparar o host de build (uma vez por máquina)

```bash
cd lyra-iso
./scripts/setup-build-host.sh
```

Instala as dependências de sistema (`archiso`, `git`, `base-devel` etc.),
instala o `yay` se necessário, builda os pacotes AUR e locais do
ecossistema Lyra (`prosa`, `fina`, `calamares`, `lyra-tour`,
`linuxtoys-bin`, `lyra-branding`, `calamares-lyra-winmigrate`) e monta o
repositório local `[lyra]` em `~/.local/share/lyra-repo`, referenciado
em `pacman.conf`. Idempotente — pode rodar de novo a qualquer momento
para atualizar os pacotes locais.

### 2. Gerar o ISO

```bash
sudo ./build.sh
```

O script:

1. Copia os wallpapers de `assets/wallpaper/` para o rootfs live
2. Extrai o tema `Lyra-Dark` e o tema de ícones `Lyra-Icons-v2`
3. Gera o `gnome-background-properties/lyra.xml` a partir dos wallpapers presentes
4. Limpa qualquer `work/` de um build anterior (garante que o build sempre
   reflita o profile atual — um `work/` reaproveitado pode esconder mudanças
   em `airootfs/`)
5. Executa `mkarchiso`, que por sua vez aplica `airootfs/root/customize_airootfs.sh`
   (cópia do kernel, geração do initramfs, atualização de cache de ícones,
   `dconf update` e habilitação dos serviços systemd)
6. Gera o checksum SHA-256 do ISO resultante

O ISO final e o arquivo `SHA256SUMS` ficam em `lyra-iso/out/`.

### 3. Testar a ISO em uma VM

```bash
./scripts/run-qemu.sh
```

Sobe a ISO mais recente de `out/` numa VM QEMU (usa aceleração KVM
automaticamente se disponível), com um disco alvo de teste para quem
quiser rodar a instalação completa via Calamares. Login da sessão live:
usuário `lyra`, senha `lyra` (autologin habilitado).

## Validação pós-build

Pontos principais a checar depois de um build (boot em QEMU via
`./scripts/run-qemu.sh` ou em hardware real):

- Boot do live USB abre o GDM com o wallpaper padrão e autologin `lyra`/`lyra`
- Tema `Lyra-Dark` e ícones `Lyra-Icons-v2` aplicados
- `fastfetch` abre sozinho em terminal novo com o ASCII art da marca
- Calamares abre em português com a marca Lyra e instala até o fim
- `os-release` reporta `ID=lyra`

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

Instala os jobs Calamares `winmigrate-detect` e `winmigrate-copy` em
`/usr/lib/calamares/modules/` (onde o Calamares realmente procura
módulos completos — `/usr/share/calamares/modules/` é só para `.conf`
de configuração). A tela de seleção (`winmigrate`) **não** é um módulo
próprio — o Calamares não tem interface `qml` para módulos `view` (toda
tela exige um plugin C++ compilado), então ela reaproveita o módulo
genérico `notesqml` do próprio pacote `calamares` como host do QML,
configurado como instância `notesqml@winmigrate` em `settings.conf`. O
`main.qml` vai para a pasta de branding do Calamares
(`/usr/share/calamares/branding/lyra/winmigrate.qml`), por isso o
pacote depende de `lyra-branding`. Mapeamento origem→destino em
`/etc/calamares/modules/winmigrate-mapping.conf`. `makepkg` roda os
testes em `tests/` durante o `check()`. O pacote está listado em
`lyra-iso/packages.x86_64`, então um build normal do ISO já o inclui.

## Escopo

Este repositório cobre a geração do ISO. `Lyrae` (painel de controle,
também conhecido como Vega no ecossistema) e `lyraed` (daemon
privilegiado) já estão desenvolvidos em outro lugar, mas ainda não
publicados como pacote resolvível pelo pacman — por isso não aparecem
em `packages.x86_64` nem em `setup-build-host.sh` ainda.

A arte vetorial do logo e do mascote Lyro em `branding/` é uma
primeira versão funcional (gerada proceduralmente), não uma peça
final aprovada por um designer — serve para destravar o build e pode
ser substituída sem alterar a estrutura de arquivos esperada pelo
`lyra-branding/PKGBUILD`.
