//! Safety scaffold for executing a confirmed [`crate::storage::InstallPlan`]
//! as root (issue #37): wire protocol, an allow-listed no-shell executor,
//! and an engine that revalidates the plan against fresh disk state before
//! running anything and rolls back on failure.
//!
//! No real disk-mutating operation exists yet — [`operation::Operation`] is
//! deliberately uninhabited. #40/#41/#42 add concrete
//! [`operation::PrivilegedOperation`] implementations for partitioning,
//! rootfs deployment and Snapper/GRUB; this module only builds the rails
//! they'll run through.

pub mod engine;
pub mod executor;
pub mod operation;
pub mod protocol;

pub use engine::{execute, ExecutionOutcome};
pub use executor::{Executor, ExecutorError, RealExecutor};
pub use operation::{plan_to_operations, ArgvCommand, Operation, PrivilegedOperation, ALLOWED_BINARIES};
pub use protocol::{ExecutionControl, ExecutionEvent, ExecutionRequest};
