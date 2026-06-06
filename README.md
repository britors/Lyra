<p align="center">
  <img src="branding/assets/logo.svg" alt="Lyra OS" width="150">
</p>

<h1 align="center">Lyra OS</h1>

<p align="center"><strong>Simples. Poderoso. Seu.</strong></p>

<p align="center">
  Distribuição Linux baseada em Arch, com KDE Plasma 6 enxuto, voltada ao usuário
  final que quer "ligou, funcionou". Mantida por <strong>Rodrigo Brito</strong>.
</p>

---

Este repositório contém os perfis `archiso`, os pacotes curados e a configuração
do instalador necessários para gerar a ISO da Lyra OS.

## Como gerar a ISO

Host **Arch Linux** com internet. Caminho mais simples — um comando faz tudo:

```fish
./create_iso.sh
```

Ele instala as dependências, gera a arte/wallpapers, compila os pacotes AUR num
chroot limpo, monta o perfil e roda o `mkarchiso`. Pede a senha de `sudo` só nas
etapas que precisam de root. É **re-executável**: pula pacotes AUR já compilados
e limpa a work dir sozinho. A ISO sai em `out/iso/lyra-AAAA.MM.DD-x86_64.iso`.

Para forçar a recompilação de todos os pacotes AUR/locais: `REBUILD=1 ./create_iso.sh`.

### Por etapas (debug / iteração)

```fish
sudo pacman -S --needed archiso base-devel devtools grub mtools git imagemagick librsvg
./build.sh assets       # arte + wallpapers (paleta safira->violeta)
./build.sh aur          # compila o AUR -> repo local out/lyra-local
./build.sh assemble     # monta o perfil archiso de trabalho
sudo ./build.sh iso     # mkarchiso (root; baixa vários GB) -> out/iso/
```

> **Notas:**
> - `devtools` fornece o `makechrootpkg`: os pacotes AUR são compilados num
>   **chroot limpo**, então o build **não altera o seu `/etc/pacman.conf`** nem
>   instala o driver NVIDIA 580xx no host.
> - `grub` + `mtools` são usados pelo `mkarchiso` no host para montar o boot UEFI.
> - `mkarchiso` **exige root**; as demais etapas não (o `makepkg` recusa root).

## Estrutura

| Caminho | Conteúdo |
|---------|----------|
| `create_iso.sh` | Sequência completa, do zero à ISO (one-shot, re-executável) |
| `build.sh` | Orquestrador por etapas (preflight → assets → aur → assemble → iso) |
| `profile/` | Perfil `archiso` (profiledef, packages, pacman.conf, boot menus) |
| `profile/airootfs/` | Sistema de arquivos da imagem live/instalada (configs, serviços, scripts) |
| `aur/` | Lista curada de pacotes AUR + `build-aur.sh` (gera o repo `lyra-local`) |
| `packages/lyra-kernel-manager/` | Trocador de kernel gráfico próprio (§7) |
| `branding/` | Logo, wallpapers, Plymouth, tema SDDM, defaults do Plasma + metapacote `lyra-branding` |
| `calamares/` | Configuração do instalador Calamares (Btrfs, GRUB, módulo de GPU) |
| `docs/` | [Registro de decisões](docs/DECISIONS.md) e notas de build |
| `out/` | Saída do build (gerado; ignorado pelo git) |

## Destaques técnicos

- **Base Arch + KDE Plasma 6** enxuto (sem o grupo `kde-applications` completo).
- **Btrfs + Snapper + grub-btrfs** (§4): snapshot antes de cada update e
  recuperação "voltar no tempo" pelo menu de boot, sem terminal.
- **Drivers de GPU automáticos** (§6): o módulo do Calamares instala o driver
  NVIDIA certo pela arquitetura detectada (open / 580xx legado / nouveau).
- **Pronto para jogos** (§8): Steam, Proton, multilib, tuning de `vm.max_map_count`/`nofile`.
- **Flatpak/Flathub** e **Pamac** configurados por padrão (§5).
- **Trocador de kernel** gráfico próprio (§7) que sempre instala os `*-headers`.

## Decisões de build

As pendências do prompt original (§13) foram resolvidas — ver
[`docs/DECISIONS.md`](docs/DECISIONS.md) (inclui a escolha de bootloader: GRUB
mantido por causa do `grub-btrfs`; systemd-boot avaliado e descartado).

## Pendências externas

- **Calco** (planilhas) e **Pulso** (apresentações): aguardando publicação no
  AUR para entrar em `aur/packages.list` e `profile/packages.x86_64` (§9).
- **`fina`:** confirmar o nome exato do pacote no AUR (§9).
- **Logo:** `branding/assets/logo.svg` é a fonte oficial; ajuste-o e rode
  `./build.sh assets` para rasterizar a arte derivada.

## Contribuindo

Veja [`CONTRIBUTING.md`](CONTRIBUTING.md) — como adicionar pacotes curados,
padrões de código e fluxo de PR.

## Licença

GPL-3.0. Lyra OS crido por  **Rodrigo Brito**.
