#!/usr/bin/env python3
"""Export, publish, and audit reproducible Lyra KIWI image builds."""

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
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "image-build.toml"
KIWI = ROOT / "kiwi"
RELEASE = ROOT / "release.toml"
PACKAGE_SIGNING_KEY = KIWI / "keys/suse-16-package-signing.asc"
PACKAGE_SIGNING_KEY_SHA256 = "2f5f47168f5bd25efc5d1f26ebfab5a8fcba971b8d7c6dda19c0882ad8092acb"
PACKAGE_SIGNING_KEY_EXPORT = "suse-16-package-signing.asc"


class PolicyError(RuntimeError):
    """An image-build invariant was not satisfied."""


@dataclasses.dataclass(frozen=True)
class ObsPath:
    project: str
    repository: str


@dataclasses.dataclass(frozen=True)
class Manifest:
    image_name: str
    description: str
    architecture: str
    required_flavor: str
    optional_flavors: tuple[str, ...]
    api_url: str
    project: str
    package: str
    repository: str
    maintainer: str
    paths: tuple[ObsPath, ...]
    required_artifacts: tuple[str, ...]

    @classmethod
    def load(cls, path: Path = DEFAULT_MANIFEST) -> "Manifest":
        with path.open("rb") as stream:
            data = tomllib.load(stream)
        if data.get("schema") != 1:
            raise PolicyError("image manifest schema must be 1")
        image, obs = data["image"], data["obs"]
        result = cls(
            image_name=image["name"],
            description=image["description"],
            architecture=image["architecture"],
            required_flavor=image["required_flavor"],
            optional_flavors=tuple(image["optional_flavors"]),
            api_url=obs["api_url"],
            project=obs["project"],
            package=obs["package"],
            repository=obs["repository"],
            maintainer=obs["maintainer"],
            paths=tuple(ObsPath(**item) for item in obs["paths"]),
            required_artifacts=tuple(data["artifacts"]["required"]),
        )
        result.validate()
        return result

    def validate(self) -> None:
        if self.api_url != "https://api.opensuse.org":
            raise PolicyError("only the canonical HTTPS OBS API is allowed")
        if not self.project.startswith("home:rodrigosbrito:"):
            raise PolicyError("image project is outside the approved OBS namespace")
        identifiers = (self.image_name, self.architecture, self.required_flavor, self.package)
        if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", value) for value in identifiers):
            raise PolicyError("invalid image identifier")
        if self.description != f"{self.package}.kiwi":
            raise PolicyError("OBS description must be named after the package with a .kiwi suffix")
        flavors = (self.required_flavor, *self.optional_flavors)
        if len(set(flavors)) != len(flavors):
            raise PolicyError("image flavors must be unique")
        if self.required_flavor != "standard" or "nvidia" not in self.optional_flavors:
            raise PolicyError("standard must be required and nvidia must remain optional")
        if len(self.paths) < 4 or len(set(self.paths)) != len(self.paths):
            raise PolicyError("OBS build paths are incomplete or duplicated")
        if set(self.required_artifacts) != {"iso", "packages", "verified", "changes", "kiwi_result"}:
            raise PolicyError("artifact policy is incomplete")


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


def release_values() -> dict[str, object]:
    with RELEASE.open("rb") as stream:
        return tomllib.load(stream)["release"]


def version_id() -> str:
    release = release_values()
    if release["stage"] == "release":
        return str(release["calendar_version"])
    return f'{release["calendar_version"]}-{release["stage"]}{release["iteration"]}'


def canonical_xml() -> ET.ElementTree:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.parse(KIWI / "config.xml", parser=parser)


def validate_sources(manifest: Manifest) -> None:
    root = canonical_xml().getroot()
    if root.attrib.get("name") != manifest.image_name:
        raise PolicyError("KIWI image name differs from image-build.toml")
    version = root.findtext("preferences/version")
    if version != version_id():
        raise PolicyError(f"KIWI version {version!r} differs from release.toml")
    if root.findtext("preferences/rpm-check-signatures") != "true":
        raise PolicyError("KIWI must reject packages with invalid signatures")
    repositories = root.findall("repository")
    if len(repositories) != 5:
        raise PolicyError("canonical KIWI description must contain exactly five repositories")
    aliases: set[str] = set()
    for repository in repositories:
        alias = repository.attrib.get("alias", "")
        source = repository.find("source")
        url = "" if source is None else source.attrib.get("path", "")
        if alias in aliases or not alias:
            raise PolicyError(f"missing or duplicate repository alias: {alias!r}")
        aliases.add(alias)
        if not url.startswith("https://") or ":staging" in url:
            raise PolicyError(f"unsafe installed-image repository: {url}")
        for option in ("repository_gpgcheck", "package_gpgcheck"):
            if repository.attrib.get(option) != "true":
                raise PolicyError(f"{alias}: {option} must be true")
    config = (KIWI / "config.sh").read_text(encoding="utf-8")
    forbidden = ("curl ", "wget ", "flatpak remote-add", "obsrepositories:/")
    for token in forbidden:
        if token in config:
            raise PolicyError(f"network-dependent build command is forbidden: {token.strip()}")
    flathub = KIWI / "root/etc/flatpak/remotes.d/flathub.flatpakrepo"
    if "GPGKey=" not in flathub.read_text(encoding="utf-8"):
        raise PolicyError("versioned Flathub remote or signing key is missing")
    if sha256(PACKAGE_SIGNING_KEY) != PACKAGE_SIGNING_KEY_SHA256:
        raise PolicyError("Leap 16 package-signing keyring differs from the reviewed checksum")


def source_metadata(commit: str, dirty: bool) -> tuple[dict[str, object], str]:
    try:
        full_commit = git("rev-parse", f"{commit}^{{commit}}")
        epoch = int(git("show", "-s", "--format=%ct", full_commit))
    except subprocess.CalledProcessError as error:
        raise PolicyError(f"unknown source commit: {commit}") from error
    built_at = dt.datetime.fromtimestamp(epoch, dt.timezone.utc).isoformat().replace("+00:00", "Z")
    document = {
        "schema_version": 1,
        "commit": full_commit,
        "dirty": dirty,
        "source_epoch": epoch,
        "image_built_at": built_at,
    }
    environment = (
        "# Generated by scripts/image-build.py; do not edit.\n"
        f"LYRA_BUILD_SOURCE_COMMIT='{full_commit}'\n"
        f"LYRA_BUILD_SOURCE_DIRTY='{int(dirty)}'\n"
        f"LYRA_BUILD_SOURCE_EPOCH='{epoch}'\n"
        f"LYRA_IMAGE_BUILT_AT='{built_at}'\n"
    )
    return document, environment


def render_obs_config(manifest: Manifest) -> bytes:
    tree = canonical_xml()
    root = tree.getroot()
    root.insert(0, ET.Comment(" OBS-Profiles: @BUILD_FLAVOR@ "))
    profiles = ET.Element("profiles")
    ET.SubElement(
        profiles,
        "profile",
        {"name": manifest.required_flavor, "description": "Lyra OS standard image", "import": "true"},
    )
    for flavor in manifest.optional_flavors:
        ET.SubElement(
            profiles,
            "profile",
            {"name": flavor, "description": f"Lyra OS {flavor} image"},
        )
    description_index = next(index for index, node in enumerate(root) if node.tag == "description")
    root.insert(description_index + 1, profiles)
    for repository in root.findall("repository"):
        repository.attrib.pop("imageinclude", None)
        repository.set("imageonly", "true")
        if repository.attrib.get("alias") == "repo-oss":
            source = repository.find("source")
            if source is None:
                raise PolicyError("repo-oss has no source element")
            ET.SubElement(
                source,
                "signing",
                {"key": f"file:///usr/src/packages/SOURCES/{PACKAGE_SIGNING_KEY_EXPORT}"},
            )
    build_repository = ET.Element("repository", {"alias": "obs-build", "type": "rpm-md"})
    ET.SubElement(build_repository, "source", {"path": "obsrepositories:/"})
    first_packages = next(index for index, node in enumerate(root) if node.tag == "packages")
    root.insert(first_packages, build_repository)
    ET.indent(tree, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"


def ensure_export_target(destination: Path) -> None:
    if destination.exists() and any(destination.iterdir()):
        raise PolicyError(f"export destination is not empty: {destination}")
    destination.mkdir(parents=True, exist_ok=True)


def export(manifest: Manifest, destination: Path, commit: str, allow_dirty: bool) -> None:
    validate_sources(manifest)
    dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
    if dirty and not allow_dirty:
        raise PolicyError("working tree is dirty; commit the image sources before export")
    metadata, environment = source_metadata(commit, dirty)
    if metadata["commit"] != git("rev-parse", "HEAD"):
        raise PolicyError("--commit must identify the currently checked-out HEAD")
    ensure_export_target(destination)
    for name in ("config.sh",):
        shutil.copy2(KIWI / name, destination / name)
    shutil.copy2(PACKAGE_SIGNING_KEY, destination / PACKAGE_SIGNING_KEY_EXPORT)
    shutil.copytree(KIWI / "root", destination / "root", symlinks=True)
    (destination / manifest.description).write_bytes(render_obs_config(manifest))
    (destination / "build-source.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    embedded = destination / "root/usr/lib/lyra-os/build-source"
    embedded.parent.mkdir(parents=True, exist_ok=True)
    embedded.write_text(environment, encoding="utf-8")
    multibuild = ET.Element("multibuild")
    ET.SubElement(multibuild, "flavor").text = manifest.required_flavor
    ET.indent(multibuild, space="  ")
    (destination / "_multibuild").write_text(
        ET.tostring(multibuild, encoding="unicode") + "\n", encoding="utf-8"
    )
    print(destination)


def verify_export(manifest: Manifest, directory: Path) -> None:
    metadata = json.loads((directory / "build-source.json").read_text(encoding="utf-8"))
    if metadata.get("dirty") is not False or not re.fullmatch(r"[0-9a-f]{40}", metadata.get("commit", "")):
        raise PolicyError("export has invalid source identity")
    root = ET.parse(directory / manifest.description).getroot()
    profiles = {node.attrib["name"]: node.attrib for node in root.findall("profiles/profile")}
    if profiles.get(manifest.required_flavor, {}).get("import") != "true":
        raise PolicyError("standard profile is not the imported default")
    flavors = [node.text for node in ET.parse(directory / "_multibuild").getroot().findall("flavor")]
    if flavors != [manifest.required_flavor]:
        raise PolicyError("optional NVIDIA flavor must not gate the standard image")
    build_repos = [
        node for node in root.findall("repository")
        if node.find("source") is not None and node.find("source").attrib.get("path") == "obsrepositories:/"
    ]
    if len(build_repos) != 1:
        raise PolicyError("export must have one OBS-injected build repository")
    repo_oss = root.find("repository[@alias='repo-oss']")
    signing = None if repo_oss is None else repo_oss.find("source/signing")
    expected_key = f"file:///usr/src/packages/SOURCES/{PACKAGE_SIGNING_KEY_EXPORT}"
    if signing is None or signing.attrib.get("key") != expected_key:
        raise PolicyError("preserved repository lacks the pinned Leap 16 signing keyring")
    if sha256(directory / PACKAGE_SIGNING_KEY_EXPORT) != PACKAGE_SIGNING_KEY_SHA256:
        raise PolicyError("exported Leap 16 signing keyring failed its checksum")
    installed = [node for node in root.findall("repository") if node.attrib.get("alias") != "obs-build"]
    if len(installed) != 5 or any(node.attrib.get("imageonly") != "true" for node in installed):
        raise PolicyError("installed repositories must be isolated from OBS build resolution")
    embedded = directory / "root/usr/lib/lyra-os/build-source"
    if metadata["commit"] not in embedded.read_text(encoding="utf-8"):
        raise PolicyError("embedded source identity differs from export manifest")
    print(f"OK: deterministic {manifest.required_flavor} export at {metadata['commit']}")


def project_meta(manifest: Manifest) -> str:
    root = ET.Element("project", {"name": manifest.project})
    ET.SubElement(root, "title").text = "Lyra OS image staging"
    ET.SubElement(root, "description").text = "Reproducible KIWI image builds from committed Lyra sources."
    ET.SubElement(root, "person", {"userid": manifest.maintainer, "role": "maintainer"})
    publish = ET.SubElement(root, "publish")
    ET.SubElement(publish, "enable", {"repository": manifest.repository, "arch": manifest.architecture})
    repository = ET.SubElement(root, "repository", {"name": manifest.repository})
    for path in manifest.paths:
        ET.SubElement(repository, "path", dataclasses.asdict(path))
    ET.SubElement(repository, "arch").text = manifest.architecture
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode") + "\n"


def package_meta(manifest: Manifest) -> str:
    root = ET.Element("package", {"name": manifest.package, "project": manifest.project})
    ET.SubElement(root, "title").text = "Lyra OS KIWI image"
    ET.SubElement(root, "description").text = "Versioned source for the standard Lyra OS ISO."
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="unicode") + "\n"


def project_config() -> str:
    # RPM repositories otherwise default to spec recipes; image URLs should
    # also remain stable across rebuilds. OBS deliberately refuses ambiguous
    # providers, so keep the two Leap branding choices explicit.
    return (
        "Type: kiwi\n"
        "Repotype: staticlinks\n"
        "Prefer: plymouth-branding-openSUSE\n"
        "Prefer: MozillaFirefox-branding-openSUSE\n"
    )


def run(command: list[str], *, cwd: Path | None = None) -> str:
    result = subprocess.run(command, cwd=cwd or ROOT, text=True, capture_output=True)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise PolicyError(f"command failed: {' '.join(command)}\n{detail}")
    return result.stdout


def publish(manifest: Manifest, execute: bool) -> None:
    validate_sources(manifest)
    if git("status", "--porcelain", "--untracked-files=normal"):
        raise PolicyError("publish requires a clean committed working tree")
    commit = git("rev-parse", "HEAD")
    if not execute:
        print(f"PLAN: create/update OBS project {manifest.project}")
        print(f"PLAN: export commit {commit} to {manifest.package}")
        print(f"PLAN: build only required flavor {manifest.required_flavor}")
        return
    osc = ["osc", "-A", manifest.api_url]
    with tempfile.TemporaryDirectory(prefix="lyra-image-") as temporary_name:
        temporary = Path(temporary_name)
        exported = temporary / "export"
        export(manifest, exported, commit, allow_dirty=False)
        project_file = temporary / "project.xml"
        package_file = temporary / "package.xml"
        project_config_file = temporary / "project.conf"
        project_file.write_text(project_meta(manifest), encoding="utf-8")
        package_file.write_text(package_meta(manifest), encoding="utf-8")
        project_config_file.write_text(project_config(), encoding="utf-8")
        run([*osc, "meta", "prj", manifest.project, "-F", str(project_file)])
        run([*osc, "meta", "prjconf", manifest.project, "-F", str(project_config_file)])
        run([*osc, "meta", "pkg", manifest.project, manifest.package, "-F", str(package_file)])
        checkout_root = temporary / "checkout"
        checkout_root.mkdir()
        checkout = checkout_root / "package"
        run(
            [*osc, "checkout", manifest.project, manifest.package, "--output-dir", str(checkout)],
            cwd=checkout_root,
        )
        if not (checkout / ".osc/_package").is_file():
            raise PolicyError("could not identify the OBS package checkout")
        for child in checkout.iterdir():
            if child.name != ".osc":
                if child.is_dir() and not child.is_symlink():
                    shutil.rmtree(child)
                else:
                    child.unlink()
        for child in exported.iterdir():
            target = checkout / child.name
            if child.is_dir():
                shutil.copytree(child, target, symlinks=True)
            else:
                shutil.copy2(child, target)
        run([*osc, "addremove"], cwd=checkout)
        run([*osc, "commit", "-m", f"Build Lyra OS image from Git {commit}"], cwd=checkout)
    print(f"OK: published {manifest.project}/{manifest.package} from {commit}")


def remote_check(manifest: Manifest) -> None:
    osc = ["osc", "-A", manifest.api_url, "api"]
    meta = ET.fromstring(run([*osc, f"/source/{manifest.project}/_meta"]))
    repository = meta.find(f"repository[@name='{manifest.repository}']")
    if repository is None:
        raise PolicyError("OBS image repository is missing")
    paths = tuple(ObsPath(**node.attrib) for node in repository.findall("path"))
    arches = tuple(node.text for node in repository.findall("arch"))
    if paths != manifest.paths or arches != (manifest.architecture,):
        raise PolicyError("OBS paths or architecture differ from image-build.toml")
    query = (
        f"/build/{manifest.project}/_result?repository={manifest.repository}"
        f"&arch={manifest.architecture}&view=status"
    )
    result = ET.fromstring(run([*osc, query])).find("result")
    if result is None or result.attrib.get("code") != "published":
        state = "missing" if result is None else result.attrib.get("code", "unknown")
        raise PolicyError(f"OBS image repository is not published ({state})")
    statuses = {node.attrib["package"]: node.attrib["code"] for node in result.findall("status")}
    standard = f"{manifest.package}:{manifest.required_flavor}"
    if statuses.get(standard) != "succeeded":
        raise PolicyError(f"required image build did not succeed: {statuses.get(standard)!r}")
    nvidia = f"{manifest.package}:nvidia"
    if nvidia in statuses:
        raise PolicyError("optional NVIDIA build unexpectedly gates Beta 2")
    print(f"OK: {standard} succeeded and {nvidia} remains independent")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def one(directory: Path, pattern: str, role: str) -> Path:
    matches = list(directory.glob(pattern))
    if len(matches) != 1:
        raise PolicyError(f"expected one {role} artifact matching {pattern}, found {len(matches)}")
    return matches[0]


def artifact_manifest(manifest: Manifest, directory: Path, output: Path, tests: list[str]) -> None:
    roles = {
        "iso": one(directory, "*.iso", "ISO"),
        "packages": one(directory, "*.packages", "package revision list"),
        "verified": one(directory, "*.verified", "verification report"),
        "changes": one(directory, "*.changes", "change log"),
        "kiwi_result": one(directory, "kiwi.result.json", "KIWI result"),
    }
    package_rows = [line.split("|") for line in roles["packages"].read_text(encoding="utf-8").splitlines() if line]
    if any(len(row) != 8 for row in package_rows):
        raise PolicyError("KIWI package manifest has an unexpected format")
    if not package_rows or any(not row[5] for row in package_rows):
        raise PolicyError("exact source revisions are missing from the package manifest")
    test_results: dict[str, dict[str, object]] = {}
    for item in tests:
        if "=" not in item:
            raise PolicyError("--test-result must use NAME=FILE")
        name, filename = item.split("=", 1)
        path = Path(filename).resolve()
        if not name or not path.is_file():
            raise PolicyError(f"invalid test result: {item}")
        test_results[name] = {"filename": path.name, "sha256": sha256(path), "size_bytes": path.stat().st_size}
    document = {
        "schema_version": 1,
        "product": manifest.image_name,
        "version": version_id(),
        "source": {"commit": git("rev-parse", "HEAD"), "dirty": bool(git("status", "--porcelain"))},
        "package_count": len(package_rows),
        "packages": [
            {"name": row[0], "epoch": row[1], "version": row[2], "release": row[3], "arch": row[4], "source": row[5], "source_package": row[6], "license": row[7]}
            for row in package_rows
        ],
        "artifacts": {
            role: {"filename": path.name, "sha256": sha256(path), "size_bytes": path.stat().st_size}
            for role, path in roles.items()
        },
        "test_results": test_results,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.new")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(output)
    print(output)


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    commands = cli.add_subparsers(dest="command", required=True)
    commands.add_parser("validate")
    export_command = commands.add_parser("export")
    export_command.add_argument("destination", type=Path)
    export_command.add_argument("--commit", default="HEAD")
    export_command.add_argument("--allow-dirty", action="store_true")
    verify = commands.add_parser("verify-export")
    verify.add_argument("directory", type=Path)
    publish_command = commands.add_parser("publish")
    publish_command.add_argument("--execute", action="store_true")
    commands.add_parser("check-remote")
    artifacts = commands.add_parser("artifact-manifest")
    artifacts.add_argument("directory", type=Path)
    artifacts.add_argument("--output", required=True, type=Path)
    artifacts.add_argument("--test-result", action="append", default=[])
    return cli


def main() -> int:
    args = parser().parse_args()
    try:
        manifest = Manifest.load(args.manifest)
        if args.command == "validate":
            validate_sources(manifest)
            print("OK: image sources, repositories, signatures, and flavors are valid")
        elif args.command == "export":
            export(manifest, args.destination, args.commit, args.allow_dirty)
        elif args.command == "verify-export":
            verify_export(manifest, args.directory)
        elif args.command == "publish":
            publish(manifest, args.execute)
        elif args.command == "check-remote":
            remote_check(manifest)
        else:
            artifact_manifest(manifest, args.directory, args.output, args.test_result)
    except (KeyError, OSError, PolicyError, subprocess.SubprocessError, tomllib.TOMLDecodeError, ET.ParseError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
