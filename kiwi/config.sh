#!/bin/bash
#
# Lyra OS - Odisseia (v1)
# KIWI config.sh: runs chrooted into the image after packages are installed.

set -euo pipefail

test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configuring image: [$kiwi_iname]..."

RELEASE_METADATA=/usr/lib/lyra-os/release
if [ ! -r "$RELEASE_METADATA" ]; then
    echo "Missing generated release metadata: $RELEASE_METADATA" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$RELEASE_METADATA"

if [ "$kiwi_iversion" != "$LYRA_VERSION_ID" ]; then
    echo "KIWI version $kiwi_iversion does not match $LYRA_VERSION_ID" >&2
    exit 1
fi

# Leap's filesystem package does not own /etc/mtab, and a KIWI-built root can
# therefore leave the path absent.  Snapper still opens /etc/mtab while
# detecting the filesystem for `create-config`; point it at the kernel's live
# mount table, as on a normally installed system.  The relative target keeps
# the link valid both in the live image and in Calamares' target chroot.
ln -sfn ../proc/self/mounts /etc/mtab

# Networking / firewall - Leap defaults, enabled explicitly for the live boot
suseInsertService NetworkManager
suseInsertService firewalld

# Display manager
baseUpdateSysConfig /etc/sysconfig/displaymanager DISPLAYMANAGER gdm
suseInsertService gdm

# Live-session autologin as liveuser. This is a live-boot convenience
# only; the installed system's login/account model is set up by
# Calamares (root disabled, sudo user), not here.
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=liveuser
EOF

# zram-generator activates its own systemd generator at boot from
# /etc/systemd/zram-generator.conf - no service to enable here.

# Flathub as the third-party app channel (PROMPT-LYRA-OS.md). Registered
# here, at image-build time, rather than as a Calamares install step:
# unpackfs later rsyncs this whole live root - including whatever ends
# up under /etc/flatpak and /var/lib/flatpak - onto the installed
# system, so this one remote-add covers both the live session and every
# installed system built from this image. Needs network access during
# the KIWI build (fetches flathub.flatpakrepo) - see kiwi/README.md.
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Compile the image-owned GNOME defaults after KIWI has overlaid root/.
# This activates the system-installed Sheliak extension for the live account
# and for users subsequently created by Calamares, while still allowing each
# user to disable it normally.
glib-compile-schemas /usr/share/glib-2.0/schemas

# Product identity (PROMPT-LYRA-OS.md: "Lyra OS", not "Lyra Linux" or
# "Lyra Enterprise Linux" - those are historical/discontinued names).
# ID_LIKE keeps openSUSE/SUSE tooling that branches on it (package
# managers, some installers) working correctly; everything user-visible
# says Lyra OS. Overwrites whatever openSUSE-release just installed.
#
# Deliberately no HOME_URL/BUG_REPORT_URL/LOGO here: there's no
# confirmed project website, issue tracker, or a matching icon name
# shipped by lyra-enterprise-icons to point them at - adding guessed
# URLs/icon names felt worse than leaving these optional fields out.
cat > /etc/os-release <<EOF
NAME="Lyra OS"
PRETTY_NAME="$LYRA_PRETTY_NAME"
ID=lyra-os
ID_LIKE="opensuse suse"
VERSION="$LYRA_VERSION_NAME"
VERSION_ID="$LYRA_VERSION_ID"
VERSION_CODENAME="$LYRA_CODENAME_ID"
BUILD_ID="$LYRA_VERSION_ID"
IMAGE_ID="$LYRA_IMAGE_NAME"
IMAGE_VERSION="$LYRA_VERSION_ID"
CPE_NAME="cpe:/o:rodrigosbrito:lyra_os:$LYRA_VERSION_ID"
EOF

exit 0
