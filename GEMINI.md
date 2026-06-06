# Lyra Project Instructions

## Overview
Lyra is an Arch Linux-based distribution built using `archiso`. This document outlines the standards, workflows, and architectural conventions for contributors.

## Architecture
- **Base System:** Managed via `archiso` configuration in the `profile/` directory.
- **Installer:** Calamares configuration is located in the `calamares/` directory.
- **Branding:** Assets, Plymouth themes, and SDDM configurations are centralized in `branding/`.
- **Custom Tools:** Located in `packages/` (e.g., `lyra-kernel-manager`).

## Workflow Conventions
- **Building:** Use the root `./build.sh` script for generating ISOs.
- **Package Management:** Add standard Arch packages to `profile/packages.x86_64`.
- **Custom Packages:** Custom packages in `packages/` must follow standard PKGBUILD practices. Ensure new packages are included in `aur/packages.list`.
- **System Configuration:** Persistent modifications to the live environment must be applied via `profile/airootfs/`.

## Quality & Validation Standards
- **Shell Scripts:** All scripts must pass `shellcheck` linting.
- **Python Tools:** Adhere to PEP 8 standards. Use strict type hinting.
- **Testing:** Verify structural changes by performing a build and testing in a virtualized environment before submitting changes.
- **Documentation:** Maintain `docs/DECISIONS.md` for architectural design choices.

## Commit Guidelines
- Use clear, concise commit messages following conventional commit principles.
- Scope commits to single architectural or functional units.
- **Never** include secrets, API keys, or sensitive credentials in commits.
