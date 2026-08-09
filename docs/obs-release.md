# OBS staging, promotion, and rollback

Lyra OS Beta 2 uses separate OBS staging and release channels. The ISO consumes
only the existing release projects. A source change must build and publish in
staging, pass its package tests, and enter release through a revision-pinned,
reviewed submit request.

The machine-readable contract is [`obs/projects.toml`](../obs/projects.toml).
Run `./scripts/obs-release.py validate` after changing it.

The manifest also pins the fingerprint of the OBS signing key inherited from
`home:rodrigosbrito`. A key rotation must update that fingerprint in a reviewed
commit before a new release can pass the health gate.

## Architecture

| Component | Staging project | Release project | Target | ISO |
|---|---|---|---|---|
| Lyra base and apps | `home:rodrigosbrito:lyra:staging` | `home:rodrigosbrito:lyra` | Leap 16.0, x86_64 | release only |
| Vega | `home:rodrigosbrito:vega:staging` | `home:rodrigosbrito:vega` | Leap 16.0, x86_64 | release only |
| Fina | `home:rodrigosbrito:fina:staging` | `home:rodrigosbrito:fina` | Leap 16.0 and Tumbleweed, x86_64 | Leap release only |

Staging repositories build directly against their official openSUSE targets.
They are published so testers can install the exact RPMs, but neither KIWI nor
an installed Lyra system contains a staging URL. The release projects remain
the stable URLs consumed by `kiwi/config.xml`.

Package ownership is explicit in the manifest. Multibuild flavors such as
`lyra-theme:lyra-os-icons` are results of the `lyra-theme` source package and
are promoted together. An undeclared source package, a missing package, a
failed flavor, an unpublished repository, or a target mismatch fails the gate.

## Repository priorities

During image construction, KIWI uses priorities 1, 2, and 3 for Lyra, Vega,
and Fina so the image consumes the reviewed Lyra packages. Official Leap OSS
and non-OSS use 20 and 21. This build-only exception is allowlisted by the OBS
package inventory.

Before the installed system is finalized, the Rust installer changes all three
personal OBS repositories to priority 90. Official Leap therefore wins every
later same-name resolution. `obs-release.py validate` checks both sides of
this contract and fails CI if they drift.

## Credentials and responsibility

The OBS maintainer `rodrigosbrito` owns project metadata, accepts submit
requests, and coordinates rollback. Contributors may create staging commits
and submit requests if granted OBS permissions; the author must not be the sole
reviewer for a production-impacting change when another maintainer is
available.

Use the system keyring configured by `scripts/bootstrap-development.sh`.
Never put an OBS password, token, cookie, `oscrc`, or command containing a
secret in Git, issue comments, CI variables printed to logs, or submit-request
messages. The commands below rely on `osc`'s credential manager and expose no
credential material.

## Normal flow

Select the project and package from `obs/projects.toml`, then:

```console
osc -A https://api.opensuse.org checkout home:rodrigosbrito:lyra:staging beam
cd home:rodrigosbrito:lyra:staging/beam
osc build --clean --checks openSUSE_Leap_16.0 x86_64
osc status
osc diff
osc commit -m 'Explain the change and its test coverage'
```

Wait for the remote build and publication. Validate the whole staging channel,
not only the changed package:

```console
./scripts/obs-release.py check --channel staging
```

Run the package's functional/smoke tests against staging RPMs. First preview
the exact revision-pinned submit request; then repeat with `--execute`:

```console
./scripts/obs-release.py promote lyra beam \
  --test-evidence 'osc build --clean --checks; beam smoke test on Leap 16 VM'
./scripts/obs-release.py promote lyra beam \
  --test-evidence 'osc build --clean --checks; beam smoke test on Leap 16 VM' \
  --execute
```

Review the request diff and source build status. Acceptance is deliberately not
automated by the helper:

```console
osc -A https://api.opensuse.org request show --diff --source-buildstatus REQUEST_ID
osc -A https://api.opensuse.org review add -U SECOND_REVIEWER REQUEST_ID
osc -A https://api.opensuse.org request accept -m 'Staging and tests verified' REQUEST_ID
./scripts/obs-release.py check --channel release
```

Only the final `request accept` copies the source into the ISO-consumed project.
Never use `osc copypac` directly from a workstation into a release project.

## Release health gate

Before building a release candidate, verify the release channels through their
public download URLs and write the evidence consumed by #51:

```console
./scripts/obs-release.py health \
  --output artifacts/obs-health-2026.08-beta2.json
```

This single command checks every declared project, target, architecture and
source package. It fails when:

- project metadata or package inventory differs from `obs/projects.toml`;
- a build is failed, unresolvable, excluded without successful flavors, or the
  repository is not published;
- the current release revision does not originate from an accepted,
  revision-pinned submit request from the matching staging project and is not
  part of the explicitly pinned stable baseline;
- public repository metadata is unavailable or its detached signature does
  not match the pinned OBS key;
- a required binary RPM cannot be downloaded or its signature is invalid.

The JSON report records source revision, version, accepted request or baseline
tag, build state, public URL, RPM version, size and SHA-256. Preserve it with
the release candidate and attach it to the image evidence:

```console
./scripts/image-build.py artifact-manifest /path/to/kiwi/results \
  --output /path/to/lyra-os.evidence.json \
  --test-result obs-repositories=artifacts/obs-health-2026.08-beta2.json
```

The command requires `osc`, `gpg`, `gpgv`, `rpm` and `rpmkeys`. OBS credentials
are used only for API reads; RPMs and signed repository metadata are fetched
from `download.opensuse.org`, exactly as the ISO consumes them.

The one-time `[baseline]` table pins every package revision that existed at
`v2026.08-beta2-stable-20260809`, before the staging-only policy became a hard
gate. It cannot authorize a new revision: any direct commit that changes a
`srcmd5` immediately fails, and all subsequent changes must arrive through an
accepted staging request.

## Rollback

Identify a known-good historical release revision without changing anything:

```console
osc -A https://api.opensuse.org log home:rodrigosbrito:lyra beam
osc -A https://api.opensuse.org checkout -r REVISION home:rodrigosbrito:lyra beam
```

Stage the exact revision. The first command is a dry-run; `--execute` changes
staging only:

```console
./scripts/obs-release.py rollback lyra beam --revision REVISION
./scripts/obs-release.py rollback lyra beam --revision REVISION --execute
./scripts/obs-release.py check --channel staging
```

Re-run the smoke tests and use the normal `promote` flow. The resulting submit
request records the restored source revision and test evidence. Do not delete
the defective OBS revision: keeping history makes the incident auditable.

Rollback is considered complete only after the release project is published,
`check --channel release` passes, a clean ISO resolves the known-good RPM, and
the incident records the request ID, bad revision, restored revision, tester,
and time.

### Beta 2 rollback rehearsal

On 2026-08-08 the rollback path was exercised without touching an
ISO-consumed project. `fina` staging was changed from release revision 12 to
historical release revision 11. OBS published that revision successfully for
both `openSUSE_Leap_16.0/x86_64` and `openSUSE_Tumbleweed/x86_64`.

The source identity was verified rather than inferred from a revision number:
release revision 11 and staging revision 2 both had
`srcmd5=693a80e881f2f3864d5ad13b49d01c8f`. Staging was then restored to release
revision 12; release revision 12 and staging revision 3 both had
`srcmd5=0c370c814568c112b6d6e0e358c999c3`, and both targets published green
again. No submit request or write to `home:rodrigosbrito:fina` occurred.

## Retention and changes to policy

- Keep release project history indefinitely and retain at least the current and
  previous successful staging revisions.
- Revoke obsolete open submit requests; do not accept them after newer source
  was tested.
- Project, target, architecture, package inventory, or priority changes require
  a Git review of `obs/projects.toml` and this document before OBS metadata is
  updated.
- `init-staging` is idempotent but privileged. Preview it without `--execute`;
  use the executing form only to reconcile OBS with reviewed manifest changes.

```console
./scripts/obs-release.py init-staging
./scripts/obs-release.py init-staging --execute
```
