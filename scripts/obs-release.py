#!/usr/bin/env python3
"""Validate and operate Lyra's reviewed OBS staging workflow."""

from __future__ import annotations

import argparse
import dataclasses
import re
import subprocess
import sys
import tempfile
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "obs/projects.toml"
IMAGE_CONFIG = ROOT / "kiwi/config.xml"
INSTALLER_DEPLOY = ROOT / "installer/src/service/operations/deploy.rs"
GOOD_PACKAGE_STATES = {"succeeded", "excluded"}


class PolicyError(RuntimeError):
    """A local or remote release policy invariant was not satisfied."""


@dataclasses.dataclass(frozen=True)
class Target:
    name: str
    upstream_project: str
    upstream_repository: str
    architectures: tuple[str, ...]
    iso_consumer: bool


@dataclasses.dataclass(frozen=True)
class Project:
    id: str
    release: str
    staging: str
    iso_consumer: bool
    packages: tuple[str, ...]
    targets: tuple[Target, ...]


@dataclasses.dataclass(frozen=True)
class Manifest:
    api_url: str
    maintainer: str
    priorities: dict[str, int]
    projects: tuple[Project, ...]

    @classmethod
    def load(cls, path: Path = DEFAULT_MANIFEST) -> "Manifest":
        with path.open("rb") as stream:
            data = tomllib.load(stream)
        if data.get("schema") != 1:
            raise PolicyError("obs manifest schema must be 1")
        projects = tuple(
            Project(
                id=item["id"],
                release=item["release"],
                staging=item["staging"],
                iso_consumer=item["iso_consumer"],
                packages=tuple(item["packages"]),
                targets=tuple(
                    Target(
                        name=target["name"],
                        upstream_project=target["upstream_project"],
                        upstream_repository=target["upstream_repository"],
                        architectures=tuple(target["architectures"]),
                        iso_consumer=target["iso_consumer"],
                    )
                    for target in item["targets"]
                ),
            )
            for item in data["projects"]
        )
        manifest = cls(
            api_url=data["api_url"],
            maintainer=data["maintainer"],
            priorities=dict(data["priorities"]),
            projects=projects,
        )
        manifest.validate()
        return manifest

    def validate(self) -> None:
        if self.api_url != "https://api.opensuse.org":
            raise PolicyError("only the canonical HTTPS OBS API is allowed")
        if not re.fullmatch(r"[a-zA-Z0-9_.-]+", self.maintainer):
            raise PolicyError("invalid OBS maintainer")
        ids: set[str] = set()
        remote_names: set[str] = set()
        for project in self.projects:
            if project.id in ids:
                raise PolicyError(f"duplicate project id: {project.id}")
            ids.add(project.id)
            if project.release == project.staging:
                raise PolicyError(f"{project.id}: staging and release must differ")
            for name in (project.release, project.staging):
                if name in remote_names:
                    raise PolicyError(f"duplicate OBS project: {name}")
                remote_names.add(name)
                if not name.startswith("home:rodrigosbrito:"):
                    raise PolicyError(f"project outside the approved OBS namespace: {name}")
            if not project.packages or len(set(project.packages)) != len(project.packages):
                raise PolicyError(f"{project.id}: package list is empty or duplicated")
            if not project.targets:
                raise PolicyError(f"{project.id}: at least one target is required")
            if project.iso_consumer and not any(target.iso_consumer for target in project.targets):
                raise PolicyError(f"{project.id}: ISO consumer has no ISO target")

        required = {
            "official_oss": 20,
            "official_non_oss": 21,
            "lyra_image": 1,
            "vega_image": 2,
            "fina_image": 3,
            "installed_third_party": 90,
        }
        if self.priorities != required:
            raise PolicyError(f"repository priorities differ from policy: {required}")

    def project(self, project_id: str) -> Project:
        for project in self.projects:
            if project.id == project_id:
                return project
        raise PolicyError(f"unknown project id: {project_id}")


class Obs:
    def __init__(self, api_url: str, execute: bool = False) -> None:
        self.api_url = api_url
        self.execute = execute

    @staticmethod
    def format_command(arguments: list[str]) -> str:
        def quote(value: str) -> str:
            if re.fullmatch(r"[A-Za-z0-9_./:@=+-]+", value):
                return value
            return "'" + value.replace("'", "'\"'\"'") + "'"

        return " ".join(quote(value) for value in arguments)

    def run(self, arguments: list[str], *, mutating: bool = False) -> str:
        command = ["osc", "-A", self.api_url, *arguments]
        if mutating and not self.execute:
            print(f"PLAN: {self.format_command(command)}")
            return ""
        result = subprocess.run(command, check=False, text=True, capture_output=True)
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip()
            raise PolicyError(f"command failed: {self.format_command(command)}\n{detail}")
        return result.stdout

    def api_xml(self, path: str) -> ET.Element:
        try:
            return ET.fromstring(self.run(["api", path]))
        except ET.ParseError as error:
            raise PolicyError(f"OBS returned invalid XML for {path}: {error}") from error


def check_local_priorities(manifest: Manifest) -> None:
    root = ET.parse(IMAGE_CONFIG).getroot()
    repositories = {
        node.attrib["alias"]: int(node.attrib["priority"])
        for node in root.findall("repository")
    }
    expected = {
        "repo-oss": manifest.priorities["official_oss"],
        "repo-non-oss": manifest.priorities["official_non_oss"],
        "repo-lyra": manifest.priorities["lyra_image"],
        "repo-vega": manifest.priorities["vega_image"],
        "repo-fina": manifest.priorities["fina_image"],
    }
    if {name: repositories.get(name) for name in expected} != expected:
        raise PolicyError(f"KIWI repository priorities differ from policy: {expected}")

    deployment = INSTALLER_DEPLOY.read_text(encoding="utf-8")
    installed = manifest.priorities["installed_third_party"]
    priority = re.search(
        r"const INSTALLED_THIRD_PARTY_PRIORITY:\s*u8\s*=\s*(\d+);",
        deployment,
    )
    if priority is None or int(priority.group(1)) != installed:
        raise PolicyError(f"installed-system priority differs from policy: {installed}")

    aliases = re.search(
        r"const LYRA_REPO_ALIASES:\s*&\[&str\]\s*=\s*&\[(.*?)\];",
        deployment,
        re.DOTALL,
    )
    if aliases is None:
        raise PolicyError("installer repository allow-list is missing")
    for alias in ("repo-lyra", "repo-vega", "repo-fina"):
        if f'"{alias}"' not in aliases.group(1):
            raise PolicyError(f"installed-system priority missing for {alias}: {installed}")


def render_project_meta(manifest: Manifest, project: Project) -> str:
    root = ET.Element("project", {"name": project.staging})
    ET.SubElement(root, "title").text = f"Lyra {project.id} staging"
    ET.SubElement(root, "description").text = (
        f"Build and test gate for {project.release}. Not consumed by Lyra ISO. "
        "Changes reach release only through reviewed submit requests."
    )
    ET.SubElement(root, "person", {"userid": manifest.maintainer, "role": "maintainer"})
    publish = ET.SubElement(root, "publish")
    for target in project.targets:
        for arch in target.architectures:
            ET.SubElement(publish, "enable", {"repository": target.name, "arch": arch})
    for target in project.targets:
        repository = ET.SubElement(root, "repository", {"name": target.name})
        ET.SubElement(
            repository,
            "path",
            {"project": target.upstream_project, "repository": target.upstream_repository},
        )
        for arch in target.architectures:
            ET.SubElement(repository, "arch").text = arch
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode") + "\n"


def source_revisions(obs: Obs, remote: str) -> dict[str, str]:
    root = obs.api_xml(f"/source/{remote}?view=info")
    return {
        node.attrib["package"]: node.attrib["srcmd5"]
        for node in root.findall("sourceinfo")
        if ":" not in node.attrib["package"]
    }


def check_project_meta(project: Project, remote: str, root: ET.Element) -> None:
    if root.attrib.get("name") != remote:
        raise PolicyError(f"metadata name mismatch for {remote}")
    actual: dict[str, tuple[tuple[str, str], tuple[str, ...]]] = {}
    for repository in root.findall("repository"):
        paths = tuple(
            (path.attrib["project"], path.attrib["repository"])
            for path in repository.findall("path")
        )
        arches = tuple(arch.text or "" for arch in repository.findall("arch"))
        actual[repository.attrib["name"]] = (paths, arches)
    expected = {
        target.name: (
            ((target.upstream_project, target.upstream_repository),),
            target.architectures,
        )
        for target in project.targets
    }
    if actual != expected:
        raise PolicyError(f"{remote}: repositories/targets differ from manifest")


def check_target_result(obs: Obs, project: Project, remote: str, target: Target, arch: str) -> None:
    root = obs.api_xml(
        f"/build/{remote}/_result?repository={target.name}&arch={arch}&view=status"
    )
    result = root.find("result")
    if result is None or result.attrib.get("code") != "published":
        code = "missing" if result is None else result.attrib.get("code", "unknown")
        raise PolicyError(f"{remote}/{target.name}/{arch}: not published ({code})")
    statuses = {node.attrib["package"]: node.attrib["code"] for node in result.findall("status")}
    for package in project.packages:
        state = statuses.get(package)
        flavors = {
            name: code for name, code in statuses.items() if name.startswith(f"{package}:")
        }
        if state == "succeeded":
            continue
        if state == "excluded" and flavors and all(code == "succeeded" for code in flavors.values()):
            continue
        raise PolicyError(
            f"{remote}/{target.name}/{arch}/{package}: build gate failed "
            f"(state={state!r}, flavors={flavors})"
        )


def check_remote(obs: Obs, manifest: Manifest, channel: str) -> None:
    channels = ("release", "staging") if channel == "all" else (channel,)
    for project in manifest.projects:
        for current in channels:
            remote = getattr(project, current)
            meta = obs.api_xml(f"/source/{remote}/_meta")
            check_project_meta(project, remote, meta)
            revisions = source_revisions(obs, remote)
            missing = sorted(set(project.packages) - set(revisions))
            extra = sorted(set(revisions) - set(project.packages))
            if missing or extra:
                raise PolicyError(f"{remote}: package inventory mismatch; missing={missing}, extra={extra}")
            for target in project.targets:
                for arch in target.architectures:
                    check_target_result(obs, project, remote, target, arch)
            print(f"OK: {remote} ({len(project.packages)} source packages, all targets published)")


def init_staging(obs: Obs, manifest: Manifest) -> None:
    for project in manifest.projects:
        metadata = render_project_meta(manifest, project)
        if obs.execute:
            with tempfile.NamedTemporaryFile("w", encoding="utf-8") as stream:
                stream.write(metadata)
                stream.flush()
                obs.run(["meta", "prj", project.staging, "-F", stream.name], mutating=True)
        else:
            print(f"PLAN: create/update {project.staging} with manifest-defined metadata")
        revisions = source_revisions(obs, project.release)
        for package in project.packages:
            revision = revisions[package]
            obs.run(
                [
                    "copypac",
                    "-r",
                    revision,
                    "-m",
                    "Seed staging from the reviewed release revision",
                    project.release,
                    package,
                    project.staging,
                    package,
                ],
                mutating=True,
            )


def promote(obs: Obs, manifest: Manifest, args: argparse.Namespace) -> None:
    project = manifest.project(args.project)
    if args.package not in project.packages:
        raise PolicyError(f"{args.package} is not owned by {project.id}")
    if not args.test_evidence.strip():
        raise PolicyError("--test-evidence must identify the completed tests")
    check_remote_project(obs, project, project.staging)
    revisions = source_revisions(obs, project.staging)
    revision = revisions[args.package]
    if args.revision and args.revision != revision:
        raise PolicyError(
            f"staging revision changed: requested {args.revision}, current {revision}; re-review it"
        )
    message = (
        f"Promote {args.package} from staging\n\n"
        f"Source revision: {revision}\nTest evidence: {args.test_evidence.strip()}"
    )
    obs.run(
        [
            "submitrequest",
            "--nodevelproject",
            "--no-cleanup",
            "-r",
            revision,
            "-m",
            message,
            project.staging,
            args.package,
            project.release,
            args.package,
        ],
        mutating=True,
    )


def check_remote_project(obs: Obs, project: Project, remote: str) -> None:
    meta = obs.api_xml(f"/source/{remote}/_meta")
    check_project_meta(project, remote, meta)
    revisions = source_revisions(obs, remote)
    missing = sorted(set(project.packages) - set(revisions))
    extra = sorted(set(revisions) - set(project.packages))
    if missing or extra:
        raise PolicyError(f"{remote}: package inventory mismatch; missing={missing}, extra={extra}")
    for target in project.targets:
        for arch in target.architectures:
            check_target_result(obs, project, remote, target, arch)


def rollback(obs: Obs, manifest: Manifest, args: argparse.Namespace) -> None:
    project = manifest.project(args.project)
    if args.package not in project.packages:
        raise PolicyError(f"{args.package} is not owned by {project.id}")
    if not re.fullmatch(r"[0-9]+|[0-9a-f]{32}", args.revision):
        raise PolicyError("rollback revision must be an OBS revision number or srcmd5")
    obs.run(
        [
            "copypac",
            "-r",
            args.revision,
            "-m",
            f"Stage rollback of {args.package} to release revision {args.revision}",
            project.release,
            args.package,
            project.staging,
            args.package,
        ],
        mutating=True,
    )
    print("NEXT: wait for staging to publish, run check, then promote the staged revision")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = result.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate", help="validate local policy and priorities")

    check = subparsers.add_parser("check", help="validate OBS projects and green build gates")
    check.add_argument("--channel", choices=("release", "staging", "all"), default="all")

    initialize = subparsers.add_parser("init-staging", help="create and seed staging projects")
    initialize.add_argument("--execute", action="store_true")

    promotion = subparsers.add_parser("promote", help="open a revision-pinned submit request")
    promotion.add_argument("project", choices=("lyra", "vega", "fina"))
    promotion.add_argument("package")
    promotion.add_argument("--revision", help="expected current staging srcmd5")
    promotion.add_argument("--test-evidence", required=True)
    promotion.add_argument("--execute", action="store_true")

    revert = subparsers.add_parser("rollback", help="copy a historic release revision to staging")
    revert.add_argument("project", choices=("lyra", "vega", "fina"))
    revert.add_argument("package")
    revert.add_argument("--revision", required=True)
    revert.add_argument("--execute", action="store_true")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        manifest = Manifest.load(args.manifest)
        check_local_priorities(manifest)
        obs = Obs(manifest.api_url, execute=getattr(args, "execute", False))
        if args.command == "validate":
            print("OK: OBS manifest and repository priorities are valid")
        elif args.command == "check":
            check_remote(obs, manifest, args.channel)
        elif args.command == "init-staging":
            init_staging(obs, manifest)
        elif args.command == "promote":
            promote(obs, manifest, args)
        elif args.command == "rollback":
            rollback(obs, manifest, args)
    except (KeyError, OSError, PolicyError, subprocess.SubprocessError, tomllib.TOMLDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
