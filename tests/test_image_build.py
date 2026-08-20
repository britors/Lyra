from __future__ import annotations

import dataclasses
import importlib.util
import json
import stat
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lyra_image_build", ROOT / "scripts/image-build.py")
assert SPEC and SPEC.loader
image_build = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = image_build
SPEC.loader.exec_module(image_build)


class ImagePolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = image_build.Manifest.load()

    def test_recovery_editors_are_available_in_every_profile(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        shared_image_packages = {
            package.attrib["name"]
            for packages in root.findall("packages")
            if packages.attrib.get("type") == "image"
            and "profiles" not in packages.attrib
            for package in packages.findall("package")
        }
        self.assertTrue({"vim", "neovim", "nano"}.issubset(shared_image_packages))

    def test_man_is_available_in_every_profile(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        shared_image_packages = {
            package.attrib["name"]
            for packages in root.findall("packages")
            if packages.attrib.get("type") == "image"
            and "profiles" not in packages.attrib
            for package in packages.findall("package")
        }
        self.assertIn("man", shared_image_packages)

    def test_zypper_cache_policy_matches_vega_update_flow(self) -> None:
        config = (
            ROOT / "kiwi/root/etc/zypp/zypp.conf.d/90-lyra-refresh.conf"
        ).read_text(encoding="utf-8")
        self.assertIn("repo.refresh.delay = 2880", config)
        self.assertIn("download.max_concurrent_connections = 5", config)
        self.assertIn("download.use_deltarpm = false", config)

    def test_localsearch_failure_is_contained(self) -> None:
        preflight = ROOT / "kiwi/root/usr/libexec/lyra-localsearch-preflight"
        self.assertTrue(preflight.stat().st_mode & stat.S_IXUSR)
        script = preflight.read_text(encoding="utf-8")
        self.assertIn("localsearch-extractor-3", script)
        self.assertIn("=> not found", script)

        drop_in = (
            ROOT
            / "kiwi/root/usr/lib/systemd/user/localsearch-3.service.d/90-lyra-stability.conf"
        ).read_text(encoding="utf-8")
        for policy in (
            "ExecStartPre=/usr/libexec/lyra-localsearch-preflight",
            "StartLimitBurst=3",
            "CPUWeight=10",
            "MemoryHigh=512M",
            "MemoryMax=1G",
            "TasksMax=64",
            "LogRateLimitBurst=100",
        ):
            self.assertIn(policy, drop_in)

    def test_vega_update_indicator_is_enabled_by_default(self) -> None:
        override = (
            ROOT
            / "kiwi/root/usr/share/glib-2.0/schemas/99-lyra-sheliak.gschema.override"
        ).read_text(encoding="utf-8")
        self.assertIn("sheliak@lyraos.org", override)
        self.assertIn("updates-indicator@lyraos.org", override)

        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            package.attrib["name"]
            for packages in root.findall("packages")
            if packages.attrib.get("profiles") == "desktop"
            for package in packages.findall("package")
        }
        self.assertIn("vega-gtk", desktop_packages)

    def test_canonical_sources_pass_repository_and_signature_policy(self) -> None:
        image_build.validate_sources(self.manifest)

    def test_personal_obs_repository_is_desktop_only_and_low_precedence(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        repository = root.find("repository[@alias='repo-rodrigosbrito']")
        self.assertIsNotNone(repository)
        assert repository is not None
        self.assertEqual(repository.attrib["profiles"], "desktop")
        self.assertEqual(repository.attrib["priority"], "90")
        self.assertEqual(
            repository.find("source").attrib["path"],
            "https://download.opensuse.org/repositories/home:/rodrigosbrito/openSUSE_Leap_16.0/",
        )

    def test_release_evidence_tools_are_executable(self) -> None:
        for name in (
            "lyra-hardware-matrix",
            "lyra-live-smoke",
            "lyra-performance",
            "lyra-report",
            "lyra-system-smoke",
            "lyra-update-smoke",
        ):
            path = ROOT / "kiwi/root/usr/bin" / name
            self.assertTrue(path.is_file(), name)
            self.assertNotEqual(path.stat().st_mode & 0o111, 0, name)

    def test_installer_identity_matches_tauri_desktop_and_rpm(self) -> None:
        image_build.validate_installer_identity()

        config = json.loads(
            (ROOT / "installer/src-tauri/tauri.conf.json").read_text(encoding="utf-8")
        )
        self.assertEqual(config["identifier"], image_build.INSTALLER_APP_ID)
        self.assertTrue(config["app"]["enableGTKAppId"])

    def test_obs_is_restricted_to_ordered_rpm_package_sources(self) -> None:
        self.assertEqual(self.manifest.obs_role, "packages-only")
        projects = [source.project for source in self.manifest.package_sources]
        self.assertEqual(projects[0], "home:rodrigosbrito:lyra")
        self.assertEqual(projects[-1], "Virtualization:Appliances:Builder")
        self.assertFalse(hasattr(self.manifest, "project"))
        self.assertFalse(hasattr(self.manifest, "package"))

    def test_distribution_policy_uses_github_and_sourceforge(self) -> None:
        self.assertEqual(self.manifest.source_repository, "https://github.com/britors/Lyra")
        self.assertEqual(self.manifest.iso_provider, "sourceforge")
        help_text = image_build.parser().format_help()
        self.assertNotIn("publish", help_text)
        self.assertNotIn("check-remote", help_text)

    def test_manifest_rejects_an_obs_image_publication_target(self) -> None:
        source = (ROOT / "image-build.toml").read_text(encoding="utf-8")
        source = source.replace(
            'role = "packages-only"',
            'project = "home:rodrigosbrito:lyra:images"\nrole = "packages-only"',
        )
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "image-build.toml"
            manifest.write_text(source, encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "publication targets"):
                image_build.Manifest.load(manifest)

    def test_live_module_is_part_of_the_installed_image(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        image_packages = root.find("packages[@type='image']")
        assert image_packages is not None
        self.assertIsNotNone(image_packages.find("package[@name='dracut-kiwi-live']"))
        self.assertIsNone(root.find("packages[@type='iso']/package[@name='dracut-kiwi-live']"))

    def test_desktop_image_has_emoji_and_microsoft_compatible_fonts(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        packages = {node.attrib["name"] for node in root.findall("packages/package")}
        self.assertIn("google-noto-coloremoji-fonts", packages)
        self.assertIn("liberation-fonts", packages)
        self.assertIn("google-carlito-fonts", packages)
        self.assertIn("google-noto-sans-cjk-fonts", packages)

    def test_fish_and_nvm_are_available_only_in_the_desktop_profile(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        shared = next(
            packages
            for packages in root.findall("packages")
            if packages.attrib.get("type") == "image" and "profiles" not in packages.attrib
        )
        desktop = root.find("packages[@type='image'][@profiles='desktop']")
        server = root.find("packages[@type='image'][@profiles='server']")
        assert desktop is not None
        assert server is not None

        for package in ("fish", "nvm-fish", "git", "linuxtoys", "lyra-welcome"):
            self.assertIsNotNone(desktop.find(f"package[@name='{package}']"))
            self.assertIsNone(shared.find(f"package[@name='{package}']"))
            self.assertIsNone(server.find(f"package[@name='{package}']"))

        live_user = root.find("users[@profiles='desktop']/user[@name='liveuser']")
        assert live_user is not None
        self.assertEqual(live_user.attrib["shell"], "/usr/bin/fish")

        prompt = ROOT / "kiwi/root/usr/share/fish/vendor_functions.d/fish_prompt.fish"
        defaults = ROOT / "kiwi/root/usr/share/fish/vendor_conf.d/lyra-defaults.fish"
        self.assertTrue(prompt.is_file())
        self.assertTrue(defaults.is_file())

        deploy = (
            ROOT / "installer/src/service/operations/deploy.rs"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'const DEFAULT_DESKTOP_SHELL: &str = "/usr/bin/fish";', deploy
        )
        self.assertIn("DEFAULT_DESKTOP_SHELL.to_string()", deploy)
        self.assertNotIn("ConfigureUserBashrc", deploy)
        self.assertNotIn('join(".bashrc")', deploy)

        spec = (ROOT / "packaging/linuxtoys/linuxtoys.spec").read_text(
            encoding="utf-8"
        )
        patch = (
            ROOT / "packaging/linuxtoys/linuxtoys-disable-self-update.patch"
        ).read_text(encoding="utf-8")
        self.assertIn("Requires:       git", spec)
        self.assertIn("upstream self-update bypasses RPM ownership", spec)
        self.assertIn("LinuxToys is managed by Lyra OS", patch)

    def test_fish_z_state_is_always_owned_by_the_logged_in_user(self) -> None:
        early_defaults = (
            ROOT / "kiwi/root/etc/fish/conf.d/00-lyra-home.fish"
        ).read_text()
        image_config = (ROOT / "kiwi/config.sh").read_text()

        self.assertIn('set -gx Z_DATA_DIR "$XDG_DATA_HOME/z"', early_defaults)
        self.assertIn('set -gx Z_DATA "$Z_DATA_DIR/data"', early_defaults)
        self.assertNotIn("_ZO_DATA_DIR", early_defaults)
        self.assertIn("SETUVAR Z_DATA:/root/", image_config)
        self.assertIn("SETUVAR Z_DATA_DIR:/root/", image_config)

    def test_beta_two_uses_only_the_rust_installer(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        packages = {node.attrib["name"] for node in root.findall("packages/package")}
        self.assertIn("lyra-installer", packages)
        self.assertNotIn("calamares", packages)
        self.assertFalse((ROOT / "kiwi/root/etc/calamares").exists())
        self.assertFalse(
            (ROOT / "kiwi/root/usr/share/applications/calamares.desktop").exists()
        )

        autostart = (
            ROOT / "kiwi/root/etc/xdg/autostart/lyra-installer-autostart.desktop"
        ).read_text(encoding="utf-8")
        self.assertIn("TryExec=/usr/bin/lyra-installer", autostart)
        self.assertIn("Exec=/usr/bin/lyra-install-lock /usr/bin/lyra-installer", autostart)
        self.assertIn("StartupWMClass=lyra-installer", autostart)

        self.assertNotIn("pkexec", autostart)

        packaged_wrapper = ROOT / "installer/packaging/lyra-install-lock"
        image_wrapper = ROOT / "kiwi/root/usr/bin/lyra-install-lock"
        self.assertEqual(image_wrapper.read_bytes(), packaged_wrapper.read_bytes())
        wrapper = image_wrapper.read_text(encoding="utf-8")
        self.assertIn("XDG_RUNTIME_DIR", wrapper)
        self.assertNotIn("/run/lock/lyra-install.lock", wrapper)
        self.assertNotEqual(image_wrapper.stat().st_mode & 0o111, 0)

        packaged_launcher = ROOT / "installer/packaging/org.lyraos.LyraInstaller.desktop"
        image_launcher = (
            ROOT
            / "kiwi/root/usr/share/applications/org.lyraos.LyraInstaller.desktop"
        )
        self.assertEqual(image_launcher.read_bytes(), packaged_launcher.read_bytes())

        packaged_icon = ROOT / "installer/src-tauri/icons/256x256.png"
        image_icon = (
            ROOT
            / "kiwi/root/usr/share/icons/hicolor/256x256/apps"
            / "org.lyraos.LyraInstaller.png"
        )
        self.assertEqual(image_icon.read_bytes(), packaged_icon.read_bytes())

        live_smoke = ROOT / "kiwi/root/usr/bin/lyra-live-smoke"
        self.assertTrue(live_smoke.is_file())
        self.assertNotEqual(live_smoke.stat().st_mode & 0o111, 0)
        deploy = (ROOT / "installer/src/service/operations/deploy.rs").read_text(
            encoding="utf-8"
        )
        self.assertIn('"usr/bin/lyra-live-smoke"', deploy)

        update_smoke = ROOT / "kiwi/root/usr/bin/lyra-update-smoke"
        self.assertTrue(update_smoke.is_file())
        self.assertNotEqual(update_smoke.stat().st_mode & 0o111, 0)

    def test_installed_desktop_sudo_uses_the_user_password(self) -> None:
        deploy = (ROOT / "installer/src/service/operations/deploy.rs").read_text(
            encoding="utf-8"
        )
        changes = (ROOT / "installer/packaging/lyra-installer.changes").read_text(
            encoding="utf-8"
        )

        self.assertIn('"Defaults !targetpw\\n%wheel ALL=(ALL) ALL\\n"', deploy)
        self.assertIn("Defaults targetpw", changes)

    def test_chord_is_not_installed_or_pinned_on_the_desktop(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall("packages")
            if packages.attrib.get("profiles") in (None, "desktop")
            for node in packages.findall("package")
        }
        self.assertNotIn("chord", desktop_packages)

        defaults = (
            ROOT
            / "kiwi/root/usr/share/glib-2.0/schemas/99-lyra-desktop-defaults.gschema.override"
        ).read_text(encoding="utf-8")
        self.assertNotIn("'org.lyraos.Chord.desktop'", defaults)

    def test_bluetooth_and_screen_recording_are_installed_and_enabled(self) -> None:
        # Real gap found on an installed image: onlyRequired dropped both
        # (neither is a hard Requires of gnome_basic/gnome), so Bluetooth
        # never turned on and GNOME Shell's Ctrl+Shift+Alt+R screen
        # recorder silently failed while plain screenshots (a different,
        # non-GStreamer code path) kept working. Desktop-only: the server
        # profile is headless (docs/server-edition.md).
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="desktop"]')
            for node in packages.findall("package")
        }
        server_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="server"]')
            for node in packages.findall("package")
        }
        for name in ("bluez", "bluez-firmware", "gnome-bluetooth", "gstreamer-plugins-good"):
            self.assertIn(name, desktop_packages, name)
            self.assertNotIn(name, server_packages, name)

        config_sh = (ROOT / "kiwi/config.sh").read_text(encoding="utf-8")
        # Must be inside the desktop-only display-manager block, not the
        # shared/server path (config.sh runs once per profile build).
        desktop_branch = config_sh[
            config_sh.index("# Display manager") : config_sh.index("# zram-generator")
        ]
        self.assertIn("suseInsertService bluetooth", desktop_branch)

    def test_desktop_installs_upower_for_battery_status(self) -> None:
        # onlyRequired kept libupower but omitted the daemon on Alpha 3. The
        # kernel exposed BAT1 normally, yet GNOME had no service from which to
        # obtain battery state and therefore displayed no battery icon.
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="desktop"]')
            for node in packages.findall("package")
        }
        server_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="server"]')
            for node in packages.findall("package")
        }
        self.assertIn("upower", desktop_packages)
        self.assertNotIn("upower", server_packages)

    def test_desktop_installs_explicit_alsa_userspace_stack(self) -> None:
        # PipeWire remains the desktop audio server, while these packages
        # provide ALSA hardware profiles, diagnostics and compatibility for
        # applications that do not use PipeWire directly. Keep the set
        # desktop-only instead of growing the headless Server image.
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="desktop"]')
            for node in packages.findall("package")
        }
        server_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="server"]')
            for node in packages.findall("package")
        }
        alsa_packages = {
            "alsa",
            "alsa-oss",
            "alsa-plugins",
            "alsa-plugins-speexrate",
            "alsa-plugins-upmix",
            "alsa-ucm-conf",
            "alsa-utils",
            "libatopology2",
        }
        self.assertTrue(alsa_packages.issubset(desktop_packages))
        self.assertTrue(alsa_packages.isdisjoint(server_packages))

    def test_mozilla_apps_follow_installed_system_locale(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="desktop"]')
            for node in packages.findall("package")
        }
        self.assertIn("MozillaFirefox", desktop_packages)
        self.assertIn("MozillaFirefox-translations-common", desktop_packages)
        self.assertNotIn("MozillaFirefox-translations-other", desktop_packages)
        self.assertIn("MozillaThunderbird", desktop_packages)
        self.assertIn("MozillaThunderbird-translations-common", desktop_packages)
        self.assertNotIn("MozillaThunderbird-translations-other", desktop_packages)

        image_config = (ROOT / "kiwi/config.xml").read_text(encoding="utf-8")
        for locale in ("en_US", "pt_BR", "es_ES"):
            self.assertIn(locale, image_config)

        locales = root.findtext("preferences/locale")
        self.assertEqual(locales, "en_US,pt_BR,es_ES")

        installer_core = (ROOT / "installer/src/lib.rs").read_text(encoding="utf-8")
        self.assertIn('"pt_BR.UTF-8" | "en_US.UTF-8" | "es_ES.UTF-8"', installer_core)
        deploy = (
            ROOT / "installer/src/service/operations/deploy.rs"
        ).read_text(encoding="utf-8")
        self.assertIn('etc.join("locale.conf")', deploy)

        policies = json.loads(
            (
                ROOT
                / "kiwi/root/usr/lib64/firefox/distribution/policies.json"
            ).read_text(encoding="utf-8")
        )
        preferences = policies["policies"].get("Preferences", {})
        self.assertNotIn("intl.locale.requested", preferences)

    def test_office_apps_and_locales_match_image_policy(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        packages = {node.attrib["name"] for node in root.findall("packages/package")}
        libreoffice = {
            "libreoffice",
            "libreoffice-base",
            "libreoffice-calc",
            "libreoffice-draw",
            "libreoffice-impress",
            "libreoffice-math",
            "libreoffice-writer",
            "libreoffice-gnome",
            "libreoffice-gtk3",
            "libreoffice-l10n-en",
            "libreoffice-l10n-pt_BR",
            "libreoffice-l10n-es",
        }
        self.assertTrue(libreoffice.issubset(packages))

        defaults = (
            ROOT
            / "kiwi/root/usr/share/glib-2.0/schemas/99-lyra-desktop-defaults.gschema.override"
        ).read_text(encoding="utf-8")
        self.assertIn("libreoffice-writer.desktop", defaults)

    def test_desktop_app_curation_uses_vlc_without_gnome_software_or_monitor(self) -> None:
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        desktop_packages = {
            node.attrib["name"]
            for packages in root.findall('packages[@profiles="desktop"]')
            for node in packages.findall("package")
        }

        self.assertIn("vlc", desktop_packages)
        self.assertIn("vlc-lang", desktop_packages)
        for name in (
            "vlc-codecs",
            "ffmpeg-7",
            "gstreamer-plugins-bad-codecs",
            "gstreamer-plugins-ugly-codecs",
            "ivtv-firmware",
            "bladeRF-fpga-firmware",
            "bladeRF-fx3-firmware",
        ):
            self.assertIn(name, desktop_packages, name)
        for name in (
            "gnome-software",
            "gnome-software-lang",
            "gnome-software-plugin-packagekit",
            "gnome-system-monitor",
            "gnome-system-monitor-lang",
        ):
            self.assertNotIn(name, desktop_packages, name)

        language_remediation = (
            ROOT / "scripts/fix-gnome-lang-packages.sh"
        ).read_text(encoding="utf-8")
        self.assertNotIn("gnome-software", language_remediation)

    def test_installed_grub_theme_contract_is_validated_by_build_and_installer(self) -> None:
        deploy = (ROOT / "installer/src/service/operations/deploy.rs").read_text(
            encoding="utf-8"
        )
        self.assertIn('"/usr/share/grub/themes/Lyra-OS/theme.txt"', deploy)
        root = ET.parse(ROOT / "kiwi/config.xml").getroot()
        build_type = root.find("preferences/type")
        self.assertIsNotNone(build_type)
        self.assertEqual(build_type.attrib.get("editbootconfig"), "edit_boot_config.sh")
        hook_path = ROOT / "kiwi/edit_boot_config.sh"
        self.assertNotEqual(hook_path.stat().st_mode & 0o111, 0)
        hook = hook_path.read_text(encoding="utf-8")
        self.assertIn("GRUB_THEME_ASSET=usr/share/grub/themes/Lyra-OS/theme.txt", hook)
        self.assertIn('GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"', hook)
        # Real regression, found running --profile server in a VM: this hook
        # used to hard-require the theme asset unconditionally, which broke
        # the server profile build (no lyra-os-theme there,
        # docs/server-edition.md). It must be conditional on the asset
        # existing, not on a hardcoded profile name.
        self.assertIn('if [ -s "$GRUB_THEME_ASSET" ]; then', hook)
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn("IMAGE_INSTALLED_GRUB_THEME", helper)
        self.assertIn("IMAGE_INSTALLED_GRUB_DEFAULT", helper)
        self.assertIn('"$KIWI_DESC/edit_boot_config.sh"', helper)

    def test_vm_helper_can_build_without_destroying_existing_vm(self) -> None:
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn("--build-only", helper)
        self.assertIn('--signing-key "$PACKAGE_SIGNING_KEYRING"', helper)
        self.assertIn(
            "build-only complete; existing VM disk and UEFI state were not changed",
            helper,
        )
        iso_ready = helper.index('echo "--- ISO ready:')
        build_only_exit = helper.index("build-only complete; existing VM disk")
        qemu_requirements = helper.index("for command in qemu-img qemu-system-x86_64")
        destructive_vm_reset = helper.rindex("\nstop_previous_vm\n")
        self.assertLess(build_only_exit, qemu_requirements)
        self.assertLess(iso_ready, destructive_vm_reset)

    def test_vm_helper_guards_host_loader_cache_during_kiwi_build(self) -> None:
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn("host_loader_is_healthy", helper)
        self.assertIn("repair_host_loader_cache", helper)
        self.assertIn("start_loader_guard", helper)
        self.assertIn("stop_loader_guard", helper)
        self.assertIn("sudo -n ldconfig", helper)
        self.assertLess(helper.index("start_loader_guard"), helper.index("sudo kiwi-ng"))
        self.assertGreater(helper.rindex("stop_loader_guard"), helper.index("sudo kiwi-ng"))

    def test_vm_helper_can_boot_installed_disk_without_iso_or_reset(self) -> None:
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn("--boot-installed", helper)
        installed_branch = helper.index('if [ "$BOOT_INSTALLED" -eq 1 ]; then')
        installed_exit = helper.index('exit "$INSTALLED_QEMU_STATUS"')
        destructive_reset = helper.index('echo "--- deleting previous VM disk')
        self.assertLess(installed_branch, installed_exit)
        self.assertLess(installed_exit, destructive_reset)
        branch = helper[installed_branch:installed_exit]
        self.assertIn("-boot order=c,menu=on", branch)
        self.assertNotIn("-cdrom", branch)
        self.assertNotIn('rm -f "$DISK_IMG"', branch)
        self.assertIn("preserving VM disk and UEFI state", branch)

    def test_vm_helper_rejects_a_stale_published_installer(self) -> None:
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn('strings "$IMAGE_INSTALLER_SERVICE"', helper)
        self.assertIn("grep -F '/usr/bin/fish'", helper)
        self.assertIn("grep -F '.bashrc'", helper)
        self.assertIn("stale or incompatible installer RPM", helper)
        self.assertIn("build-source.txt", helper)

    def test_development_bootstrap_installs_obs_local_build_runner(self) -> None:
        bootstrap = (ROOT / "scripts/bootstrap-development.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("build rpm-build rpmdevtools rpmlint spec-cleaner osc", bootstrap)
        self.assertIn("git git-lfs gh osc build", bootstrap)

    def test_vm_helper_fully_extracts_squashfs_before_promoting_iso(self) -> None:
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        extract_image = helper.index('-extract /LiveOS/squashfs.img "$ISO_SQUASHFS"')
        verify_rootfs = helper.index(
            "unsquashfs -no-xattrs -no-exit-code -f"
        )
        promote_iso = helper.index('echo "--- promoting new ISO')

        self.assertLess(extract_image, verify_rootfs)
        self.assertLess(verify_rootfs, promote_iso)
        self.assertIn("generated ISO contains an unreadable/corrupt live SquashFS", helper)
        self.assertIn("existing ISO contains an unreadable/corrupt live SquashFS", helper)
        self.assertIn("refusing to boot with --skip-build", helper)

    def test_vm_helper_forwards_ssh_and_vega_web_ports_for_server(self) -> None:
        # QEMU's user-mode/SLIRP networking is NAT-only by default - without
        # hostfwd, the server profile's ssh/vega-web could not be reached
        # from the host running the VM at all.
        helper = (ROOT / "kiwi/test/build-and-run-vm.sh").read_text(encoding="utf-8")
        self.assertIn("hostfwd=tcp::2222-:22", helper)
        self.assertIn("hostfwd=tcp::9090-:9090", helper)
        self.assertIn('if [ "$PROFILE" = server ]; then', helper)

    def test_export_is_derived_from_canonical_kiwi_without_duplicate_package_list(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "export"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=False)
            image_build.verify_export(self.manifest, destination)
            canonical = ET.parse(ROOT / "kiwi/config.xml").getroot()
            exported = ET.parse(destination / self.manifest.description).getroot()
            canonical_packages = [node.attrib["name"] for node in canonical.findall("packages/package")]
            exported_packages = [node.attrib["name"] for node in exported.findall("packages/package")]
            self.assertEqual(exported_packages, canonical_packages)
            self.assertFalse((destination / "_multibuild").exists())
            self.assertEqual(
                image_build.sha256(
                    destination / "keys/obs-package-signing-keyring.asc"
                ),
                image_build.sha256(image_build.PACKAGE_SIGNING_KEYRING),
            )
            self.assertEqual(
                image_build.sha256(destination / "config.xml"),
                image_build.sha256(ROOT / "kiwi/config.xml"),
            )
            source = json.loads((destination / "build-source.json").read_text(encoding="utf-8"))
            self.assertRegex(source["commit"], r"^[0-9a-f]{40}$")
            self.assertFalse(source["dirty"])
            self.assertTrue((destination / "root.tar.gz").is_file())

    def test_export_includes_the_server_profile_overlay(self) -> None:
        # kiwi/server/ overlays getty autologin, the pinned console
        # installer and release metadata on top of root/ only when the
        # server profile is selected (kiwi.system.setup.import_overlay_files).
        # A `kiwi-ng system build --profile server` against an export
        # missing this directory would fail immediately - config.sh
        # requires /usr/lib/lyra-os/server-release, which only exists here.
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "export"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=False)
            self.assertTrue((destination / "server/usr/lib/lyra-os/server-release").is_file())
            self.assertTrue((destination / "server/usr/sbin/lyra-server-install").is_file())
            self.assertTrue(
                (destination / "server/etc/systemd/system/getty@tty1.service.d/override.conf").is_file()
            )
            self.assertTrue(
                (destination / "server/etc/profile.d/lyra-server-info.sh").is_file()
            )

    def test_server_login_banner_shows_ip_cpu_disk_memory(self) -> None:
        banner = (
            ROOT / "kiwi/server/etc/profile.d/lyra-server-info.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("ip -4", banner)
        self.assertIn("/proc/cpuinfo", banner)
        self.assertIn("free ", banner)
        self.assertIn("df -h /", banner)
        self.assertIn("uname -n", banner)
        self.assertNotIn("$(hostname)", banner)

    def test_root_archive_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / "first"
            second = Path(temporary) / "second"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, first, "HEAD", allow_dirty=False)
                image_build.export(self.manifest, second, "HEAD", allow_dirty=False)
            self.assertEqual(
                image_build.sha256(first / "root.tar.gz"),
                image_build.sha256(second / "root.tar.gz"),
            )

    def test_export_refuses_nonempty_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            (destination / "existing").write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "not empty"):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=True)

    def test_dirty_inspection_export_cannot_pass_verification(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "export"
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: " M kiwi/config.xml" if args[0] == "status" else real_git(*args),
            ):
                image_build.export(self.manifest, destination, "HEAD", allow_dirty=True)
            with self.assertRaisesRegex(image_build.PolicyError, "source identity"):
                image_build.verify_export(self.manifest, destination)


class ServerImagePolicyTests(unittest.TestCase):
    # image-build-server.toml exists specifically so the server profile can
    # go through the same export/validate/artifact-manifest pipeline as
    # the desktop (docs/server-edition.md - initially left out on purpose,
    # added when Rodrigo asked to prepare a real alpha1 release). Both
    # profiles share <image name="lyra-os"> in kiwi/config.xml (cannot be
    # scoped per KIWI profile), so Manifest gained its own "profile" field
    # to tell the two whitelists apart in validate() instead.

    def setUp(self) -> None:
        self.manifest = image_build.Manifest.load(ROOT / "image-build-server.toml")

    def test_server_manifest_loads_with_its_own_profile_and_sources(self) -> None:
        self.assertEqual(self.manifest.profile, "server")
        projects = [source.project for source in self.manifest.package_sources]
        self.assertEqual(projects, ["home:rodrigosbrito:lyra", "home:rodrigosbrito:vega"])
        self.assertNotIn("home:rodrigosbrito:fina", projects)
        self.assertNotIn("Virtualization:Appliances:Builder", projects)
        self.assertNotIn("rollback", self.manifest.required_test_results)
        self.assertIn("checksum_signature", self.manifest.required_artifacts)

    def test_desktop_manifest_still_defaults_to_the_desktop_profile(self) -> None:
        desktop_manifest = image_build.Manifest.load()
        self.assertEqual(desktop_manifest.profile, "desktop")
        self.assertIn("rollback", desktop_manifest.required_test_results)

    def test_validate_sources_checks_the_server_preferences_block(self) -> None:
        image_build.validate_sources(
            self.manifest, profile="server", release_file=ROOT / "release-server.toml"
        )

    def test_validate_sources_rejects_a_profile_release_file_mismatch(self) -> None:
        # The desktop and server <preferences> blocks carry different
        # <version> values (independent release cycles - docs/server-edition.md).
        # Comparing the server's KIWI block against the desktop's
        # release.toml (or vice versa) must fail loudly, not silently pass.
        with self.assertRaisesRegex(image_build.PolicyError, "does not belong to profile"):
            image_build.validate_sources(self.manifest, profile="server", release_file=image_build.RELEASE)

    def test_build_identity_rejects_a_manifest_profile_mismatch(self) -> None:
        with self.assertRaisesRegex(image_build.PolicyError, "differs from manifest profile"):
            image_build.build_identity(
                self.manifest,
                profile="desktop",
                release_file=ROOT / "release-server.toml",
            )

    def test_server_identity_is_derived_from_the_manifest(self) -> None:
        profile, release_file = image_build.build_identity(self.manifest)
        self.assertEqual(profile, "server")
        self.assertEqual(release_file, ROOT / "release-server.toml")

    def test_identity_options_are_accepted_after_the_subcommand(self) -> None:
        args = image_build.parser().parse_args(
            [
                "validate",
                "--manifest",
                "image-build-server.toml",
                "--profile",
                "server",
                "--release-file",
                "release-server.toml",
            ]
        )
        self.assertEqual(args.manifest, Path("image-build-server.toml"))
        self.assertEqual(args.profile, "server")
        self.assertEqual(args.release_file, Path("release-server.toml"))

    def test_invalid_profile_is_rejected(self) -> None:
        bogus = dataclasses.replace(self.manifest, profile="bogus")
        with self.assertRaisesRegex(image_build.PolicyError, "profile must be desktop or server"):
            bogus.validate()


class ArtifactTests(unittest.TestCase):
    def create_artifacts(self, directory: Path) -> None:
        (directory / "lyra.iso").write_bytes(b"iso")
        (directory / "lyra.packages").write_text(
            "fina|(none)|0.4.0|12.1|x86_64|obs://build.opensuse.org/"
            "home:rodrigosbrito:fina/repo/revision-fina|MIT\n",
            encoding="utf-8",
        )
        (directory / "lyra.verified").write_text("verified\n", encoding="utf-8")
        (directory / "lyra.report").write_text("<report/>\n", encoding="utf-8")
        (directory / "lyra.iso.sha256").write_text(
            "checksum  lyra.iso\n", encoding="utf-8"
        )
        (directory / "lyra.iso.sha256.asc").write_text(
            "signature\n", encoding="utf-8"
        )
        (directory / "lyra.cdx.json").write_text("{}\n", encoding="utf-8")
        (directory / "lyra.spdx.json").write_text("{}\n", encoding="utf-8")

    def create_test_results(
        self, manifest: image_build.Manifest, directory: Path
    ) -> list[str]:
        results = []
        for name in manifest.required_test_results:
            path = directory / f"{name}.json"
            if name == "obs-repositories":
                document = {
                    "schema": 1,
                    "status": "passed",
                    "projects": [{"packages": ["fina"], "targets": ["Leap"]}],
                }
            elif name == "hardware-matrix":
                document = {
                    "schema": 1,
                    "status": "passed",
                    "mode": "hardware-matrix",
                    "iso": {
                        "filename": "lyra.iso",
                        "sha256": image_build.sha256(directory / "lyra.iso"),
                    },
                    "coverage": {
                        "desktops": 1,
                        "notebooks": 2,
                        "cpu_vendors": ["amd", "intel"],
                        "gpu_vendors": ["amd", "intel"],
                    },
                    "scenarios": [{"machine": str(index)} for index in range(3)],
                }
            else:
                modes = {
                    "live-session": "live-session",
                    "installer": "installer",
                    "first-boot": "first-boot",
                    "uefi-secure-boot": "uefi-secure-boot",
                    "rollback": "rollback",
                }
                document = {
                    "schema": 1,
                    "status": "passed",
                    "mode": modes[name],
                    "checks": [{"id": "fixture", "status": "passed"}],
                }
                if name == "rollback":
                    document["phase"] = "rollback-verified"
            path.write_text(json.dumps(document) + "\n", encoding="utf-8")
            results.append(f"{name}={path}")
        return results

    def test_manifest_hashes_all_evidence_and_records_exact_package_sources(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.create_artifacts(directory)
            output = directory / "manifest.json"
            tests = self.create_test_results(manifest, directory)
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.artifact_manifest(manifest, directory, output, tests)
            document = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(
                set(document["artifacts"]),
                set(image_build.required_artifact_roles(manifest, image_build.RELEASE)),
            )
            self.assertNotIn("checksum_signature", document["artifacts"])
            self.assertEqual(document["packages"][0]["license"], "MIT")
            self.assertIn("revision-fina", document["packages"][0]["source"])
            self.assertEqual(
                set(document["test_results"]), set(manifest.required_test_results)
            )
            self.assertFalse(document["source"]["dirty"])

    def test_alpha_manifest_accepts_checksum_without_detached_signature(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.create_artifacts(directory)
            (directory / "lyra.iso.sha256.asc").unlink()
            output = directory / "manifest.json"
            tests = self.create_test_results(manifest, directory)
            real_git = image_build.git
            with mock.patch.object(
                image_build,
                "git",
                side_effect=lambda *args: "" if args[0] == "status" else real_git(*args),
            ):
                image_build.artifact_manifest(manifest, directory, output, tests)
            document = json.loads(output.read_text(encoding="utf-8"))
            self.assertNotIn("checksum_signature", document["artifacts"])

    def test_beta_manifest_rejects_missing_detached_signature(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.create_artifacts(directory)
            (directory / "lyra.iso.sha256.asc").unlink()
            output = directory / "manifest.json"
            tests = self.create_test_results(manifest, directory)
            real_release_values = image_build.release_values

            def beta_release(path: Path = image_build.RELEASE) -> dict[str, object]:
                values = real_release_values(path)
                return {**values, "stage": "beta", "iteration": 1}

            with mock.patch.object(image_build, "release_values", side_effect=beta_release):
                with self.assertRaisesRegex(
                    image_build.PolicyError, "checksum signature.*found 0"
                ):
                    image_build.artifact_manifest(manifest, directory, output, tests)

    def test_manifest_rejects_missing_or_failed_release_evidence(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.create_artifacts(directory)
            failed = directory / "obs.json"
            failed.write_text('{"schema":1,"status":"failed"}\n', encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "did not pass"):
                image_build.artifact_manifest(
                    manifest,
                    directory,
                    directory / "manifest.json",
                    [f"obs-repositories={failed}"],
                )

    def test_hardware_matrix_with_a_single_machine_still_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            iso = Path(temporary) / "lyra.iso"
            iso.write_bytes(b"iso payload")
            result = image_build.validate_test_result(
                "hardware-matrix",
                {
                    "schema": 1,
                    "status": "passed",
                    "mode": "hardware-matrix",
                    "iso": {
                        "filename": iso.name,
                        "sha256": image_build.sha256(iso),
                    },
                    "coverage": {
                        "desktops": 1,
                        "notebooks": 0,
                        "cpu_vendors": ["amd"],
                        "gpu_vendors": ["amd"],
                        "gap": ["notebooks<2", "cpu:intel", "gpu:intel"],
                    },
                    "scenarios": [{"machine": "only-physical-machine"}],
                },
                iso_path=iso,
            )
            self.assertEqual(result["coverage"]["gap"], ["notebooks<2", "cpu:intel", "gpu:intel"])

    def test_manifest_rejects_empty_passed_or_mislabeled_evidence(self) -> None:
        manifest = image_build.Manifest.load()
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.create_artifacts(directory)
            empty = directory / "empty.json"
            empty.write_text('{"schema":1,"status":"passed"}\n', encoding="utf-8")
            with self.assertRaisesRegex(image_build.PolicyError, "mode"):
                image_build.validate_test_result(
                    "first-boot",
                    json.loads(empty.read_text(encoding="utf-8")),
                    iso_path=directory / "lyra.iso",
                )


if __name__ == "__main__":
    unittest.main()
