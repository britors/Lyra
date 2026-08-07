//! Runs [`ArgvCommand`]s. [`RealExecutor`] is the only thing in this crate
//! allowed to spawn a process; everything upstream of it deals in typed
//! data, never strings destined for a shell.

use std::fmt;
use std::process::Command;

use super::operation::{ArgvCommand, ALLOWED_BINARIES};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExecutorError {
    DisallowedBinary(String),
    Spawn(String),
    NonZeroExit(Option<i32>),
}

impl fmt::Display for ExecutorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ExecutorError::DisallowedBinary(binary) => {
                write!(f, "{binary}: binário fora da allow-list, execução recusada")
            }
            ExecutorError::Spawn(reason) => write!(f, "falha ao iniciar processo: {reason}"),
            ExecutorError::NonZeroExit(code) => {
                write!(f, "processo terminou com código {code:?}")
            }
        }
    }
}

pub trait Executor {
    fn run(&self, command: &ArgvCommand) -> Result<(), ExecutorError>;
}

/// Spawns the real process via argv — `Command::new(binary).args(args)`,
/// never `sh -c`. Rejects anything outside [`ALLOWED_BINARIES`] before
/// spawning at all, regardless of who constructed the `ArgvCommand`.
pub struct RealExecutor;

impl Executor for RealExecutor {
    fn run(&self, command: &ArgvCommand) -> Result<(), ExecutorError> {
        if !ALLOWED_BINARIES.contains(&command.binary.as_str()) {
            return Err(ExecutorError::DisallowedBinary(command.binary.clone()));
        }

        let status = Command::new(&command.binary)
            .args(&command.args)
            .status()
            .map_err(|error| ExecutorError::Spawn(error.to_string()))?;

        if status.success() {
            Ok(())
        } else {
            Err(ExecutorError::NonZeroExit(status.code()))
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
}
