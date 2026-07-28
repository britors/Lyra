# Lyra OS - KIWI appliance (ISO)

KIWI image description for the Lyra OS "Odisseia" (v1) x86_64 live/installer
ISO, built on openSUSE Leap 16. See `/PROMPT-LYRA-OS.md` at the repo root
for the full product spec this implements.

## Scope of this directory (current state)

Implements all four checklist items so far: an ISO that builds via KIWI,
on top of Leap 16, with `kernel-default`, a GNOME live session, the
Btrfs/Snapper + zram-generator packages present; Calamares installed with
Lyra-specific config (`root/etc/calamares/`) covering root-disabled
install, pt-BR default, hostname suggestion, an openSUSE-style Btrfs
subvolume layout, a working live-session launcher, and a Snapper/GRUB
rollback bootstrap (see "Snapper bootstrap" below for the one place this
deliberately isn't a byte-for-byte match of what YaST/Agama do); the Lyra
OBS repos, Vega, Flatpak/Flathub, and a curated app set (Firefox,
LibreOffice, CUPS+print/scan, a specific hand-picked GNOME app list); and
Lyra-Theme branding (GRUB/Plymouth/GNOME theming, `/etc/os-release`) - see
"Repos and package selection" and "Branding" below for what's real here
vs. still blocked.

**Deliberately not done here yet** (tracked as separate follow-up work):

- Calamares' installer *UI itself* still uses upstream's placeholder
  branding (`branding: default` in settings.conf) - product strings
  (name/logo/slideshow) for the install wizard specifically, as opposed
  to the boot/desktop theming below, which is done.

### Live-session Calamares launcher (resolved)

`root/usr/share/applications/calamares.desktop` overrides the RPM-shipped
launcher to `Exec=pkexec calamares`, and
`root/etc/polkit-1/rules.d/90-lyra-live-installer.rules` grants exactly
that action to `liveuser` without a password prompt. The action ID,
`com.github.calamares.calamares.pkexec.run`, is not guessed - it's read
directly from upstream Calamares' own shipped policy file
([`com.github.calamares.calamares.policy`](https://github.com/calamares/calamares/blob/calamares/com.github.calamares.calamares.policy)).

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
about Leap 15-era bugs, pkexec was kept and the polkit rule added
instead. **This choice is unverified** - whether pkexec reliably raises
the graphical prompt from a GNOME Wayland live session on Leap 16 is
exactly the kind of thing that needs a real VM boot test, and if it
turns out Leap 16 has the same problem Leap 15 did, falling back to
openSUSE's kdesu approach (and giving `liveuser` a real, even if
trivial, password) is the documented, proven fallback.

### Snapper bootstrap (resolved, simplified)

`root/etc/calamares/modules/snapshotcfg.conf` (a `shellprocess@snapshotcfg`
instance, see `settings.conf`) runs, chrooted, **after** `grubcfg` and
`bootloader`:

1. `snapper --no-dbus -c root create-config /` - the same command SUSE's
   own Snapper Tutorial documents for adding Snapper to an already-mounted
   Btrfs root.
2. `snapper --no-dbus -c root create --read-only --type single ...` - a
   "first root filesystem" snapshot. `--read-only` is mandatory, not
   cosmetic: `grub2-snapper-plugin.sh` (in the openSUSE `grub2` package)
   explicitly skips writable snapshots when building the boot menu.
3. `grub2-mkconfig -o /boot/grub2/grub.cfg` again, so the just-created
   snapshot actually shows up in the regenerated menu.

`grub2-snapper-plugin` was added to `kiwi/config.xml`'s package list (it
ships `/etc/grub.d/80_suse_btrfs_snapshot`), and `grubcfg.conf` now sets
`SUSE_BTRFS_SNAPSHOT_BOOTING: true`, which that script explicitly checks
- without it the "Start bootloader from a read-only snapshot" submenu
never gets generated at all, regardless of what Snapper is doing.

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
`/home` etc. are flat siblings of `.snapshots`" at the same time) - out
of proportion for what the spec actually needs, which is the GRUB panic
button working *going forward*. The trade-off: there's no pristine
"as-installed" snapshot to roll back to on a system built from this
config - only the "first root filesystem" snapshot above, and everything
snapshotted after it (zypper transactions, timeline), are available for
rollback via GRUB.

### Repos and package selection

**Lyra OBS repos**: `repo-lyra`, `repo-vega`, `repo-fina` were added to
`config.xml`, pointed at
`download.opensuse.org/repositories/home:/rodrigosbrito:/{lyra,vega,fina}/openSUSE_Leap_16.0/`.
This isn't assumed from the spec text - verified live against the real
OBS instance on 2026-07-28: all three projects exist, all three have an
`openSUSE_Leap_16.0` build target, all three repos actually publish
repodata at that URL (HTTP 200), and the packages this config installs
from them (`vega-gtk`) show `code="succeeded"` in OBS's own build
status API.

**`home:rodrigosbrito:atelier` (Prosa/Calco/Pulso) does not exist on
OBS** - confirmed via `GET /public/source/home:rodrigosbrito:atelier`,
which returns `unknown_project`, not just "no packages yet". This is a
real discrepancy between `PROMPT-LYRA-OS.md` and the current state of
the OBS account, not something this config works around: adding a repo
URL for a project that returns 404 would break every `zypper ref`/KIWI
build that touches it. Left out entirely rather than added-and-disabled.
**Confirmed expected for now**: Prosa/Calco/Pulso aren't shipping any
software yet, so there's nothing this repo would even carry today - this
isn't a v1 blocker. Revisit when Atelier has something to publish (create
the OBS project then, or fix the spec's repo name if it changes).

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
`config.xml` for the full reasoning, including why `gnome-terminal` is
explicit (GNOME's own current default is `gnome-console`, not what the
spec wants) and why `gnome-software` needed adding explicitly too (it's
only reachable via the separate `sw_management_gnome` pattern, not
`gnome_basic`/`gnome` at all - would have been silently missing even
under `plusRecommended`).

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

- **GRUB and Plymouth theming need nothing extra here.**
  `lyra-enterprise-theme`'s own RPM `%post` scriptlet sets `GRUB_THEME` in
  `/etc/default/grub`, runs `grub2-mkconfig`, and runs
  `plymouth-set-default-theme -R Lyra-Enterprise` automatically on
  install. Since `unpackfs` later copies this whole live root (including
  those already-updated config files) onto the install target, and
  Calamares' own `dracut`/`grubcfg`/`bootloader` steps regenerate the
  initramfs/grub.cfg from them afterward, this carries through correctly
  without any Calamares-side branding config.
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
  `NAME="Lyra OS"` / `PRETTY_NAME="Lyra OS 1.0 (Odisseia)"` /
  `ID=lyra-os`, keeping `ID_LIKE="opensuse suse"` so tooling that branches
  on family detection still works. `HOME_URL`, `BUG_REPORT_URL`, and
  `LOGO` were deliberately left out rather than filled with guesses -
  there's no confirmed project website/tracker URL, and no icon name
  confirmed to exist under `lyra-enterprise-icons` for `LOGO` to point at.
- **Calamares' own installer UI branding** (product name/logo in the
  wizard itself, as opposed to the desktop/boot theming above) is still
  `branding: default` - see the "not done yet" note above.
- GNOME 48+ is required by the theme; confirmed Leap 16.0 actually ships
  GNOME 48.3, so this isn't a live concern.

### Untested

None of this - Calamares config, KIWI build, Snapper/GRUB bootstrap,
repos/package selection, branding - has been run through an actual
`kiwi-ng` build + live install in a VM. Module/package names, YAML keys,
command flags, and file paths are grounded in Calamares', KIWI's,
snapper's, grub2's, and the Lyra projects' current upstream/OBS/repodata
source (checked, not guessed - see above for specific things that check
actually caught), but a real end-to-end build+install is the only way to
be sure it all works together, and is the natural next step before
trusting this.

## Notable choices

- **Live ISO, not OEM/unattended installer**: `image="iso"` with
  `flags="overlay"` (the `dracut-kiwi-live` module) produces a bootable
  live squashfs, matching how Calamares-based distros work - Calamares
  runs from inside the live session and partitions the target disk
  itself. The live squashfs root itself isn't Btrfs; the Btrfs+Snapper
  subvolume layout in `root/etc/calamares/modules/mount.conf` only
  applies to the *installed* system.
- **`liveuser` with GDM autologin** (`config.sh`): makes the live ISO
  boot to a usable desktop even before there's a way to launch Calamares
  from it (see "Known gaps" below). No relation to the installed
  system's account model (root disabled, sudo user created by
  Calamares) - that's separate, install-time behavior.
- **`grub2-*` binary names**: `bootloader.conf`/`grubcfg.conf` point at
  `grub2-install`, `grub2-mkconfig`, `/boot/grub2/grub.cfg` etc. -
  Calamares' own defaults assume Arch/Debian-style `grub-*` names, which
  don't exist on Leap.
- **Btrfs subvolume layout**: `mount.conf`'s `btrfsSubvolumes` list
  mirrors the fallback list openSUSE's own installer (yast2-storage-ng)
  uses, rather than Calamares' generic `@`/`@home` example, so an
  installed system's layout matches what a Leap user would expect from
  `/etc/fstab`.
- **zram**: `zram-generator` package + `root/etc/systemd/zram-generator.conf`
  shipped verbatim into the image (`zram0`, size = min(ram/2, 8GiB),
  zstd). No swapfile anywhere.
- **Secure Boot groundwork**: `firmware="uefi"` + `shim`/`mokutil`
  packages, relying on Leap's Microsoft-signed shim (nothing custom).

## Building

Requires `kiwi-ng` (the `kiwi` package on Leap 16) on the build host.

```sh
sudo kiwi-ng system build \
  --description kiwi \
  --target-dir /tmp/lyra-os-build
```

If `kiwi-ng` rejects the description with a schema version error, check
the installed tool's supported schema (`kiwi-ng --version`) and adjust
the `schemaversion` attribute in `config.xml` (currently `8.5`) to match.
