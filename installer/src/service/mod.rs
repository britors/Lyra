//! Executing a confirmed [`crate::storage::InstallPlan`] as root: wire
//! protocol, an allow-listed no-shell executor, an engine that revalidates
//! the plan against fresh disk state before running anything and unwinds
//! (mount/undo) whether it succeeds or fails (issue #37), and the concrete
//! partitioning/Btrfs/fstab operations for a whole-disk target (issue #40).
//! RAID/LVM raw targets and rootfs/bootloader steps (#41/#42) aren't
//! implemented yet — `operations::plan_to_operations` returns
//! `OperationError::NotImplemented` for those rather than silently doing
//! nothing.

pub mod engine;
pub mod executor;
pub mod operation;
pub mod operations;
pub mod protocol;

pub use engine::{execute, ExecutionOutcome};
pub use executor::{Executor, ExecutorError, RealExecutor};
pub use operation::{ArgvCommand, OperationError, PrivilegedOperation, ALLOWED_BINARIES};
pub use operations::{plan_to_operations, TARGET_ROOT};
pub use protocol::{ExecutionControl, ExecutionEvent, ExecutionRequest};
