//! Runs [`ArgvCommand`]s. [`RealExecutor`] is the only thing in this crate
//! allowed to spawn a process; everything upstream of it deals in typed
//! data, never strings destined for a shell.

use std::fmt;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use super::operation::{ALLOWED_BINARIES, ArgvCommand};

const SYSTEM_BINARY_DIRS: &[&str] = &["/usr/sbin", "/usr/bin", "/sbin", "/bin"];

/// Reports missing command providers before the first destructive operation.
/// Search only the fixed system paths also used by the packaged live image;
/// the privileged service must never trust a caller-controlled PATH.
pub fn missing_allowed_binaries() -> Vec<&'static str> {
    ALLOWED_BINARIES
        .iter()
        .copied()
        .filter(|binary| system_binary_path(binary).is_none())
        .collect()
}

fn system_binary_path(binary: &str) -> Option<PathBuf> {
    SYSTEM_BINARY_DIRS.iter().find_map(|directory| {
        let path = Path::new(directory).join(binary);
        let metadata = path.metadata().ok()?;
        (metadata.is_file() && metadata.permissions().mode() & 0o111 != 0).then_some(path)
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExecutorError {
    DisallowedBinary(String),
    Spawn { binary: String, reason: String },
    NonZeroExit(Option<i32>),
}

impl fmt::Display for ExecutorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ExecutorError::DisallowedBinary(binary) => {
                write!(f, "{binary}: binário fora da allow-list, execução recusada")
            }
            ExecutorError::Spawn { binary, reason } => {
                write!(f, "falha ao iniciar o processo {binary}: {reason}")
            }
            ExecutorError::NonZeroExit(code) => {
                write!(f, "processo terminou com código {code:?}")
            }
        }
    }
}

/// Returns captured, trimmed stdout on success — needed by operations like
/// `blkid -s UUID -o value` that read a value rather than just check
/// success/failure.
pub trait Executor {
    fn run(&self, command: &ArgvCommand) -> Result<String, ExecutorError>;

    /// Like [`Executor::run`], but pipes `stdin` to the child rather than
    /// putting it on argv — the only reason this exists is `chpasswd`,
    /// which takes `username:password` on stdin specifically so the
    /// password never appears in argv (visible to any user via `ps`) or in
    /// a logged `ArgvCommand`.
    fn run_with_stdin(&self, command: &ArgvCommand, stdin: &str) -> Result<String, ExecutorError>;
}

/// Spawns the real process via argv — `Command::new(binary).args(args)`,
/// never `sh -c`. Rejects anything outside [`ALLOWED_BINARIES`] before
/// spawning at all, regardless of who constructed the `ArgvCommand`.
pub struct RealExecutor;

impl Executor for RealExecutor {
    fn run(&self, command: &ArgvCommand) -> Result<String, ExecutorError> {
        if !ALLOWED_BINARIES.contains(&command.binary.as_str()) {
            return Err(ExecutorError::DisallowedBinary(command.binary.clone()));
        }

        let binary_path =
            system_binary_path(&command.binary).ok_or_else(|| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: "não encontrado nos diretórios de sistema".to_string(),
            })?;

        let output = Command::new(binary_path)
            .args(&command.args)
            .output()
            .map_err(|error| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: error.to_string(),
            })?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            Err(ExecutorError::NonZeroExit(output.status.code()))
        }
    }

    fn run_with_stdin(&self, command: &ArgvCommand, stdin: &str) -> Result<String, ExecutorError> {
        if !ALLOWED_BINARIES.contains(&command.binary.as_str()) {
            return Err(ExecutorError::DisallowedBinary(command.binary.clone()));
        }

        let binary_path =
            system_binary_path(&command.binary).ok_or_else(|| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: "não encontrado nos diretórios de sistema".to_string(),
            })?;

        let mut child = Command::new(binary_path)
            .args(&command.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .map_err(|error| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: error.to_string(),
            })?;

        child
            .stdin
            .take()
            .ok_or_else(|| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: "stdin do processo indisponível".to_string(),
            })?
            .write_all(stdin.as_bytes())
            .map_err(|error| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: error.to_string(),
            })?;

        let output = child
            .wait_with_output()
            .map_err(|error| ExecutorError::Spawn {
                binary: command.binary.clone(),
                reason: error.to_string(),
            })?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            Err(ExecutorError::NonZeroExit(output.status.code()))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn command(binary: &str) -> ArgvCommand {
        ArgvCommand {
            binary: binary.to_string(),
            args: vec!["--version".to_string()],
        }
    }

    #[test]
    fn disallowed_binary_is_rejected_without_spawning() {
        let error = RealExecutor.run(&command("rm")).unwrap_err();
        assert_eq!(error, ExecutorError::DisallowedBinary("rm".to_string()));
    }

    #[test]
    fn shell_metacharacters_in_a_disallowed_binary_name_are_also_rejected() {
        // Never reaches a shell either way (argv, not string interpolation),
        // but this pins that a crafted binary name doesn't slip past the
        // allow-list check by accident.
        let error = RealExecutor.run(&command("sgdisk; rm -rf /")).unwrap_err();
        assert!(matches!(error, ExecutorError::DisallowedBinary(_)));
    }

    #[test]
    fn spawn_error_identifies_the_missing_binary() {
        let error = ExecutorError::Spawn {
            binary: "mkfs.vfat".to_string(),
            reason: "No such file or directory (os error 2)".to_string(),
        };
        assert_eq!(
            error.to_string(),
            "falha ao iniciar o processo mkfs.vfat: No such file or directory (os error 2)"
        );
    }
}
