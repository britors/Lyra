//! Rootfs deployment and target configuration (issue #41): extract the live
//! squashfs into the mounted target from #40, then reproduce every step
//! Calamares' real `settings.conf` sequence runs after `fstab` — read
//! directly from the installed Calamares module tree (including the ones
//! with no Lyra override, `machineid.conf`/`locale.conf`/`keyboard.conf`/
//! `dracut.conf`, which come from `calamares-branding-upstream`) rather
//! than guessed.
//!
//! Most steps use `--root`/`-R` flags (`useradd`, `userdel`, `chpasswd`,
//! `systemctl`) or plain file I/O against paths under the target, avoiding
//! a chroot entirely. Only `dracut` genuinely needs one — it inspects the
//! target's own `/lib/modules` — so [`BindMount`] + [`RunDracut`] are the
//! only operations here that touch `chroot`.
//!
//! Deliberately not covered: removing the `calamares`/
//! `calamares-branding-upstream` RPMs from the target (Calamares'
//! `packages.conf`). That needs real zypper dependency resolution against
//! a target this session can't test against — left for #44's parity audit
//! rather than guessed at.

use std::fs;
use std::io::Read;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

use crate::InstallConfig;

use super::{io_error, path_str, ArgvCommand, Executor, OperationError, PrivilegedOperation};

const LIVE_SQUASHFS: &str = "/run/overlay/live/LiveOS/squashfs.img";
const LIVE_NM_CONNECTIONS: &str = "/etc/NetworkManager/system-connections";

/// Repos whose priority KIWI sets to 1/2/3 (`kiwi/config.xml`) only so the
/// image build picks Lyra's own package forks — must drop back down once
/// installed, or a personal OBS project would keep outranking official
/// Leap packages on every future `zypper dup`. Mirrors
/// `installcleanup.conf`'s `zypper modifyrepo --priority 90` sequence.
const LYRA_REPO_ALIASES: &[&str] = &["repo-lyra", "repo-vega", "repo-fina"];

/// Mirrors `installcleanup.conf`'s final `rm -f` — every file that only
/// makes sense in the autologin live session.
const LIVE_ONLY_ARTIFACTS: &[&str] = &[
    "etc/gdm/custom.conf",
    "etc/xdg/autostart/lyra-installer-autostart.desktop",
    "etc/polkit-1/rules.d/00-lyra-live-installer.rules",
    "usr/share/applications/calamares.desktop",
];

/// Mirrors `services-systemd.conf` exactly.
const ENABLED_SERVICES: &[&str] = &["NetworkManager.service", "firewalld.service", "gdm.service", "cups.service"];

pub fn deployment_operations(config: &InstallConfig) -> Vec<Box<dyn PrivilegedOperation>> {
    let target_root = PathBuf::from(super::TARGET_ROOT);

    vec![
        Box::new(ExtractRootfs {
            target_root: target_root.clone(),
        }),
        Box::new(WriteMachineId {
            target_root: target_root.clone(),
        }),
        Box::new(WriteLocale {
            target_root: target_root.clone(),
            locale: config.locale.clone(),
        }),
        Box::new(WriteKeyboard {
            target_root: target_root.clone(),
            locale: config.locale.clone(),
        }),
        Box::new(WriteHostname {
            target_root: target_root.clone(),
            hostname: config.hostname.clone(),
        }),
        Box::new(CreateUser {
            target_root: target_root.clone(),
            full_name: config.full_name.clone(),
            username: config.username.clone(),
            password: config.password.clone(),
        }),
        Box::new(WriteSudoers {
            target_root: target_root.clone(),
        }),
        Box::new(BindMount {
            source: PathBuf::from("/proc"),
            dest: target_root.join("proc"),
        }),
        Box::new(BindMount {
            source: PathBuf::from("/sys"),
            dest: target_root.join("sys"),
        }),
        Box::new(BindMount {
            source: PathBuf::from("/dev"),
            dest: target_root.join("dev"),
        }),
        Box::new(RunDracut {
            target_root: target_root.clone(),
        }),
        Box::new(RemoveLiveUser {
            target_root: target_root.clone(),
        }),
        Box::new(LowerLyraRepoPriorities {
            target_root: target_root.clone(),
        }),
        Box::new(RemoveLiveOnlyArtifacts {
            target_root: target_root.clone(),
        }),
        Box::new(CopyNetworkConfig {
            target_root: target_root.clone(),
            source_dir: PathBuf::from(LIVE_NM_CONNECTIONS),
            username: config.username.clone(),
        }),
        Box::new(SetHardwareClock {
            target_root: target_root.clone(),
        }),
        Box::new(EnableServices { target_root }),
    ]
}

fn random_bytes(n: usize) -> Result<Vec<u8>, OperationError> {
    let mut file = fs::File::open("/dev/urandom").map_err(io_error)?;
    let mut buf = vec![0u8; n];
    file.read_exact(&mut buf).map_err(io_error)?;
    Ok(buf)
}

fn random_hex(n: usize) -> Result<String, OperationError> {
    Ok(random_bytes(n)?.iter().map(|byte| format!("{byte:02x}")).collect())
}

struct ExtractRootfs {
    target_root: PathBuf,
}

impl PrivilegedOperation for ExtractRootfs {
    fn describe(&self) -> String {
        "extrair rootfs da sessão live".to_string()
    }
    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        executor.run(&ArgvCommand {
            binary: "unsquashfs".to_string(),
            args: vec!["-f".to_string(), "-d".to_string(), path_str(&self.target_root), LIVE_SQUASHFS.to_string()],
        })?;
        Ok(())
    }
}

/// Mirrors `machineid.conf`'s active keys: `systemd-style: uuid`,
/// `dbus-symlink: true`, `entropy-copy: false` (always generate fresh
/// entropy, never copy the live session's).
struct WriteMachineId {
    target_root: PathBuf,
}

impl PrivilegedOperation for WriteMachineId {
    fn describe(&self) -> String {
        "gerar machine-id".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let id = random_hex(16)?;
        let etc = self.target_root.join("etc");
        fs::create_dir_all(&etc).map_err(io_error)?;
        fs::write(etc.join("machine-id"), format!("{id}\n")).map_err(io_error)?;

        let dbus_dir = self.target_root.join("var/lib/dbus");
        fs::create_dir_all(&dbus_dir).map_err(io_error)?;
        let dbus_link = dbus_dir.join("machine-id");
        let _ = fs::remove_file(&dbus_link);
        std::os::unix::fs::symlink("../../../etc/machine-id", &dbus_link).map_err(io_error)?;

        for seed_dir in ["var/lib/urandom", "var/lib/systemd"] {
            let dir = self.target_root.join(seed_dir);
            fs::create_dir_all(&dir).map_err(io_error)?;
            fs::write(dir.join("random-seed"), random_bytes(512)?).map_err(io_error)?;
        }
        Ok(())
    }
}

/// Mirrors `localecfg`'s real `main.py`: writes `/etc/locale.conf` (every
/// `LC_*` category set to the same value as `LANG`, matching its
/// no-selection-made fallback shape) and `/etc/default/locale` only if
/// `/etc/default` exists. Leap has no `/etc/locale.gen`, so the module's
/// `locale-gen` branch never actually runs on this image either — nothing
/// to reproduce there.
struct WriteLocale {
    target_root: PathBuf,
    locale: String,
}

const LOCALE_CATEGORIES: &[&str] = &[
    "LANG",
    "LC_NUMERIC",
    "LC_TIME",
    "LC_MONETARY",
    "LC_PAPER",
    "LC_NAME",
    "LC_ADDRESS",
    "LC_TELEPHONE",
    "LC_MEASUREMENT",
    "LC_IDENTIFICATION",
];

impl PrivilegedOperation for WriteLocale {
    fn describe(&self) -> String {
        format!("configurar locale ({})", self.locale)
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let mut content = String::new();
        for key in LOCALE_CATEGORIES {
            content.push_str(&format!("{key}={}\n", self.locale));
        }

        let etc = self.target_root.join("etc");
        fs::create_dir_all(&etc).map_err(io_error)?;
        fs::write(etc.join("locale.conf"), &content).map_err(io_error)?;

        let default_dir = etc.join("default");
        if default_dir.is_dir() {
            fs::write(default_dir.join("locale"), &content).map_err(io_error)?;
        }
        Ok(())
    }
}

/// `InstallConfig` has no keyboard field yet — `keyboard.conf`'s real
/// module is compiled C++, so its exact target-writing behaviour can't be
/// grepped either. This is a placeholder mapping tied to locale until a
/// real keyboard picker exists; said so here and in
/// `docs/installer-architecture.md`, not left implicit.
struct WriteKeyboard {
    target_root: PathBuf,
    locale: String,
}

impl PrivilegedOperation for WriteKeyboard {
    fn describe(&self) -> String {
        "configurar layout de teclado".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let layout = if self.locale.starts_with("pt_BR") { "br" } else { "us" };

        let etc = self.target_root.join("etc");
        fs::create_dir_all(&etc).map_err(io_error)?;
        fs::write(etc.join("vconsole.conf"), format!("KEYMAP={layout}\n")).map_err(io_error)?;

        let xorg_dir = etc.join("X11/xorg.conf.d");
        fs::create_dir_all(&xorg_dir).map_err(io_error)?;
        let content = format!(
            "Section \"InputClass\"\n    Identifier \"system-keyboard\"\n    MatchIsKeyboard \"on\"\n    Option \"XkbLayout\" \"{layout}\"\nEndSection\n"
        );
        fs::write(xorg_dir.join("00-keyboard.conf"), content).map_err(io_error)?;
        Ok(())
    }
}

struct WriteHostname {
    target_root: PathBuf,
    hostname: String,
}

impl PrivilegedOperation for WriteHostname {
    fn describe(&self) -> String {
        format!("configurar hostname ({})", self.hostname)
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let etc = self.target_root.join("etc");
        fs::create_dir_all(&etc).map_err(io_error)?;
        fs::write(etc.join("hostname"), format!("{}\n", self.hostname)).map_err(io_error)?;

        let hosts_path = etc.join("hosts");
        let mut content = fs::read_to_string(&hosts_path).unwrap_or_default();
        content.push_str(&format!("127.0.1.1\t{}\n", self.hostname));
        fs::write(&hosts_path, content).map_err(io_error)?;
        Ok(())
    }
}

/// `-R`/`-c`/`-G`/`-s` mirror `users.conf`'s `wheel` membership and
/// `/bin/bash` shell; the password crosses via `chpasswd`'s stdin
/// (`run_with_stdin`), never argv. Root is never touched here — it's
/// already locked in the extracted squashfs (`setRootPassword: false`'s
/// real-world equivalent is simply that no step anywhere sets a root
/// password).
struct CreateUser {
    target_root: PathBuf,
    full_name: String,
    username: String,
    password: String,
}

impl PrivilegedOperation for CreateUser {
    fn describe(&self) -> String {
        format!("criar usuário {}", self.username)
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        executor.run(&ArgvCommand {
            binary: "useradd".to_string(),
            args: vec![
                "-R".to_string(),
                path_str(&self.target_root),
                "-m".to_string(),
                "-c".to_string(),
                self.full_name.clone(),
                "-G".to_string(),
                "wheel".to_string(),
                "-s".to_string(),
                "/bin/bash".to_string(),
                self.username.clone(),
            ],
        })?;

        executor.run_with_stdin(
            &ArgvCommand {
                binary: "chpasswd".to_string(),
                args: vec!["-R".to_string(), path_str(&self.target_root)],
            },
            &format!("{}:{}\n", self.username, self.password),
        )?;
        Ok(())
    }
}

struct WriteSudoers {
    target_root: PathBuf,
}

impl PrivilegedOperation for WriteSudoers {
    fn describe(&self) -> String {
        "conceder sudo ao grupo wheel".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let dir = self.target_root.join("etc/sudoers.d");
        fs::create_dir_all(&dir).map_err(io_error)?;
        let path = dir.join("10-installer");
        fs::write(&path, "%wheel ALL=(ALL) ALL\n").map_err(io_error)?;
        fs::set_permissions(&path, fs::Permissions::from_mode(0o440)).map_err(io_error)?;
        Ok(())
    }
}

struct BindMount {
    source: PathBuf,
    dest: PathBuf,
}

impl PrivilegedOperation for BindMount {
    fn describe(&self) -> String {
        format!("bind-mount {} em {}", self.source.display(), self.dest.display())
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        fs::create_dir_all(&self.dest).map_err(io_error)?;
        executor.run(&ArgvCommand {
            binary: "mount".to_string(),
            args: vec!["--bind".to_string(), path_str(&self.source), path_str(&self.dest)],
        })?;
        Ok(())
    }

    fn undo(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        executor.run(&ArgvCommand {
            binary: "umount".to_string(),
            args: vec![path_str(&self.dest)],
        })?;
        Ok(())
    }
}

/// `dracut.conf`'s real, active (unoverridden) content sets
/// `initramfsName: /boot/initramfs-freebsd.img` — an upstream example
/// value nobody replaced, which means Calamares on this image currently
/// writes the initramfs to the *wrong* file. Runs plain `dracut -f`
/// instead (the correct, kernel-versioned default); see
/// `kiwi/root/etc/calamares/modules/dracut.conf`, added to fix the same
/// bug for Calamares' own still-active path.
struct RunDracut {
    target_root: PathBuf,
}

impl PrivilegedOperation for RunDracut {
    fn describe(&self) -> String {
        "gerar initramfs (dracut)".to_string()
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        executor.run(&ArgvCommand {
            binary: "chroot".to_string(),
            args: vec![path_str(&self.target_root), "dracut".to_string(), "-f".to_string()],
        })?;
        Ok(())
    }
}

struct RemoveLiveUser {
    target_root: PathBuf,
}

impl PrivilegedOperation for RemoveLiveUser {
    fn describe(&self) -> String {
        "remover conta liveuser".to_string()
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        executor.run(&ArgvCommand {
            binary: "userdel".to_string(),
            args: vec![
                "-R".to_string(),
                path_str(&self.target_root),
                "--force".to_string(),
                "--remove".to_string(),
                "liveuser".to_string(),
            ],
        })?;
        Ok(())
    }
}

struct LowerLyraRepoPriorities {
    target_root: PathBuf,
}

impl PrivilegedOperation for LowerLyraRepoPriorities {
    fn describe(&self) -> String {
        "reduzir prioridade dos repositórios Lyra".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        let repos_dir = self.target_root.join("etc/zypp/repos.d");
        for alias in LYRA_REPO_ALIASES {
            let path = repos_dir.join(format!("{alias}.repo"));
            if !path.is_file() {
                continue;
            }
            let content = fs::read_to_string(&path).map_err(io_error)?;
            let rewritten: String = content
                .lines()
                .map(|line| if line.trim_start().starts_with("priority=") { "priority=90" } else { line })
                .collect::<Vec<_>>()
                .join("\n");
            fs::write(&path, rewritten + "\n").map_err(io_error)?;
        }
        Ok(())
    }
}

struct RemoveLiveOnlyArtifacts {
    target_root: PathBuf,
}

impl PrivilegedOperation for RemoveLiveOnlyArtifacts {
    fn describe(&self) -> String {
        "remover artefatos exclusivos da sessão live".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        for artifact in LIVE_ONLY_ARTIFACTS {
            // Best-effort: a missing file here just means there was nothing
            // to clean up (e.g. Calamares' own desktop entry, once the Rust
            // installer is what actually shipped this install).
            let _ = fs::remove_file(self.target_root.join(artifact));
        }
        Ok(())
    }
}

/// Line-for-line translation of `networkcfg/main.py`'s real logic: copy
/// each live NetworkManager keyfile connection except `LTSP` or one that
/// already exists on the target, rewriting the live user's saved
/// `permissions=user:...:;` line to the newly-created account.
struct CopyNetworkConfig {
    target_root: PathBuf,
    /// Always `LIVE_NM_CONNECTIONS` in production; a field (not the
    /// constant used directly) so tests can point it at a fixture
    /// directory instead of the real live session's `/etc`.
    source_dir: PathBuf,
    username: String,
}

impl PrivilegedOperation for CopyNetworkConfig {
    fn describe(&self) -> String {
        "copiar perfis de rede da sessão live".to_string()
    }

    fn perform(&self, _executor: &dyn Executor) -> Result<(), OperationError> {
        if !self.source_dir.is_dir() {
            return Ok(());
        }
        let dest_dir = self.target_root.join("etc/NetworkManager/system-connections");
        fs::create_dir_all(&dest_dir).map_err(io_error)?;

        let live_marker = "permissions=user:liveuser:;";
        let target_marker = format!("permissions=user:{}:;", self.username);

        for entry in fs::read_dir(&self.source_dir).map_err(io_error)? {
            let entry = entry.map_err(io_error)?;
            let file_name = entry.file_name();
            if file_name.to_string_lossy() == "LTSP" {
                continue;
            }
            let dest_path = dest_dir.join(&file_name);
            if dest_path.exists() {
                continue;
            }

            let content = fs::read_to_string(entry.path()).map_err(io_error)?;
            let rewritten: String = content
                .lines()
                .map(|line| if line.contains(live_marker) { target_marker.as_str() } else { line })
                .collect::<Vec<_>>()
                .join("\n");
            fs::write(&dest_path, rewritten + "\n").map_err(io_error)?;
        }
        Ok(())
    }
}

/// `--adjfile` targets the install's own `/etc/adjtime` without needing a
/// chroot (the real `hwclock/main.py` runs chrooted via
/// `target_env_call`, but writes the same file either way). Always UTC —
/// `hwclock`'s real module has no local-time branch at all.
struct SetHardwareClock {
    target_root: PathBuf,
}

impl PrivilegedOperation for SetHardwareClock {
    fn describe(&self) -> String {
        "sincronizar relógio de hardware (UTC)".to_string()
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        let adjfile = self.target_root.join("etc/adjtime");
        executor.run(&ArgvCommand {
            binary: "hwclock".to_string(),
            args: vec!["--systohc".to_string(), "--utc".to_string(), format!("--adjfile={}", path_str(&adjfile))],
        })?;
        Ok(())
    }
}

struct EnableServices {
    target_root: PathBuf,
}

impl PrivilegedOperation for EnableServices {
    fn describe(&self) -> String {
        "habilitar serviços do sistema".to_string()
    }

    fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
        let mut args = vec![format!("--root={}", path_str(&self.target_root)), "enable".to_string()];
        args.extend(ENABLED_SERVICES.iter().map(|service| service.to_string()));
        executor.run(&ArgvCommand {
            binary: "systemctl".to_string(),
            args,
        })?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;
    use std::sync::atomic::{AtomicU64, Ordering};

    use super::*;
    use crate::service::executor::ExecutorError;

    struct FakeExecutor {
        calls: RefCell<Vec<String>>,
    }

    impl FakeExecutor {
        fn new() -> Self {
            Self {
                calls: RefCell::new(Vec::new()),
            }
        }
        fn calls(&self) -> Vec<String> {
            self.calls.borrow().clone()
        }
    }

    impl Executor for FakeExecutor {
        fn run(&self, command: &ArgvCommand) -> Result<String, ExecutorError> {
            self.calls
                .borrow_mut()
                .push(format!("{} {}", command.binary, command.args.join(" ")));
            Ok(String::new())
        }

        fn run_with_stdin(&self, command: &ArgvCommand, stdin: &str) -> Result<String, ExecutorError> {
            self.calls
                .borrow_mut()
                .push(format!("{} {} <stdin: {stdin}>", command.binary, command.args.join(" ")));
            Ok(String::new())
        }
    }

    struct TempRoot(PathBuf);

    impl TempRoot {
        fn new(label: &str) -> Self {
            static COUNTER: AtomicU64 = AtomicU64::new(0);
            let n = COUNTER.fetch_add(1, Ordering::SeqCst);
            let path = std::env::temp_dir().join(format!(
                "lyra-installer-deploy-test-{label}-{}-{n}",
                std::process::id()
            ));
            fs::create_dir_all(&path).expect("temp dir should be creatable");
            TempRoot(path)
        }
    }

    impl Drop for TempRoot {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn extract_rootfs_runs_unsquashfs_with_force_and_the_live_squashfs_source() {
        let op = ExtractRootfs {
            target_root: PathBuf::from("/run/lyra-installer/target"),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        assert_eq!(
            executor.calls(),
            vec!["unsquashfs -f -d /run/lyra-installer/target /run/overlay/live/LiveOS/squashfs.img"]
        );
    }

    #[test]
    fn write_machine_id_writes_id_symlink_and_entropy_seeds() {
        let temp = TempRoot::new("machine-id");
        let op = WriteMachineId {
            target_root: temp.0.clone(),
        };
        op.perform(&FakeExecutor::new()).unwrap();

        let id = fs::read_to_string(temp.0.join("etc/machine-id")).unwrap();
        assert_eq!(id.trim().len(), 32, "machine-id should be a 32-char hex UUID");
        assert!(id.trim().chars().all(|c| c.is_ascii_hexdigit()));

        let link = temp.0.join("var/lib/dbus/machine-id");
        assert!(link.symlink_metadata().unwrap().file_type().is_symlink());
        assert_eq!(fs::read_link(&link).unwrap(), PathBuf::from("../../../etc/machine-id"));

        for seed_dir in ["var/lib/urandom", "var/lib/systemd"] {
            let seed = fs::read(temp.0.join(seed_dir).join("random-seed")).unwrap();
            assert_eq!(seed.len(), 512);
        }
    }

    #[test]
    fn write_locale_sets_every_category_and_writes_default_locale_only_if_the_dir_exists() {
        let temp = TempRoot::new("locale-no-default-dir");
        let op = WriteLocale {
            target_root: temp.0.clone(),
            locale: "pt_BR.UTF-8".to_string(),
        };
        op.perform(&FakeExecutor::new()).unwrap();

        let content = fs::read_to_string(temp.0.join("etc/locale.conf")).unwrap();
        for category in LOCALE_CATEGORIES {
            assert!(content.contains(&format!("{category}=pt_BR.UTF-8")));
        }
        assert!(!temp.0.join("etc/default/locale").exists());

        // Now with an existing /etc/default directory.
        let temp2 = TempRoot::new("locale-with-default-dir");
        fs::create_dir_all(temp2.0.join("etc/default")).unwrap();
        let op2 = WriteLocale {
            target_root: temp2.0.clone(),
            locale: "en_US.UTF-8".to_string(),
        };
        op2.perform(&FakeExecutor::new()).unwrap();
        assert!(fs::read_to_string(temp2.0.join("etc/default/locale"))
            .unwrap()
            .contains("LANG=en_US.UTF-8"));
    }

    #[test]
    fn write_keyboard_maps_locale_to_a_layout() {
        let temp = TempRoot::new("keyboard-brazil");
        let op = WriteKeyboard {
            target_root: temp.0.clone(),
            locale: "pt_BR.UTF-8".to_string(),
        };
        op.perform(&FakeExecutor::new()).unwrap();
        assert_eq!(fs::read_to_string(temp.0.join("etc/vconsole.conf")).unwrap(), "KEYMAP=br\n");
        assert!(fs::read_to_string(temp.0.join("etc/X11/xorg.conf.d/00-keyboard.conf"))
            .unwrap()
            .contains("\"br\""));

        let temp2 = TempRoot::new("keyboard-us");
        let op2 = WriteKeyboard {
            target_root: temp2.0.clone(),
            locale: "en_US.UTF-8".to_string(),
        };
        op2.perform(&FakeExecutor::new()).unwrap();
        assert_eq!(fs::read_to_string(temp2.0.join("etc/vconsole.conf")).unwrap(), "KEYMAP=us\n");
    }

    #[test]
    fn write_hostname_writes_hostname_file_and_hosts_entry() {
        let temp = TempRoot::new("hostname");
        let op = WriteHostname {
            target_root: temp.0.clone(),
            hostname: "lyra-os".to_string(),
        };
        op.perform(&FakeExecutor::new()).unwrap();
        assert_eq!(fs::read_to_string(temp.0.join("etc/hostname")).unwrap(), "lyra-os\n");
        assert!(fs::read_to_string(temp.0.join("etc/hosts")).unwrap().contains("127.0.1.1\tlyra-os"));
    }

    #[test]
    fn create_user_sends_the_password_via_stdin_never_as_an_argument() {
        let temp = TempRoot::new("create-user");
        let op = CreateUser {
            target_root: temp.0.clone(),
            full_name: "Lyra User".to_string(),
            username: "lyra".to_string(),
            password: "harmonia-2026".to_string(),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();

        let calls = executor.calls();
        assert!(calls[0].starts_with("useradd -R"));
        assert!(!calls[0].contains("harmonia-2026"), "password must never appear in argv");
        assert_eq!(calls[1], format!("chpasswd -R {} <stdin: lyra:harmonia-2026\n>", temp.0.display()));
    }

    #[test]
    fn write_sudoers_grants_wheel_with_restrictive_permissions() {
        let temp = TempRoot::new("sudoers");
        let op = WriteSudoers {
            target_root: temp.0.clone(),
        };
        op.perform(&FakeExecutor::new()).unwrap();

        let path = temp.0.join("etc/sudoers.d/10-installer");
        assert_eq!(fs::read_to_string(&path).unwrap(), "%wheel ALL=(ALL) ALL\n");
        let mode = fs::metadata(&path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o440);
    }

    #[test]
    fn bind_mount_creates_destination_and_mounts_then_unmounts_on_undo() {
        let temp = TempRoot::new("bind-mount");
        let dest = temp.0.join("proc");
        let op = BindMount {
            source: PathBuf::from("/proc"),
            dest: dest.clone(),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        assert!(dest.is_dir());
        assert_eq!(executor.calls(), vec![format!("mount --bind /proc {}", dest.display())]);

        op.undo(&executor).unwrap();
        assert_eq!(executor.calls().last().unwrap(), &format!("umount {}", dest.display()));
    }

    #[test]
    fn run_dracut_chroots_and_runs_the_corrected_command() {
        let op = RunDracut {
            target_root: PathBuf::from("/run/lyra-installer/target"),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        // No "initramfsName" garbage - see the module doc comment on RunDracut.
        assert_eq!(executor.calls(), vec!["chroot /run/lyra-installer/target dracut -f"]);
    }

    #[test]
    fn remove_live_user_argv_is_exact() {
        let op = RemoveLiveUser {
            target_root: PathBuf::from("/run/lyra-installer/target"),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        assert_eq!(
            executor.calls(),
            vec!["userdel -R /run/lyra-installer/target --force --remove liveuser"]
        );
    }

    #[test]
    fn lower_lyra_repo_priorities_only_touches_the_priority_line() {
        let temp = TempRoot::new("repo-priorities");
        let repos_dir = temp.0.join("etc/zypp/repos.d");
        fs::create_dir_all(&repos_dir).unwrap();
        fs::write(
            repos_dir.join("repo-lyra.repo"),
            "[repo-lyra]\nname=Lyra\nenabled=1\npriority=1\nautorefresh=1\n",
        )
        .unwrap();
        fs::write(repos_dir.join("repo-oss.repo"), "[repo-oss]\nname=OSS\npriority=20\n").unwrap();

        let op = LowerLyraRepoPriorities {
            target_root: temp.0.clone(),
        };
        op.perform(&FakeExecutor::new()).unwrap();

        let lyra = fs::read_to_string(repos_dir.join("repo-lyra.repo")).unwrap();
        assert!(lyra.contains("priority=90"));
        assert!(lyra.contains("name=Lyra"));
        assert!(lyra.contains("autorefresh=1"));
        // Untouched: not one of the three Lyra aliases.
        assert!(fs::read_to_string(repos_dir.join("repo-oss.repo")).unwrap().contains("priority=20"));
    }

    #[test]
    fn remove_live_only_artifacts_is_best_effort_when_files_are_missing() {
        let temp = TempRoot::new("remove-artifacts-missing");
        let op = RemoveLiveOnlyArtifacts {
            target_root: temp.0.clone(),
        };
        // None of LIVE_ONLY_ARTIFACTS exist under this fresh temp root.
        op.perform(&FakeExecutor::new()).expect("missing files must not be an error");
    }

    #[test]
    fn remove_live_only_artifacts_removes_files_that_exist() {
        let temp = TempRoot::new("remove-artifacts-present");
        let path = temp.0.join("usr/share/applications/calamares.desktop");
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, "[Desktop Entry]\n").unwrap();

        let op = RemoveLiveOnlyArtifacts {
            target_root: temp.0.clone(),
        };
        op.perform(&FakeExecutor::new()).unwrap();
        assert!(!path.exists());
    }

    #[test]
    fn copy_network_config_skips_ltsp_and_existing_and_rewrites_permissions() {
        let source = TempRoot::new("nm-source");
        fs::write(source.0.join("home-wifi.nmconnection"), "[connection]\npermissions=user:liveuser:;\nid=home\n")
            .unwrap();
        fs::write(source.0.join("LTSP"), "should be skipped\n").unwrap();

        let target = TempRoot::new("nm-target");
        let existing_dest = target.0.join("etc/NetworkManager/system-connections");
        fs::create_dir_all(&existing_dest).unwrap();
        fs::write(existing_dest.join("already-there.nmconnection"), "id=already-there\n").unwrap();
        fs::write(source.0.join("already-there.nmconnection"), "id=should-not-overwrite\n").unwrap();

        let op = CopyNetworkConfig {
            target_root: target.0.clone(),
            source_dir: source.0.clone(),
            username: "lyra".to_string(),
        };
        op.perform(&FakeExecutor::new()).unwrap();

        let copied = fs::read_to_string(existing_dest.join("home-wifi.nmconnection")).unwrap();
        assert!(copied.contains("permissions=user:lyra:;"));
        assert!(!copied.contains("liveuser"));
        assert!(!existing_dest.join("LTSP").exists());
        assert_eq!(
            fs::read_to_string(existing_dest.join("already-there.nmconnection")).unwrap(),
            "id=already-there\n",
            "an existing target file must never be overwritten"
        );
    }

    #[test]
    fn set_hardware_clock_uses_the_target_adjfile_and_utc() {
        let op = SetHardwareClock {
            target_root: PathBuf::from("/run/lyra-installer/target"),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        assert_eq!(
            executor.calls(),
            vec!["hwclock --systohc --utc --adjfile=/run/lyra-installer/target/etc/adjtime"]
        );
    }

    #[test]
    fn enable_services_targets_the_right_root_and_unit_list() {
        let op = EnableServices {
            target_root: PathBuf::from("/run/lyra-installer/target"),
        };
        let executor = FakeExecutor::new();
        op.perform(&executor).unwrap();
        assert_eq!(
            executor.calls(),
            vec!["systemctl --root=/run/lyra-installer/target enable NetworkManager.service firewalld.service gdm.service cups.service"]
        );
    }
}
