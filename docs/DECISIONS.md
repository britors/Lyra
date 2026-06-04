# Lyra OS — registro de decisões

Resolução das pendências do prompt de build (§13) e como cada uma foi
implementada.

## §4 — Btrfs + snapshots — **ADOTADO**

Raiz Btrfs com subvolumes `@`, `@home`, `@log`, `@pkg`, `@snapshots`.
Snapper + snap-pac (snapshot antes de cada transação pacman/Pamac) + grub-btrfs
(entradas de boot para rollback sem terminal).

- Particionamento: `calamares/modules/partition.conf` (`btrfsSubvolumes`).
- Montagem: `mount.conf` / `fstab.conf` (`compress=zstd:1,noatime,ssd`).
- Snapper: `profile/airootfs/etc/snapper/configs/root` + `conf.d/snapper`.
- Serviços habilitados no alvo: `services-systemd.conf`
  (`snapper-timeline.timer`, `snapper-cleanup.timer`, `grub-btrfsd.service`).
- Initramfs: `grub-btrfs-overlayfs` + módulo `btrfs` (`initcpiocfg.conf`).
- Pacotes: `snapper snap-pac grub-btrfs inotify-tools` (`packages.x86_64`).

## §7 — Trocador de kernel — **UTILITÁRIO PRÓPRIO**

`packages/lyra-kernel-manager/` — app gráfico PySide6 (Qt6, nativo do Plasma).
Lista/instala/remove `linux-zen` (padrão), `linux`, `linux-lts`,
`linux-hardened`. **Sempre instala o `*-headers` junto** (necessário para o DKMS
do NVIDIA em linux-zen — §6). Não deixa remover o kernel em uso nem o último
kernel. Privilégios via `pkexec` + política polkit.

## §10 — Wallpapers — **PALETA ALINHADA AO LOGO + NOME "Lyra"**

- Paleta: synthwave → sapphire→violet do logo. Mapa em
  `branding/generate-wallpapers.sh` (`#b44fff→#8b5cf6`, `#ff3fa4→#6e6aff`,
  `#00d4aa→#22b6ff`, `#6ea6ff→#3b82f6`).
- Nome do conjunto: **Lyra** (era OpenBase — que é a CLI .NET da W3TI).
- Reempacotado para layout KDE (`<Nome>/contents/images/<WxH>.png` +
  `metadata.json`); SVGs mantidos como fonte; rasterizado em 1080/1440/2160.
- Tema do Plasma/SDDM/Plymouth derivado do mesmo degradê.

## §9 — Apps — parcialmente resolvido

- `prosa` e `fina` em `aur/packages.list` (confirmar nome exato de `fina`).
- `Calco` e `Pulso`: **pendência externa** — entram quando publicados no AUR.
- Discord: explicitamente **não** incluído.

## §6 — Drivers de GPU (não era pendência, mas registrando a lógica)

`profile/airootfs/usr/local/bin/lyra-gpu-install`, chamado pelo Calamares no
chroot (`shellprocess-gpu.conf`):

| GPU | Driver |
|-----|--------|
| NVIDIA Turing+ (RTX, GTX 16xx) | `nvidia-open-dkms` + utils + lib32 |
| NVIDIA Maxwell/Pascal/Volta (9xx/10xx) | `nvidia-580xx-dkms` (AUR/lyra-local) |
| NVIDIA antiga / detecção falha | `nouveau` |
| AMD / Intel | Mesa aberto (já instalado) |

DKMS obrigatório (linux-zen); headers de **todos** os kernels instalados são
garantidos. Live boota em nouveau por padrão, com entradas de boot
"drivers proprietários" e "modo de segurança" (GRUB e syslinux).
