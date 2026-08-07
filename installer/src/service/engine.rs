//! Turns a validated [`ExecutionRequest`] into a sequence of executed
//! operations, with revalidation-before-first-write, cancellation
//! checkpoints and best-effort rollback on failure.

use std::sync::atomic::{AtomicBool, Ordering};

use crate::storage::{PlanBuilder, StorageSnapshot};

use super::executor::Executor;
use super::operation::PrivilegedOperation;
use super::protocol::{ExecutionEvent, ExecutionRequest};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionOutcome {
    Completed,
    Cancelled,
    Failed,
}

/// `current_snapshot` must be freshly read (not the one the frontend used
/// to build the plan originally) — that's what makes the revalidation step
/// meaningful instead of just re-checking the same data twice. `operations`
/// is normally `plan_to_operations(&request.plan)` (always empty today,
/// see `operation.rs`); taking it as a parameter rather than deriving it
/// internally keeps this function's safety rails (revalidation,
/// cancellation, rollback) testable independently of how a plan gets
/// translated.
pub fn execute(
    request: &ExecutionRequest,
    current_snapshot: &StorageSnapshot,
    operations: &[Box<dyn PrivilegedOperation>],
    executor: &dyn Executor,
    cancel_requested: &AtomicBool,
    mut on_event: impl FnMut(ExecutionEvent),
) -> ExecutionOutcome {
    on_event(ExecutionEvent::Started);

    match PlanBuilder::new(current_snapshot).build(&request.choice) {
        Err(error) => {
            on_event(ExecutionEvent::Failed {
                step: "revalidação".to_string(),
                message: error.0.join("; "),
            });
            return ExecutionOutcome::Failed;
        }
        Ok(fresh_plan) if fresh_plan != request.plan => {
            on_event(ExecutionEvent::Failed {
                step: "revalidação".to_string(),
                message: "o plano não corresponde mais ao estado atual do disco".to_string(),
            });
            return ExecutionOutcome::Failed;
        }
        Ok(_) => {}
    }

    let mut undo_stack = Vec::new();

    for operation in operations {
        if cancel_requested.load(Ordering::SeqCst) {
            rollback(&undo_stack, executor, &mut on_event);
            return ExecutionOutcome::Cancelled;
        }

        on_event(ExecutionEvent::Step {
            name: operation.describe(),
            detail: None,
        });

        match executor.run(&operation.command()) {
            Ok(()) => {
                if let Some(undo) = operation.undo() {
                    undo_stack.push(undo);
                }
            }
            Err(error) => {
                on_event(ExecutionEvent::Failed {
                    step: operation.describe(),
                    message: error.to_string(),
                });
                rollback(&undo_stack, executor, &mut on_event);
                return ExecutionOutcome::Failed;
            }
        }
    }

    on_event(ExecutionEvent::Completed);
    ExecutionOutcome::Completed
}

/// Best-effort: undo failures are surfaced as warnings, not escalated —
/// there is no further fallback if reversing an already-applied step fails,
/// and refusing to attempt the rest would leave more behind, not less.
fn rollback(
    undo_stack: &[super::operation::ArgvCommand],
    executor: &dyn Executor,
    on_event: &mut impl FnMut(ExecutionEvent),
) {
    for command in undo_stack.iter().rev() {
        if let Err(error) = executor.run(command) {
            on_event(ExecutionEvent::Warning {
                message: format!("falha ao desfazer {}: {error}", command.binary),
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::Mutex;

    use super::*;
    use crate::service::executor::ExecutorError;
    use crate::service::operation::ArgvCommand;
    use crate::storage::{DeviceRole, Disk, GuidedChoice, RawTarget, Transport, VolumeLayer};

    struct FakeOperation {
        name: &'static str,
        undo: bool,
    }

    impl PrivilegedOperation for FakeOperation {
        fn describe(&self) -> String {
            self.name.to_string()
        }
        fn command(&self) -> ArgvCommand {
            ArgvCommand {
                binary: "btrfs".to_string(),
                args: vec![self.name.to_string()],
            }
        }
        fn undo(&self) -> Option<ArgvCommand> {
            self.undo.then(|| ArgvCommand {
                binary: "btrfs".to_string(),
                args: vec![format!("undo-{}", self.name)],
            })
        }
    }

    fn fake_ops(names: &[(&'static str, bool)]) -> Vec<Box<dyn PrivilegedOperation>> {
        names
            .iter()
            .map(|(name, undo)| Box::new(FakeOperation { name, undo: *undo }) as Box<dyn PrivilegedOperation>)
            .collect()
    }

    /// Fails on the Nth call (0-indexed); records every command it was
    /// asked to run, in order, so call/rollback order can be asserted.
    struct FakeExecutor {
        fail_at: Option<usize>,
        calls: Mutex<Vec<String>>,
    }

    impl FakeExecutor {
        fn new(fail_at: Option<usize>) -> Self {
            Self {
                fail_at,
                calls: Mutex::new(Vec::new()),
            }
        }
        fn calls(&self) -> Vec<String> {
            self.calls.lock().unwrap().clone()
        }
    }

    impl Executor for FakeExecutor {
        fn run(&self, command: &ArgvCommand) -> Result<(), ExecutorError> {
            let mut calls = self.calls.lock().unwrap();
            let index = calls.len();
            calls.push(command.args.join(","));
            if self.fail_at == Some(index) {
                Err(ExecutorError::NonZeroExit(Some(1)))
            } else {
                Ok(())
            }
        }
    }

    fn disk(kname: &str, size_bytes: u64) -> Disk {
        Disk {
            path: PathBuf::from(format!("/dev/{kname}")),
            kname: kname.to_string(),
            size_bytes,
            transport: Transport::Nvme,
            vendor: None,
            model: None,
            removable: false,
            is_live_media: false,
            role: DeviceRole::Free,
            partitions: Vec::new(),
        }
    }

    const LARGE: u64 = 40 * 1024 * 1024 * 1024;

    fn valid_request() -> (StorageSnapshot, ExecutionRequest) {
        let snapshot = StorageSnapshot {
            uefi: true,
            disks: vec![disk("sda", LARGE)],
            raid_arrays: Vec::new(),
            volume_groups: Vec::new(),
            logical_volumes: Vec::new(),
        };
        let choice = GuidedChoice {
            raw_target: Some(RawTarget::Disk(PathBuf::from("/dev/sda"))),
            volume_layer: VolumeLayer::Direct,
        };
        let plan = PlanBuilder::new(&snapshot).build(&choice).expect("fixture plan should be valid");
        (snapshot, ExecutionRequest { choice, plan })
    }

    #[test]
    fn a_plan_that_no_longer_matches_the_current_disk_state_fails_before_any_operation() {
        let (_, request) = valid_request();
        let stale_snapshot = StorageSnapshot {
            uefi: true,
            disks: Vec::new(), // the target disk vanished
            raid_arrays: Vec::new(),
            volume_groups: Vec::new(),
            logical_volumes: Vec::new(),
        };
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", false)]);

        let outcome = execute(&request, &stale_snapshot, &ops, &executor, &cancel, |event| events.push(event));

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert!(executor.calls().is_empty());
        assert!(matches!(events.last(), Some(ExecutionEvent::Failed { step, .. }) if step == "revalidação"));
    }

    #[test]
    fn cancellation_requested_before_an_operation_prevents_it_from_running() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(true);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", false), ("b", false)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| events.push(event));

        assert_eq!(outcome, ExecutionOutcome::Cancelled);
        assert!(executor.calls().is_empty(), "no operation should have run");
    }

    #[test]
    fn a_failure_partway_through_undoes_completed_operations_in_reverse_order() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(Some(2)); // third operation ("c") fails
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", true), ("b", true), ("c", true)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| events.push(event));

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert_eq!(executor.calls(), vec!["a", "b", "c", "undo-b", "undo-a"]);
    }

    #[test]
    fn a_clean_run_with_no_operations_completes() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();

        let outcome = execute(&request, &snapshot, &[], &executor, &cancel, |event| events.push(event));

        assert_eq!(outcome, ExecutionOutcome::Completed);
        assert_eq!(events, vec![ExecutionEvent::Started, ExecutionEvent::Completed]);
    }
}
