# KIWI image builds and SourceForge releases

The Lyra image pipeline has four explicit boundaries:

- GitHub is the canonical source for the KIWI description and root overlay;
- KIWI builds run locally or in CI from a clean Git commit;
- SourceForge is the public distribution point for ISO artifacts;
- OBS builds and publishes RPM packages only.

There is no OBS image project, KIWI package, image repository, or ISO binary.
The image tool deliberately has no command capable of creating one.
`kiwi/config.xml` owns the installed repositories and package selection,
`release.toml` owns the release identity, and `image-build.toml` records this
distribution policy plus the OBS projects used only as RPM sources.

## Policy gate and deterministic source export

Run the release and repository checks, then create an inspectable source
export from a clean commit:

```sh
./scripts/release.py check
./scripts/obs-release.py validate
./scripts/image-build.py validate
destination="$(mktemp -d)/lyra-image"
./scripts/image-build.py export "$destination"
./scripts/image-build.py verify-export "$destination"
```

`--allow-dirty` exists only for structural inspection. A dirty export records
that state and cannot pass `verify-export`.

The export contains the canonical `config.xml`, `config.sh`, root overlay,
and a normalized `root.tar.gz`. It also records the full Git commit, commit
epoch, and deterministic UTC build timestamp in `build-source.json` and
`root/usr/lib/lyra-os/build-source`. The latter becomes
`/usr/lib/lyra-os/build-info` in the installed system.

The verification gate rejects an export that differs from the GitHub KIWI
description, contains `_multibuild` or an `obsrepositories:/` source, uses a
staging repository, disables repository/package signature checks, or lacks
the embedded source identity.

## Build and test the ISO

For an interactive development build with the current installer workspace,
VM installation, and first-boot test, use:

```sh
./kiwi/test/build-and-run-vm.sh
```

The helper compiles the local Rust installer before KIWI and records
`local-installer-build` in that development image. A release candidate must
instead consume the signed installer RPM published by OBS:

```sh
./kiwi/test/build-and-run-vm.sh --published-installer
```

The script builds directly from `kiwi/`, retains the previous usable ISO until
its replacement is ready, creates a 24 GiB installation disk plus isolated
OVMF state, starts QEMU, and records logs below `kiwi/.kiwi/`. Every invocation
stops its previous QEMU process and deletes that VM's disk and NVRAM before the
build. The ISO is selected only for the first boot; reboot the guest in the
same QEMU session to test the installed disk. `--help` lists the environment
overrides for disk, RAM and virtual CPUs. CI uses the deterministic export gate
to prove that the same committed inputs are selected without publishing an
image to OBS.

Signature verification is mandatory through `rpm-check-signatures`,
`repository_gpgcheck`, and `package_gpgcheck`. The KIWI description uses the
canonical HTTPS openSUSE and Lyra package repositories. Flathub's URL and
signing key are versioned at
`kiwi/root/etc/flatpak/remotes.d/flathub.flatpakrepo`; no network command runs
from `config.sh`.

The NVIDIA ISO remains a separate optional deliverable. It does not introduce
an OBS image flavor and cannot block the standard ISO.

## Release evidence

Keep the ISO together with its package inventory, verification report, KIWI
report, checksum, checksum signature, and both SBOM formats:

- `*.iso`
- `*.packages`
- `*.verified`
- `*.report`
- `*.iso.sha256`
- `*.iso.sha256.asc`
- `*.cdx.json`
- `*.spdx.json`

The `.packages` file records exact RPM versions and OBS source revisions.
Before the KIWI build, create the signed public-repository health report:

```sh
./scripts/obs-release.py health \
  --output /path/to/obs-health-2026.08-beta2.json
```

Create a checksummed evidence document and link the OBS health, installer and
smoke-test results:

```sh
./scripts/image-build.py artifact-manifest /path/to/kiwi/results \
  --output /path/to/lyra-os.evidence.json \
  --test-result obs-repositories=/path/to/obs-health-2026.08-beta2.json \
  --test-result installer=/path/to/manual-install-result.json \
  --test-result smoke=/path/to/issue-51-result.json
```

The command fails if an artifact is absent or ambiguous, the package inventory
does not contain exact sources, or a named test result does not exist.

After the checksum and release gates pass, publish the ISO and its evidence on
SourceForge. Upload credentials and the SourceForge release operation remain
outside this repository; this prevents CI or an OBS package workflow from
silently distributing an unapproved image.

## OBS boundary

OBS remains responsible for the Lyra, Vega, Fina, and installer RPMs. Their
staging, health, signing, and promotion are controlled by
`scripts/obs-release.py` and documented in `docs/obs-release.md`.

Do not add an image project, `Type: kiwi` project configuration, `_multibuild`
image recipe, or ISO publication step to OBS. Any future image automation must
consume the GitHub sources and hand approved artifacts to the SourceForge
release process without storing the ISO in OBS.
