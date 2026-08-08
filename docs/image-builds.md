# KIWI image builds: local and OBS

`kiwi/config.xml` is the single source of truth for the Lyra OS version,
installed repositories, and package selection. `release.toml` owns the release
identity. `image-build.toml` owns only the OBS image project, build-path order,
architecture, flavors, and required evidence.

The exported OBS package is generated; do not edit it by hand. Its five HTTPS
repositories are marked `imageonly=true`, so they remain configured in the
resulting system but cannot affect dependency resolution in OBS. The single
`obsrepositories:/` source is injected for the build. OBS resolves that source
from the ordered project paths in `image-build.toml`.

## Offline policy and deterministic export

Run the policy gate and produce an inspectable package:

```sh
./scripts/release.py check
./scripts/obs-release.py validate
./scripts/image-build.py validate
destination="$(mktemp -d)/lyra-image"
./scripts/image-build.py export "$destination"
./scripts/image-build.py verify-export "$destination"
```

Export requires a clean tree. `--allow-dirty` exists only for structural
inspection and marks that export dirty; it cannot pass `verify-export` or be
published. The export records the checked-out full Git commit, commit epoch,
and deterministic UTC build timestamp in `build-source.json` and in
`root/usr/lib/lyra-os/build-source`. The latter becomes
`/usr/lib/lyra-os/build-info` inside the image.

Signature verification is mandatory (`rpm-check-signatures`,
`repository_gpgcheck`, and `package_gpgcheck`). Missing dependencies, invalid
repository metadata, or bad package signatures therefore fail KIWI/OBS instead
of creating a release candidate. Flathub's URL and signing key are versioned at
`kiwi/root/etc/flatpak/remotes.d/flathub.flatpakrepo`; no network command runs
from `config.sh`.

## Equivalent local OBS build

Use a clean exported directory as an osc package checkout, or check out the
published source and run:

```sh
osc -A https://api.opensuse.org checkout \
  home:rodrigosbrito:lyra:images:staging lyra-image
cd home:rodrigosbrito:lyra:images:staging/lyra-image
osc -A https://api.opensuse.org build images x86_64 \
  --multibuild-package=standard
```

This is the same repository graph and `standard` profile used remotely. For a
direct KIWI build and interactive QEMU/installer validation, use:

```sh
./kiwi/test/build-and-run-vm.sh
```

## Publish to the staging image project

Review the dry run, then execute from a clean committed tree:

```sh
./scripts/image-build.py publish
./scripts/image-build.py publish --execute
./scripts/image-build.py check-remote
```

The project is `home:rodrigosbrito:lyra:images:staging`, package
`lyra-image`, repository `images`, architecture `x86_64`. Its path order is
Lyra, Vega, Fina, then `Virtualization:Appliances:Builder`; changing that order
is a reviewed source change. The project configuration uses
`Repotype: staticlinks`, which gives published images stable download paths.

`standard` is the only `_multibuild` entry for Beta 2. The `nvidia` profile is
declared but optional and not submitted, so work tracked in #32 can reuse the
same base description without duplicating packages and can never block the
standard ISO.

## Artifact and test evidence

KIWI emits the ISO plus `.packages`, `.verified`, `.changes`, and
`kiwi.result.json`. Keep all five. The `.packages` file is the authoritative
list of exact package versions and OBS source revisions included in that image.
Create a checksummed JSON evidence record and link results from #11 and #51:

```sh
./scripts/image-build.py artifact-manifest /path/to/kiwi/results \
  --output /path/to/lyra-os.evidence.json \
  --test-result installer=/path/to/issue-11-result.json \
  --test-result smoke=/path/to/issue-51-result.json
```

The command fails if any required artifact is absent, if more than one matching
artifact makes the result ambiguous, if a package lacks its exact source
revision, or if a named test result does not exist. Publish the evidence JSON
beside the ISO; its SHA-256 entries bind each artifact and test result to that
record.

OBS build logs and binaries can be inspected with:

```sh
osc -A https://api.opensuse.org results \
  home:rodrigosbrito:lyra:images:staging lyra-image --multibuild-package=standard
osc -A https://api.opensuse.org buildlog \
  home:rodrigosbrito:lyra:images:staging images x86_64 lyra-image:standard
osc -A https://api.opensuse.org getbinaries \
  home:rodrigosbrito:lyra:images:staging lyra-image:standard images x86_64
```

An image is a candidate only after `check-remote` reports the repository
published and `lyra-image:standard` succeeded, and its evidence manifest links
the completed installer and smoke-test results.
