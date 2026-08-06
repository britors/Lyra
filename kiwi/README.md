# Lyra OS - KIWI appliance (ISO)

KIWI image description for the Lyra OS "Odisseia" Beta 1 x86_64 live/installer
ISO, built on openSUSE Leap 16. See `/PROMPT-LYRA-OS.md` at the repo root
for the full product spec this implements.

## Scope of this directory (current state)

Current implementation: a KIWI description for an ISO based on Leap 16,
with `kernel-default`, a GNOME live session, the
Btrfs/Snapper + zram-generator packages present; Calamares installed with
Lyra-specific config (`root/etc/calamares/`) covering root-disabled
install, pt-BR default, hostname suggestion, an openSUSE-style Btrfs
subvolume layout, a working live-session launcher, and a Snapper/GRUB
rollback bootstrap (see "Snapper bootstrap" below for the one place this
deliberately isn't a byte-for-byte match of what YaST/Agama do); the Lyra
OBS repos, Vega, Sheliak, Fina, Flatpak/Flathub, and a curated app set (Firefox,
LibreOffice, CUPS+print/scan, a specific hand-picked GNOME app list); and
Lyra-Theme branding (GRUB/Plymouth/GNOME theming, `/etc/os-release`), plus
the local-only, on-demand `lyra-report` diagnostic collector - see
"Repos and package selection", "Branding", and "Untested" below for what
is implemented, externally blocked, or still awaiting end-to-end validation.

### Diagnostics and privacy

`/usr/bin/lyra-report` creates a mode-0600 `.tar.gz` archive only when the
user invokes it; it has no timer, service, network request, or upload path.
It deliberately refuses to run as root and refuses to overwrite an existing
file. The report captures system/package/repository state, Btrfs/Snapper,
Secure Boot/EFI state, desktop versions, and up to 2,000 warning-or-higher
messages from the current boot. Its included README warns that logs and paths
can contain personal data and must be reviewed before sharing. No automatic
telemetry is introduced.

**Deliberately not done here yet** (tracked as separate follow-up work):

- Calamares' installer *UI itself* has its product strings set
  (`root/etc/calamares/branding/lyra/branding.desc`, `branding: lyra` in
  settings.conf - window title/wizard text now say "Lyra OS" instead of
  the generic "Instalador Linux"), but the images/slideshow in that same
  branding.desc still reuse calamares-branding-upstream's "default"
  assets (`squid.png`, `languages.png`, `show.qml`) verbatim - swapping
  those for real Lyra logo/wallpaper assets, as opposed to the
  boot/desktop theming below (which is done), is still pending.

### Live-session Calamares launcher (resolved)

`root/usr/share/applications/calamares.desktop` overrides the RPM-shipped
launcher with the desktop-entry-compliant
`Exec=pkexec /usr/bin/calamares`.
The same command is used by the live-session autostart entry. And
`root/etc/polkit-1/rules.d/00-lyra-live-installer.rules` grants exactly
that action to `liveuser` without a password prompt. The action ID,
`com.github.calamares.calamares.pkexec.run`, is not guessed - it's read
directly from upstream Calamares' own shipped policy file
([`com.github.calamares.calamares.policy`](https://github.com/calamares/calamares/blob/calamares/com.github.calamares.calamares.policy)).

The `00-` prefix is significant: polkit stops at the first rule that returns
a decision. Evaluating Lyra's narrowly-scoped live-session exception before
openSUSE's generic default-privilege rules prevents those rules from returning
an administrator-authentication decision first and asking for the locked root
account's password.

This deliberately diverges from what openSUSE's own `calamares` OBS
package does: their `calamares-desktop-file.patch` (see
`openSUSE:Factory/calamares` on OBS) rewrites the launcher to
`kdesu -c /usr/bin/calamares` instead of pkexec, because pkexec had
`XDG_RUNTIME_DIR`/display problems on Leap 15's live media. That fix
pulls in `kde-cli-tools5` (for `kdesu`) purely for a password dialog, and
`kdesu` needs the live user to actually have a real password to
authenticate with - which conflicts with the locked, autologin
`liveuser` account here. Since upstream Calamares' own pkexec+polkit
mechanism is standard on GNOME (GNOME Shell ships its own polkit agent,
no extra package needed) and openSUSE's workaround was specifically
about Leap 15-era display forwarding, pkexec remains the launcher. An
initial live test exposed the late `90-` rule ordering as a password
prompt; the rule now sorts first as described above. The rebuilt ISO
still needs a VM boot test to confirm this correction. If Leap 16 also
shows the older display-forwarding failure after authorization,
openSUSE's kdesu approach remains the fallback, but that is separate
from the password-prompt issue fixed here.

The live account and its privileges are explicitly removed from the target by
`shellprocess@installcleanup`, after the real user/display-manager setup and
before the first snapshot. It deletes `liveuser`, GDM's live autologin file,
the global installer autostart, the live-only polkit rule, and the installer
desktop entry. It also lowers the three Lyra OBS repositories to priority 90
on the target: priorities 1-3 are needed during image construction to select
the Qt6-enabled Calamares fork, but must not let a personal OBS project broadly
override official Leap packages during later `zypper dup` runs. This cleanup
is required because `unpackfs` copies the complete live squashfs rather than a
separate target root filesystem. The following `packages` job also removes the
Calamares and upstream-branding RPMs from the installed system; they remain
available only in the live environment.

### Snapper bootstrap (resolved, simplified)

`root/etc/calamares/modules/snapshotcfg.conf` (a `shellprocess@snapshotcfg`
instance, see `settings.conf`) runs, chrooted, **after** `grubcfg` and
the native Leap UEFI bootloader step:

Before that job can run, `config.sh` provides the conventional
`/etc/mtab -> ../proc/self/mounts` link. Leap 16's `filesystem` RPM does not
own that link, so the first built image omitted it; Snapper 0.12.1 then failed
in `create-config` while opening `/etc/mtab` to detect `/`'s filesystem type.
The VM build helper now rejects an image whose final root does not contain the
link.

1. The Lyra helper makes `/@` the initial default Btrfs subvolume and removes
   the root entry's explicit `subvol=/@`, so future rollbacks are not
   overridden by `/etc/fstab`.
2. `snapper --no-dbus -c root create-config /` - the same command SUSE's
   own Snapper Tutorial documents for adding Snapper to an already-mounted
   Btrfs root.
3. The helper adds a separate `/.snapshots` fstab mount after Snapper has
   created that subvolume. This keeps the global snapshot tree accessible
   when `/` is booted from a read-only snapshot.
4. `dracut --force --fstab` rebuilds the target initramfs from the final
   fstab. This prevents host-only dracut from preserving the installer-time
   `subvol=/@` mount in its embedded kernel command line.
5. `snapper --no-dbus -c root create --read-only --type single ...` - a
   "first root filesystem" snapshot. `--read-only` is mandatory, not
   cosmetic: `grub2-snapper-plugin.sh` (in the openSUSE `grub2` package)
   explicitly skips writable snapshots when building the boot menu.
6. `grub2-mkconfig -o /boot/grub2/grub.cfg` again, so the just-created
   snapshot actually shows up in the regenerated menu.

`grub2-snapper-plugin` was added to `kiwi/config.xml`'s package list (it
ships `/etc/grub.d/80_suse_btrfs_snapshot`), and `grubcfg.conf` now sets
`SUSE_BTRFS_SNAPSHOT_BOOTING: true`, which that script explicitly checks
- without it the "Start bootloader from a read-only snapshot" submenu
never gets generated at all, regardless of what Snapper is doing.
`snapper-zypp-plugin` is also explicit: the `snapper` RPM only recommends it,
and this image intentionally disables recommended dependencies. Without that
plugin, zypper transactions would not create the required pre/post snapshots.

The two helper operations are idempotent, so a late dracut/GRUB failure can be
retried safely. Only after every fallible setup command succeeds does the job
remove the target copy of `/etc/calamares` and the helper. The first recovery
snapshot can therefore contain these inert configuration files, but not the
Calamares RPM, executable, launcher, autostart entry, or live-user privilege.

The exact commands and ordering here aren't guessed - they come from
openSUSE/snapper's own `client/installation-helper/{readme.txt,test1.sh,
test2.sh}` and the `grub2` package's `80_suse_btrfs_snapshot` /
`grub2-snapper-plugin.sh` scripts (both fetched from
[OBS](https://build.opensuse.org), `openSUSE:Factory/grub2` and
`openSUSE:Factory/snapper`... via `openSUSE/snapper` on GitHub for the
installation-helper part).

**Deliberate simplification vs. YaST/Agama**, and why: YaST doesn't run
`create-config` against an existing root - it makes the *very first*
snapshot **be** the default root subvolume itself, via snapper's own
`/usr/lib/snapper/installation-helper --step filesystem` (see that
readme.txt), so "day 0" already exists as snapshot #1 before anything is
even unpacked. Reproducing that exactly turns out to require replacing
Calamares' partition/mount handling for `/` with a fully custom module
(traced through `mount`'s actual source: its single-pass, plain-mount
design can't express "root is a nested `.snapshots/N/snapshot`, but
`/home` etc. are flat siblings of `.snapshots`" at the same time). The
one-time default-subvolume/fstab conversion above keeps the standard Snapper
rollback mechanism working going forward without claiming byte-for-byte YaST
layout parity. The remaining trade-off: there's no pristine
"as-installed" snapshot to roll back to on a system built from this
config - only the "first root filesystem" snapshot above, and everything
snapshotted after it (zypper transactions, timeline), are available for
rollback via GRUB.

### Repos and package selection

**Leap updates**: Leap 16 has no dedicated update repository; official
maintenance updates are published through `repo-oss`. The configured OSS and
Non-OSS sources therefore cover the specification's official update channel
without the invalid Leap 15-style `/update/leap/16.0/` URLs.

**Lyra OBS repos**: `repo-lyra`, `repo-vega`, `repo-fina` were added to
`config.xml`, pointed at
`download.opensuse.org/repositories/home:/rodrigosbrito:/{lyra,vega,fina}/openSUSE_Leap_16.0/`.
This isn't assumed from the spec text - verified live against the real
OBS instance on 2026-08-05: all three projects exist, all three have an
`openSUSE_Leap_16.0` build target, all three repos actually publish
repodata at that URL (HTTP 200), and the packages this config installs
from them (`vega-gtk`, `sheliak`, and `fina`) show successful builds in
OBS's own build-status API.

`sheliak` installs the system GNOME Shell extension, and
`root/usr/share/glib-2.0/schemas/99-lyra-sheliak.gschema.override` enables it
by default for the live session and newly-created users. `config.sh` recompiles
the system schema cache after the KIWI overlay is applied. Because this is a
GSettings default rather than a mandatory dconf lock, users can still disable
the dock. `fina` is installed from its dedicated `repo-fina` source.

Repository metadata and package-signature checks are explicitly enabled on
all official and OBS sources. KIWI otherwise writes `repo_gpgcheck=0` and
`pkg_gpgcheck=0` into each image-included zypper repository even when the
global build preference checks RPM signatures, which would weaken the
installed system's update path.

**Every package name in `config.xml` was checked against the real Leap
16.0 repodata** (`download.opensuse.org/distribution/leap/16.0/repo/{oss,non-oss}/`),
not just assumed from familiarity with older openSUSE versions - this
caught three real naming issues that would otherwise have silently
broken the build:
- `firefox`/`MozillaFirefox` - the package is `MozillaFirefox` (also
  confirmed in `patterns-gnome.spec`'s own `Recommends:`).
- `cheese` - doesn't exist in Leap 16 at all; GNOME's camera app was
  renamed/rewritten upstream to `snapshot`, which is what's actually
  packaged now.
- `gnome-papers` - not packaged for Leap 16 yet; `evince` is the PDF/
  document viewer that's actually there.

**`patternType="onlyRequired"`** is set on `<packages type="image">`,
made explicit rather than relying on KIWI's default. The alternative
(`plusRecommended`) would have pulled in everything `gnome_basic`/`gnome`
*recommend* - checked against the real `patterns-gnome.spec` from OBS,
that list includes `evolution`, `pidgin`, `planner`, `remmina`,
`gnome-initial-setup`, and `opensuse-welcome-launcher`, none of which
belong on a curated distro that explicitly rules out onboarding wizards.
Instead, everything actually wanted (Settings, Text Editor, the
snapshot/camera app, Calculator, a specific hand-picked rest-of-list) is
added back as individual `<package>` entries - see the comments in
`config.xml` for the full reasoning, including why `gnome-terminal` and
`gnome-console` are both explicit (Terminal remains the default and Console
is available as an alternative) and why `gnome-software` needed adding
explicitly too (it's only reachable via the separate
`sw_management_gnome` pattern, not `gnome_basic`/`gnome` at all - would
have been silently missing even under `plusRecommended`).

The same audit made hardware and desktop plumbing explicit:
`kernel-firmware-all` plus AMD/Intel microcode (the kernel merely recommends
firmware), `gvfs` with its backends/FUSE bridge and `udisks2` (otherwise
Nautilus loses trash, removable media, phones, and network locations), and
`xdg-desktop-portal-gnome` for Flatpak file pickers and desktop portals.

**Multimedia codecs are blocked, not skipped.** The spec says these
should be "empacotados e distribuídos pelo próprio OBS do Lyra", but
`home:rodrigosbrito:lyra` only has `lyra-theme` (plus other Lyra-app
packages unrelated to codecs) right now - there's no codecs package to
point at yet. Nothing was substituted in its place (no Packman, per the
spec). This is upstream-blocked, not a decision made here.

**Flatpak**: the `flatpak` package is installed, and the Flathub remote
is registered in `config.sh` at image-build time (not as a Calamares
step) - see the comment there for why that also covers every installed
system, and the network-access requirement it implies for the KIWI
build itself.

### Branding (Lyra-Theme)

`lyra-enterprise-theme` and `lyra-enterprise-icons` are installed from the
already-configured `lyra` OBS repo. Everything here is grounded in the
real [britors/Lyra-Theme](https://github.com/britors/Lyra-Theme) repo -
its `packaging/opensuse/*.spec` files and `install-rpm.sh` - not assumed
from the product spec's prose description:

- **GRUB theming is enabled; Plymouth stays out of the live initrd.**
  `lyra-enterprise-theme`'s own RPM `%post` scriptlet sets `GRUB_THEME` in
  `/etc/default/grub`, runs `grub2-mkconfig`, and runs
  `plymouth-set-default-theme -R Lyra-Enterprise` automatically on
  install. However, explicitly adding Leap's `plymouth-dracut` to this
  non-host-only live image makes dracut pull its `drm` dependency, all generic
  GPU modules and their firmware into the initrd. The resulting 138 MiB
  archive made GRUB spend a long time at `Loading initial ramdisk` and hid
  useful diagnostics behind `quiet splash`. The live ISO therefore keeps the
  Lyra GRUB theme but deliberately omits `plymouth-dracut` and the splash
  kernel arguments. On the installed system Calamares keeps `gfxterm` output;
  using `console` there disables `GRUB_THEME`.
- **Dark/light "both installed, one default" is handled by the package
  itself**, not by anything in this repo: it ships a compiled-in
  `/usr/share/glib-2.0/schemas/99-lyra-enterprise.gschema.override`
  setting `icon-theme`, `accent-color`, `color-scheme=prefer-dark`, and
  both `picture-uri`/`picture-uri-dark` wallpaper paths as the system-wide
  GNOME defaults. Dark being the default is the package's own hardcoded
  choice, accepted here rather than overridden - the spec doesn't pick
  one for v1, and the dark palette is the one it describes in more detail.
- **GDM stays untouched**, consistent with the spec: the gschema override
  only covers `org.gnome.desktop.interface`/`background` (regular user
  sessions), not `org.gnome.login-screen`.
- **Fastfetch** is installed explicitly (it's only a `Recommends` in the
  theme's spec file); its config is dropped into every new user's
  `~/.config` automatically via the package's own `/etc/skel/` files - no
  work needed here for that either. **Neofetch was left out** on purpose:
  it's Suggests-only upstream and an archived/unmaintained project;
  Fastfetch is what the theme's own README leads with.
- **A real bug this work caught**: `grubcfg.conf`'s `defaults:` block
  (added earlier for `SUSE_BTRFS_SNAPSHOT_BOOTING`) was silently
  never being applied - traced through Calamares' actual `grubcfg`
  `main.py` and confirmed `defaults:` only gets used when the target
  `/etc/default/grub` doesn't exist yet, or `overwrite`/
  `always_use_defaults` is set. Leap always ships that file already, so
  with `overwrite: false` (correct - don't blow away `GRUB_THEME`) and
  the module's own default `always_use_defaults: false`, nothing in
  `defaults:` was ever getting written. Fixed by setting
  `always_use_defaults: true`; confirmed (from the same source) that the
  actual file write in that path is a safe line-level in-place edit, not
  a full rewrite, so it won't clobber `GRUB_THEME`.
- **`/etc/os-release`** is overwritten in `config.sh` to report
  `NAME="Lyra OS"` / `PRETTY_NAME="Lyra OS Beta 1 (Odisseia)"` /
  `ID=lyra-os`, keeping `ID_LIKE="opensuse suse"` so tooling that branches
  on family detection still works. `HOME_URL`, `BUG_REPORT_URL`, and
  `LOGO` were deliberately left out rather than filled with guesses -
  there's no confirmed project website/tracker URL, and no icon name
  confirmed to exist under `lyra-enterprise-icons` for `LOGO` to point at.
- **Calamares' own installer UI branding** (product name/logo in the
  wizard itself, as opposed to the desktop/boot theming above): product
  strings are done (`branding: lyra`), images/slideshow still aren't -
  see the "not done yet" note above.
- GNOME 48+ is required by the theme; confirmed Leap 16.0 actually ships
  GNOME 48.3, so this isn't a live concern.

### Validation status

The image has been built with `kiwi-ng` and booted in a VM. Those runs exposed
and guided fixes for the oversized live initrd, the Calamares polkit prompt,
the missing `/etc/mtab` link needed by Snapper, and other installation-path
issues described above. The VM helper also performs static checks against the
generated ISO before replacing the previously known artifact.

A clean end-to-end run after the latest fixes is still pending: rebuild the
ISO, boot the live session, complete a Calamares installation, boot the target
disk, and confirm the Snapper recovery entry. Repeat that path with Secure Boot
enabled before treating the image as release-ready. Package/module choices are
also grounded in the current Calamares, KIWI, Snapper, GRUB, OBS, and Leap 16
sources, but source-level verification is not a substitute for that final
integration test.

## Notable choices

- **Live ISO, not OEM/unattended installer**: `image="iso"` with
  `flags="overlay"` (the `dracut-kiwi-live` module) produces a bootable
  live squashfs, matching how Calamares-based distros work - Calamares
  runs from inside the live session and partitions the target disk
  itself. The live squashfs root itself isn't Btrfs; the Btrfs+Snapper
  subvolume layout in `root/etc/calamares/modules/mount.conf` only
  applies to the *installed* system.
- **`liveuser` with GDM autologin** (`config.sh`): makes the live ISO
  boot to a usable desktop. `shellprocess@installcleanup` removes that user
  and every live-only launcher/privilege from the target before the first
  installed-system snapshot; the installed account model is the separate
  root-disabled sudo user created by Calamares.
- **Native Leap UEFI bootloader**: the generic Calamares bootloader job
  is disabled. `shellprocess@uefibootloader` runs `grub2-mkconfig` and
  Leap's `/usr/sbin/shim-install`, so the signed shim, GRUB EFI image,
  fallback loader and NVRAM entry are installed by the distribution's
  own supported path.
- **Btrfs subvolume layout**: `mount.conf`'s `btrfsSubvolumes` list
  mirrors the fallback list openSUSE's own installer (yast2-storage-ng)
  uses, rather than Calamares' generic `@`/`@home` example, so an
  installed system's layout matches what a Leap user would expect from
  `/etc/fstab`.
- **zram**: `zram-generator` package + `root/etc/systemd/zram-generator.conf`
  shipped verbatim into the image (`zram0`, size = min(ram/2, 8GiB),
  zstd). No swapfile anywhere.
- **Secure Boot**: `firmware="uefi"` + `shim`/`mokutil` packages and
  `shellprocess@uefibootloader`, relying on Leap's signed shim and native
  `shim-install` implementation (nothing custom-signed by Lyra).

## Building

Requires `kiwi-ng` (the `kiwi` package on Leap 16) on the build host.

```sh
sudo kiwi-ng system build \
  --description kiwi \
  --target-dir /tmp/lyra-os-build
```

If `kiwi-ng` rejects the description with a schema version error, check
the installed tool's supported schema (`kiwi-ng --version`) and adjust
the `schemaversion` attribute in `config.xml` (currently `8.3`) to match.

For a clean end-to-end installation test with Secure Boot enabled, run
the helper as the regular desktop user (not with `sudo`):

```sh
./kiwi/test/build-and-run-vm.sh --fresh-disk --secure-boot
```

After completing the installation, boot the installed disk without the
ISO while preserving the same Secure Boot NVRAM:

```sh
./kiwi/test/build-and-run-vm.sh --boot-disk --secure-boot
```
