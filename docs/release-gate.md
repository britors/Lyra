# Beta 2 release gate

This checklist is the versioned go/no-go contract for the standard Lyra OS
Beta 2 ISO. A release coordinator may declare **GO** only when every blocking
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

Each file is JSON with top-level `"status": "passed"`. The names are enforced
by `scripts/image-build.py artifact-manifest`:

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

## Artifact and publication checks

- [ ] ISO, package inventory, KIWI verification/report and both SBOM formats
  are present;
- [ ] SHA-256 is generated, signed and independently verified;
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

## Current Beta 2 state

**NO-GO pending the new candidate ISO and runtime evidence.** The OBS health
gate passed on 2026-08-09 for all three release projects and all 15 source
packages after the reviewed staging promotions. Repository publication,
package provenance, metadata, keys and RPM signatures are green. The remaining
blocking work is to build the clean candidate from the recorded commit and
complete the live-session, installer, first-boot, Secure Boot, rollback and
hardware-matrix evidence above.

If a defect is found after publication, hide or remove the affected files on
SourceForge, record their checksums as withdrawn, stage and review the fix, and
publish a replacement candidate with a new evidence manifest. Never overwrite
an already distributed ISO while retaining its old checksum or decision record.
