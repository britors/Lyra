//! The allow-listed shape every privileged action must take. Nothing here
//! runs a shell or interpolates a string into one — every operation reduces
//! to a fixed binary name plus an argv array, checked against
//! [`ALLOWED_BINARIES`] before [`super::executor::RealExecutor`] ever spawns
//! it (see `executor.rs`).

use crate::storage::InstallPlan;

/// One process invocation: `Command::new(binary).args(args)`, never
/// `sh -c "..."`. Kept separate from [`PrivilegedOperation`] so tests can
/// build one directly without needing a real operation type to exist.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ArgvCommand {
    pub binary: String,
    pub args: Vec<String>,
}

/// Every binary a privileged operation is ever allowed to run. Adding to
/// this list is a deliberate, reviewable act — it's the actual security
/// boundary, not the polkit prompt (which only gates *launching* the
/// service at all).
pub const ALLOWED_BINARIES: &[&str] = &[
    "sgdisk",
    "wipefs",
    "mkfs.btrfs",
    "mdadm",
    "vgcreate",
    "lvcreate",
    "mount",
    "umount",
    "btrfs",
];

/// A single privileged step. Real variants (create the GPT table, format
/// the ESP, create Btrfs subvolumes, assemble a RAID array, ...) belong to
/// whichever issue actually implements that behaviour (#40 storage
/// execution, #41 rootfs deployment, #42 Snapper/GRUB) — this issue (#37)
/// only builds the safety rails those operations will run through.
pub trait PrivilegedOperation {
    /// Human-readable description surfaced in `ExecutionEvent::Step`.
    fn describe(&self) -> String;
    fn command(&self) -> ArgvCommand;
    /// Best-effort compensating action run, in reverse order, if a later
    /// operation in the same plan fails. `None` when there's nothing
    /// meaningful to undo (e.g. a read-only check).
    fn undo(&self) -> Option<ArgvCommand> {
        None
    }
}

/// Deliberately uninhabited: no concrete privileged operation exists yet.
/// `#40`/`#41`/`#42` add real variants here as they implement the storage,
/// rootfs and bootloader/Snapper steps; until then [`plan_to_operations`]
/// always returns an empty list, and the engine below has nothing to do
/// but validate.
pub enum Operation {}

impl PrivilegedOperation for Operation {
    fn describe(&self) -> String {
        match *self {}
    }
    fn command(&self) -> ArgvCommand {
        match *self {}
    }
}

/// Translates a validated [`InstallPlan`] into the ordered operations that
/// implement it. Always empty today — see [`Operation`].
pub fn plan_to_operations(_plan: &InstallPlan) -> Vec<Box<dyn PrivilegedOperation>> {
    Vec::new()
}
