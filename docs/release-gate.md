# Desktop Alpha 3 release gate

This checklist is the versioned go/no-go contract for the standard Lyra OS
Desktop Alpha 3 ISO. A release coordinator may declare **GO** only when every blocking
item below has passed and its evidence is included in the final image evidence
manifest. Missing evidence is a failure, not an implicit exception.

## Severity and blocking policy

- **P0 — stop immediately:** data loss, credential disclosure, corrupted
  installation media, or an exploitable default configuration.
- **P1 — release blocker:** failure to boot the live or installed system;
  failure of the Lyra Installer; broken basic network, update, Snapper or
  rollback; invalid repository/package signatures; an unpublished mandatory
  package; or a regression without a safe workaround.
- **P2 — known issue:** degraded optional functionality with a tested,
  documented workaround. It must appear in the release notes.
- **P3 — follow-up:** cosmetic or low-impact defect that does not invalidate a
  supported scenario. It must have a tracking issue when not fixed.

No P0 or P1 issue may remain open at publication time. A P2 may be accepted
only when the decision record names its issue, workaround, owner and residual
risk.

## Candidate identity

- [ ] source tree is clean and the full commit is recorded;
- [ ] `release.toml`, KIWI metadata, ISO filename and installed `VERSION_ID`
  agree;
- [ ] the ISO package inventory contains exact OBS source revisions;
- [ ] the candidate is tagged only after all blocking checks pass.

## Required evidence

Each file is structured JSON with schema 1 and top-level
`"status": "passed"`. `scripts/image-build.py artifact-manifest` also checks
the expected mode, nonempty passing checks, final rollback phase, OBS project
content and hardware coverage; a bare green status is rejected:

- [ ] `obs-repositories`: release projects published; provenance, repository
  metadata, keys and RPM signatures verified by `obs-release.py health`;
- [ ] `live-session`: autologin, GNOME, offline startup, basic devices and
  absence of critical journal failures;
- [ ] `installer`: Lyra Installer completes against the candidate ISO without
  a fallback installer;
- [ ] `first-boot`: installed disk boots, the created account works and no
  live-session artifact remains;
- [ ] `uefi-secure-boot`: supported UEFI and Secure Boot scenarios pass;
- [ ] `rollback`: update, Snapper snapshots and GRUB rollback pass;
- [ ] `hardware-matrix`: required real/virtual hardware scenarios are recorded.

## Release signing key

The ISO checksum is signed with the release coordinator's own GPG key, not a
key this repository generates or holds. The current canonical key is:

- **Fingerprint:** `E765 8249 6F86 597D A854  7BA4 FE28 7BB5 4891 BA80`
- **UID:** `Lyra OS Release <britors@live.com>`
- **Public key:** [`docs/release-signing-key.asc`](release-signing-key.asc)

Anyone verifying a published ISO should import that file and confirm the
fingerprint matches before trusting `*.iso.sha256.asc`. If the key is ever
rotated, replace both this fingerprint and `release-signing-key.asc` in the
same commit that publishes the first candidate signed with the new key.

## Artifact and publication checks

- [ ] ISO, package inventory, KIWI verification/report and both SBOM formats
  are present;
- [ ] SHA-256 is generated, signed with the key above and independently
  verified;
- [ ] release notes list requirements, limitations, P2/P3 issues and tested
  workarounds;
- [ ] the evidence manifest is generated from a clean commit and contains all
  required green results;
- [ ] ISO and evidence are uploaded to SourceForge and downloaded again for
  checksum/signature verification;
- [ ] #51 records coordinator, decision time, evidence URLs, accepted P2/P3
  risks and the exact source commit.

## Decision record

Record this block in #51 for every candidate:

```text
Decision: GO | NO-GO
Candidate commit:
ISO filename:
SHA-256:
Coordinator:
Decision time (UTC):
Evidence manifest:
Accepted P2/P3 issues and workarounds:
Residual risks:
```

## Current Desktop Alpha 3 state

**NO-GO pending the clean publication candidate and its signed artifacts.**
Repeated installation with the installer RPM published by OBS passed, including
first boot, login, user-password `sudo`, network/update, reboot, GRUB and
Snapper. The installer package build and all OBS release projects are published.
The remaining release work is to build the clean candidate from the recorded
commit, generate and sign its artifacts, publish them, and verify the downloaded
copy. Structured runtime evidence remains part of the formal gate when the
project performs a fully evidenced release decision.

If a defect is found after publication, hide or remove the affected files on
SourceForge, record their checksums as withdrawn, stage and review the fix, and
publish a replacement candidate with a new evidence manifest. Never overwrite
an already distributed ISO while retaining its old checksum or decision record.
