# Lyra OS

**Harmonia. Performance. Liberdade.**

Lyra OS é uma distribuição Linux baseada em Arch Linux, com ambiente
gráfico GNOME vanilla e identidade visual própria (tema, ícones e
wallpapers). A especificação completa do build está em
[`PROMPT-LYRA-OS.md`](PROMPT-LYRA-OS.md).

## Estrutura do repositório

```
lyra-iso/            Perfil archiso usado para gerar o ISO instalável
├── profiledef.sh    Metadados do perfil (nome, modos de boot, permissões)
├── packages.x86_64  Lista consolidada de pacotes Pacman
├── pacman.conf      Repositórios habilitados, incluindo o repo `lyra`
├── build.sh         Orquestra o build (assets → airootfs → mkarchiso)
├── assets/          Wallpapers e temas fornecidos (entrada do build)
└── airootfs/         Overlay do sistema de arquivos live
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

## Validação pós-build

Ver checklist completo em `PROMPT-LYRA-OS.md` §11.2. Pontos principais:

- Boot do live USB abre o GDM com o wallpaper padrão
- Tema `Lyra-Dark` e ícones `Lyra-Icons-v2` aplicados
- Calamares abre em português com a marca Lyra
- `os-release` reporta `ID=lyra`

## Escopo

Este repositório cobre a geração do ISO. Os componentes `Lyrae`
(painel de controle) e `lyraed` (daemon privilegiado) têm specs de
build separadas e são consumidos aqui apenas como pacotes Pacman do
repositório do projeto (ver `PROMPT-LYRA-OS.md` §9).
