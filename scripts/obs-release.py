#!/usr/bin/env python3
"""Validate and operate Lyra's reviewed OBS staging workflow."""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "obs/projects.toml"
IMAGE_CONFIG = ROOT / "kiwi/config.xml"
INSTALLER_DEPLOY = ROOT / "installer/src/service/operations/deploy.rs"
GOOD_PACKAGE_STATES = {"succeeded", "excluded"}
DOWNLOAD_BASE = "https://download.opensuse.org/repositories"


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
    signing_project: str
    signing_fingerprint: str
    baseline_tag: str
    approved_baselines: dict[str, dict[str, str]]
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
            signing_project=data["signing"]["project"],
            signing_fingerprint=data["signing"]["fingerprint"].replace(" ", "").upper(),
            baseline_tag=data["baseline"]["tag"],
            approved_baselines={
                project: dict(packages)
                for project, packages in data["baseline"]["projects"].items()
            },
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
        if not self.signing_project.startswith("home:rodrigosbrito"):
            raise PolicyError("signing project is outside the approved OBS namespace")
        if not re.fullmatch(r"[0-9A-F]{40}", self.signing_fingerprint):
            raise PolicyError("signing fingerprint must contain 40 hexadecimal characters")
        if not re.fullmatch(r"v[0-9A-Za-z._-]+", self.baseline_tag):
            raise PolicyError("invalid stable baseline tag")
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
            baseline = self.approved_baselines.get(project.id)
            if not baseline or not set(baseline).issubset(project.packages):
                raise PolicyError(
                    f"{project.id}: approved baseline contains unknown or no packages"
                )
            for package, revision in baseline.items():
                if not re.fullmatch(r"[0-9a-f]{32}", revision):
                    raise PolicyError(f"{project.id}/{package}: invalid baseline srcmd5")

        if set(self.approved_baselines) != ids:
            raise PolicyError("approved baseline contains unknown or missing projects")

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


class HttpDownloader:
    """Fetch public repository artifacts without using OBS credentials."""

    def __init__(
        self,
        *,
        attempts: int = 3,
        timeout: int = 120,
        opener: Any = None,
        sleeper: Any = None,
    ) -> None:
        if attempts < 1:
            raise ValueError("download attempts must be positive")
        self.attempts = attempts
        self.timeout = timeout
        self.opener = opener or urllib.request.urlopen
        self.sleeper = sleeper or time.sleep

    def get(self, url: str) -> bytes:
        request = urllib.request.Request(url, headers={"User-Agent": "lyra-obs-health/1"})
        last_error: OSError | urllib.error.URLError | None = None
        for attempt in range(1, self.attempts + 1):
            try:
                with self.opener(request, timeout=self.timeout) as response:
                    if response.status != 200:
                        raise PolicyError(
                            f"download failed: {url} returned HTTP {response.status}"
                        )
                    return response.read()
            except urllib.error.HTTPError as error:
                if 400 <= error.code < 500:
                    raise PolicyError(
                        f"download failed: {url} returned HTTP {error.code}"
                    ) from error
                last_error = error
            except (OSError, urllib.error.URLError) as error:
                last_error = error
            if attempt < self.attempts:
                self.sleeper(2 ** (attempt - 1))
        assert last_error is not None
        raise PolicyError(
            f"download failed after {self.attempts} attempts: {url}: {last_error}"
        ) from last_error


def run_checked(arguments: list[str]) -> str:
    executable = shutil.which(arguments[0])
    if executable is None:
        raise PolicyError(f"required verification command is unavailable: {arguments[0]}")
    result = subprocess.run(
        [executable, *arguments[1:]], check=False, text=True, capture_output=True
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise PolicyError(f"verification command failed: {Obs.format_command(arguments)}\n{detail}")
    return result.stdout


def key_fingerprints(key_path: Path) -> set[str]:
    output = run_checked(
        [
            "gpg",
            "--batch",
            "--with-colons",
            "--import-options",
            "show-only",
            "--import",
            str(key_path),
        ]
    )
    return {
        fields[9].upper()
        for line in output.splitlines()
        if (fields := line.split(":"))[0] == "fpr" and len(fields) > 9
    }


def repository_url(project: str, target: str) -> str:
    project_path = project.replace(":", ":/")
    return f"{DOWNLOAD_BASE}/{project_path}/{target}"


class ArtifactVerifier:
    """Verify public repository metadata and every required binary RPM."""

    def __init__(self, expected_fingerprint: str, downloader: HttpDownloader | None = None) -> None:
        self.expected_fingerprint = expected_fingerprint
        self.downloader = downloader or HttpDownloader()

    def verify_repository(self, base_url: str, rpm_filenames: list[str], arch: str) -> dict[str, Any]:
        key = self.downloader.get(f"{base_url}/repodata/repomd.xml.key")
        metadata = self.downloader.get(f"{base_url}/repodata/repomd.xml")
        signature = self.downloader.get(f"{base_url}/repodata/repomd.xml.asc")
        with tempfile.TemporaryDirectory(prefix="lyra-obs-health-") as directory:
            root = Path(directory)
            key_path = root / "repository.key"
            metadata_path = root / "repomd.xml"
            signature_path = root / "repomd.xml.asc"
            key_path.write_bytes(key)
            metadata_path.write_bytes(metadata)
            signature_path.write_bytes(signature)

            fingerprints = key_fingerprints(key_path)
            if self.expected_fingerprint not in fingerprints:
                raise PolicyError(
                    f"repository signing key mismatch for {base_url}: "
                    f"expected {self.expected_fingerprint}, got {sorted(fingerprints)}"
                )

            gpg_home = root / "gnupg"
            gpg_home.mkdir(mode=0o700)
            run_checked(["gpg", "--batch", "--homedir", str(gpg_home), "--import", str(key_path)])
            run_checked(
                [
                    "gpgv",
                    "--keyring",
                    str(gpg_home / "pubring.kbx"),
                    str(signature_path),
                    str(metadata_path),
                ]
            )

            rpmdb = root / "rpmdb"
            rpmdb.mkdir()
            run_checked(["rpmkeys", "--dbpath", str(rpmdb), "--import", str(key_path)])
            packages: list[dict[str, str | int]] = []
            for filename in sorted(rpm_filenames):
                binary_arch = "noarch" if filename.endswith(".noarch.rpm") else arch
                url = f"{base_url}/{binary_arch}/{filename}"
                payload = self.downloader.get(url)
                rpm_path = root / filename
                rpm_path.write_bytes(payload)
                run_checked(["rpmkeys", "--dbpath", str(rpmdb), "--checksig", str(rpm_path)])
                query = run_checked(
                    [
                        "rpm",
                        "-qp",
                        "--queryformat",
                        "%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}",
                        str(rpm_path),
                    ]
                )
                try:
                    name, version, rpm_arch = query.split("\t")
                except ValueError as error:
                    raise PolicyError(f"unexpected RPM metadata for {filename}: {query!r}") from error
                packages.append(
                    {
                        "filename": filename,
                        "name": name,
                        "version": version,
                        "architecture": rpm_arch,
                        "size": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(),
                        "url": url,
                        "signature": "verified",
                    }
                )
        return {
            "url": base_url,
            "metadata_signature": "verified",
            "signing_fingerprint": self.expected_fingerprint,
            "packages": packages,
        }


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


def source_information(obs: Obs, remote: str) -> dict[str, dict[str, str]]:
    root = obs.api_xml(f"/source/{remote}?view=info")
    return {
        node.attrib["package"]: {
            "revision": node.attrib.get("rev", ""),
            "srcmd5": node.attrib["srcmd5"],
            "verifymd5": node.attrib.get("verifymd5", ""),
        }
        for node in root.findall("sourceinfo")
        if ":" not in node.attrib["package"]
    }


def source_revisions(obs: Obs, remote: str) -> dict[str, str]:
    return {
        package: info["srcmd5"]
        for package, info in source_information(obs, remote).items()
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


def check_target_result(
    obs: Obs, project: Project, remote: str, target: Target, arch: str
) -> dict[str, dict[str, Any]]:
    root = obs.api_xml(
        f"/build/{remote}/_result?repository={target.name}&arch={arch}&view=status"
    )
    result = root.find("result")
    if result is None or result.attrib.get("code") != "published":
        code = "missing" if result is None else result.attrib.get("code", "unknown")
        raise PolicyError(f"{remote}/{target.name}/{arch}: not published ({code})")
    statuses = {node.attrib["package"]: node.attrib["code"] for node in result.findall("status")}
    checked: dict[str, dict[str, Any]] = {}
    for package in project.packages:
        state = statuses.get(package)
        flavors = {
            name: code for name, code in statuses.items() if name.startswith(f"{package}:")
        }
        if state == "succeeded":
            checked[package] = {"state": state, "flavors": flavors}
            continue
        if state == "excluded" and flavors and all(code == "succeeded" for code in flavors.values()):
            checked[package] = {"state": state, "flavors": flavors}
            continue
        raise PolicyError(
            f"{remote}/{target.name}/{arch}/{package}: build gate failed "
            f"(state={state!r}, flavors={flavors})"
        )
    return checked


def latest_source_revision(obs: Obs, remote: str, package: str) -> dict[str, str]:
    root = obs.api_xml(f"/source/{remote}/{package}/_history")
    revisions = root.findall("revision")
    if not revisions:
        raise PolicyError(f"{remote}/{package}: source history is empty")
    latest = revisions[-1]
    result = {
        "revision": latest.attrib.get("rev", ""),
        "srcmd5": latest.findtext("srcmd5", ""),
        "version": latest.findtext("version", ""),
        "request_id": latest.findtext("requestid", ""),
    }
    if not result["revision"] or not result["srcmd5"] or not result["version"]:
        raise PolicyError(f"{remote}/{package}: incomplete source history entry")
    return result


def validate_accepted_promotion(
    obs: Obs, project: Project, package: str, revision: dict[str, str]
) -> None:
    request_id = revision["request_id"]
    if not request_id:
        raise PolicyError(
            f"{project.release}/{package}: current revision {revision['srcmd5']} "
            "was not installed by an accepted staging submit request"
        )
    request = obs.api_xml(f"/request/{request_id}")
    state = request.find("state")
    if state is None or state.attrib.get("name") != "accepted":
        current = "missing" if state is None else state.attrib.get("name", "unknown")
        raise PolicyError(f"OBS request {request_id} is not accepted (state={current})")
    for action in request.findall("action"):
        if action.attrib.get("type") != "submit":
            continue
        source = action.find("source")
        target = action.find("target")
        accept = action.find("acceptinfo")
        if source is None or target is None or accept is None:
            continue
        if (
            source.attrib.get("project") == project.staging
            and source.attrib.get("package") == package
            and target.attrib.get("project") == project.release
            and target.attrib.get("package") == package
            and accept.attrib.get("srcmd5") == revision["srcmd5"]
        ):
            return
    raise PolicyError(
        f"{project.release}/{package}: request {request_id} does not prove promotion "
        f"of current revision {revision['srcmd5']} from {project.staging}"
    )


def release_provenance(
    obs: Obs,
    manifest: Manifest,
    project: Project,
    package: str,
    revision: dict[str, str],
) -> dict[str, Any]:
    if revision["request_id"]:
        validate_accepted_promotion(obs, project, package, revision)
        return {
            "kind": "accepted-staging-request",
            "request_id": int(revision["request_id"]),
        }
    baseline = manifest.approved_baselines[project.id].get(package)
    published_srcmd5 = revision.get("published_srcmd5", revision["srcmd5"])
    if baseline is None:
        raise PolicyError(
            f"{project.release}/{package}: current revision {published_srcmd5} has neither "
            f"an accepted staging request nor an entry in the approved "
            f"{manifest.baseline_tag} baseline"
        )
    if published_srcmd5 != baseline:
        raise PolicyError(
            f"{project.release}/{package}: current revision {published_srcmd5} has neither "
            f"an accepted staging request nor the approved {manifest.baseline_tag} baseline "
            f"revision {baseline}"
        )
    return {
        "kind": "stable-tag-baseline",
        "tag": manifest.baseline_tag,
        "srcmd5": baseline,
    }


def binary_rpms(obs: Obs, remote: str, target: Target, arch: str, package: str) -> list[str]:
    root = obs.api_xml(f"/build/{remote}/{target.name}/{arch}/{package}")
    filenames = sorted(
        node.attrib["filename"]
        for node in root.findall("binary")
        if node.attrib.get("filename", "").endswith(".rpm")
        and not node.attrib["filename"].endswith(".src.rpm")
    )
    if not filenames:
        raise PolicyError(f"{remote}/{target.name}/{arch}/{package}: no binary RPM was published")
    return filenames


def binary_build_packages(package: str, state: dict[str, Any]) -> list[str]:
    builds = [package] if state["state"] == "succeeded" else []
    builds.extend(
        flavor
        for flavor, flavor_state in sorted(state["flavors"].items())
        if flavor_state == "succeeded"
    )
    if not builds:
        raise PolicyError(f"{package}: no successful binary build was selected")
    return builds


def health_report(
    obs: Obs, manifest: Manifest, verifier: ArtifactVerifier | None = None
) -> dict[str, Any]:
    verifier = verifier or ArtifactVerifier(manifest.signing_fingerprint)
    report: dict[str, Any] = {
        "schema": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "api_url": manifest.api_url,
        "channel": "release",
        "status": "passed",
        "stable_baseline_tag": manifest.baseline_tag,
        "signing_project": manifest.signing_project,
        "signing_fingerprint": manifest.signing_fingerprint,
        "projects": [],
    }
    for project in manifest.projects:
        meta = obs.api_xml(f"/source/{project.release}/_meta")
        check_project_meta(project, project.release, meta)
        source_info = source_information(obs, project.release)
        missing = sorted(set(project.packages) - set(source_info))
        extra = sorted(set(source_info) - set(project.packages))
        if missing or extra:
            raise PolicyError(
                f"{project.release}: package inventory mismatch; missing={missing}, extra={extra}"
            )

        project_report: dict[str, Any] = {
            "id": project.id,
            "project": project.release,
            "packages": [],
            "targets": [],
        }
        for package in project.packages:
            revision = latest_source_revision(obs, project.release, package)
            published = source_info[package]
            if revision["revision"] != published["revision"]:
                raise PolicyError(
                    f"{project.release}/{package}: history revision {revision['revision']} and "
                    f"published revision {published['revision']} differ"
                )
            provenance_revision = {
                **revision,
                # Source services and multibuild expansion can make the raw
                # history MD5 differ from the published sourceinfo MD5. The
                # stable baseline pins the latter, while accepted requests
                # remain traceable through the raw history MD5.
                "published_srcmd5": published["srcmd5"],
            }
            provenance = release_provenance(
                obs, manifest, project, package, provenance_revision
            )
            project_report["packages"].append(
                {
                    "name": package,
                    "revision": revision["revision"],
                    "srcmd5": published["srcmd5"],
                    "history_srcmd5": revision["srcmd5"],
                    "verifymd5": published["verifymd5"],
                    "version": revision["version"],
                    "provenance": provenance,
                }
            )

        for target in project.targets:
            for arch in target.architectures:
                states = check_target_result(obs, project, project.release, target, arch)
                filenames: list[str] = []
                for package in project.packages:
                    for build_package in binary_build_packages(package, states[package]):
                        filenames.extend(
                            binary_rpms(
                                obs, project.release, target, arch, build_package
                            )
                        )
                repository = verifier.verify_repository(
                    repository_url(project.release, target.name), sorted(set(filenames)), arch
                )
                project_report["targets"].append(
                    {
                        "repository": target.name,
                        "architecture": arch,
                        "builds": states,
                        "public_repository": repository,
                    }
                )
        report["projects"].append(project_report)
    return report


def write_health_report(report: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=output.parent, prefix=f".{output.name}.", delete=False
    ) as stream:
        stream.write(serialized)
        temporary = Path(stream.name)
    temporary.replace(output)


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

    health = subparsers.add_parser(
        "health", help="verify release promotions, public metadata, signatures, and RPM downloads"
    )
    health.add_argument(
        "--output", type=Path, required=True, help="write the machine-readable JSON report here"
    )

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
        elif args.command == "health":
            report = health_report(obs, manifest)
            write_health_report(report, args.output)
            package_count = sum(len(project["packages"]) for project in report["projects"])
            print(
                f"OK: verified {len(report['projects'])} release projects and "
                f"{package_count} source packages; report: {args.output}"
            )
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
