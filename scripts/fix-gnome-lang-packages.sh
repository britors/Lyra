#!/usr/bin/env bash
# One-off remediation for machines installed before kiwi/config.xml started
# listing GNOME/desktop "-lang" packages explicitly. The image build uses
# patternType="onlyRequired", which drops these translation subpackages
# since they're only ever a Recommends, not a Requires - so a pt_BR install
# ends up with LANG=pt_BR.UTF-8 but most GNOME apps and gnome-shell itself
# still in English. New ISOs already include them; this just patches an
# already-installed system.

set -Eeuo pipefail

readonly PACKAGES=(
    accountsservice-lang appstream-glib-lang AppStream-lang at-spi2-core-lang
    baobab-lang evince-lang firewalld-lang fontconfig-lang gdm-lang
    glib-networking-lang gnome-calculator-lang gnome-characters-lang
    gnome-console-lang gnome-control-center-lang gnome-disk-utility-lang
    gnome-keyring-lang gnome-logs-lang gnome-session-lang
    gnome-settings-daemon-lang gnome-shell-lang
    gnome-system-monitor-lang gnome-terminal-lang gnome-text-editor-lang
    gnome-tweaks-lang gnome-user-share-lang gsettings-desktop-schemas-lang
    gvfs-lang loupe-lang malcontent-lang mutter-lang nautilus-lang
    NetworkManager-lang orca-lang PackageKit-lang pipewire-lang plymouth-lang
    seahorse-lang shared-mime-info-lang simple-scan-lang snapshot-lang
    system-config-printer-common-lang tecla-keyboard-layout-viewer-lang
    udisks2-lang xdg-desktop-portal-gnome-lang xdg-desktop-portal-lang
    xdg-user-dirs-gtk-lang xdg-user-dirs-lang xkeyboard-config-lang
)

sudo zypper install "${PACKAGES[@]}"

echo
echo "Pronto. Faça logout/login (ou reinicie) para a sessão GNOME recarregar as traduções."
