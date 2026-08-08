//! Executing a confirmed [`crate::storage::InstallPlan`] as root: wire
//! protocol, an allow-listed no-shell executor, an engine that revalidates
//! the plan against fresh disk state before running anything and unwinds
//! (mount/undo) whether it succeeds or fails (issue #37), the concrete
//! partitioning/Btrfs/fstab operations for a whole-disk target (issue #40),
//! and rootfs deployment/target configuration (issue #41). RAID/LVM raw
//! targets and the bootloader/Snapper step (#42) aren't implemented yet —
//! `operations::plan_to_operations` returns `OperationError::NotImplemented`
//! for unsupported target shapes rather than silently doing nothing.
//!
//! `operations::build` is the entry point that assembles the full sequence
//! (partitioning + deployment + final sync) for one [`ExecutionRequest`].

pub mod engine;
pub mod executor;
pub mod operation;
pub mod operations;
pub mod protocol;

pub use engine::{ExecutionOutcome, execute};
pub use executor::{Executor, ExecutorError, RealExecutor, missing_allowed_binaries};
pub use operation::{ALLOWED_BINARIES, ArgvCommand, OperationError, PrivilegedOperation};
pub use operations::{TARGET_ROOT, build, plan_to_operations};
pub use protocol::{ExecutionControl, ExecutionEvent, ExecutionRequest};
