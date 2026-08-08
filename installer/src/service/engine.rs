//! Turns a validated [`ExecutionRequest`] into a sequence of executed
//! operations, with revalidation-before-first-write, cancellation
//! checkpoints and best-effort unwind of everything that ran.

use std::sync::atomic::{AtomicBool, Ordering};

use crate::storage::{INSTALL_PLAN_SCHEMA_VERSION, PlanBuilder, StorageSnapshot};

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
/// is normally `operations::plan_to_operations(&request.plan)`; taking it
/// as a parameter rather than deriving it internally keeps this function's
/// safety rails (revalidation, cancellation, unwind) testable independently
/// of how a plan gets translated.
pub fn execute<'a>(
    request: &ExecutionRequest,
    current_snapshot: &StorageSnapshot,
    operations: &'a [Box<dyn PrivilegedOperation>],
    executor: &dyn Executor,
    cancel_requested: &AtomicBool,
    mut on_event: impl FnMut(ExecutionEvent),
) -> ExecutionOutcome {
    on_event(ExecutionEvent::Started);

    if request.plan.schema_version != INSTALL_PLAN_SCHEMA_VERSION {
        on_event(ExecutionEvent::Failed {
            step: "versão do plano".to_string(),
            message: format!(
                "schema {} não suportado; este serviço aceita somente {}",
                request.plan.schema_version, INSTALL_PLAN_SCHEMA_VERSION
            ),
        });
        return ExecutionOutcome::Failed;
    }

    if let Err(errors) = request.config.validate() {
        on_event(ExecutionEvent::Failed {
            step: "validação da configuração".to_string(),
            message: errors.join("; "),
        });
        return ExecutionOutcome::Failed;
    }

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

    let mut completed: Vec<&'a dyn PrivilegedOperation> = Vec::new();
    let mut cancelled = false;
    let mut failed = false;

    for operation in operations {
        if cancel_requested.load(Ordering::SeqCst) {
            cancelled = true;
            break;
        }

        on_event(ExecutionEvent::Step {
            name: operation.describe(),
            detail: None,
        });

        match operation.perform(executor) {
            Ok(()) => completed.push(operation.as_ref()),
            Err(error) => {
                on_event(ExecutionEvent::Failed {
                    step: operation.describe(),
                    message: error.to_string(),
                });
                failed = true;
                break;
            }
        }
    }

    // Always unwind — not just on failure. Each mount operation's `undo` is
    // the matching `umount`, so this is also what leaves the target cleanly
    // unmounted after a *successful* run, satisfying #40's "sincronizar e
    // desmontar em sucesso ou falha".
    unwind(&completed, executor, &mut on_event);

    if failed {
        ExecutionOutcome::Failed
    } else if cancelled {
        ExecutionOutcome::Cancelled
    } else {
        on_event(ExecutionEvent::Completed);
        ExecutionOutcome::Completed
    }
}

/// Best-effort: undo failures are surfaced as warnings, not escalated —
/// there is no further fallback if reversing an already-applied step fails,
/// and refusing to attempt the rest would leave more behind, not less.
fn unwind(
    completed: &[&dyn PrivilegedOperation],
    executor: &dyn Executor,
    on_event: &mut impl FnMut(ExecutionEvent),
) {
    for operation in completed.iter().rev() {
        if let Err(error) = operation.undo(executor) {
            on_event(ExecutionEvent::Warning {
                message: format!("falha ao desfazer {}: {error}", operation.describe()),
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::Mutex;

    use super::*;
    use crate::InstallConfig;
    use crate::service::executor::ExecutorError;
    use crate::service::operation::{ArgvCommand, OperationError};
    use crate::storage::{DeviceRole, Disk, GuidedChoice, RawTarget, Transport, VolumeLayer};

    struct FakeOperation {
        name: &'static str,
        undo: bool,
    }

    impl PrivilegedOperation for FakeOperation {
        fn describe(&self) -> String {
            self.name.to_string()
        }
        fn perform(&self, executor: &dyn Executor) -> Result<(), OperationError> {
            executor.run(&ArgvCommand {
                binary: "btrfs".to_string(),
                args: vec![self.name.to_string()],
            })?;
            Ok(())
        }
        fn undo(&self, executor: &dyn Executor) -> Result<(), OperationError> {
            if self.undo {
                executor.run(&ArgvCommand {
                    binary: "btrfs".to_string(),
                    args: vec![format!("undo-{}", self.name)],
                })?;
            }
            Ok(())
        }
    }

    fn fake_ops(names: &[(&'static str, bool)]) -> Vec<Box<dyn PrivilegedOperation>> {
        names
            .iter()
            .map(|(name, undo)| {
                Box::new(FakeOperation { name, undo: *undo }) as Box<dyn PrivilegedOperation>
            })
            .collect()
    }

    /// Fails on the Nth call (0-indexed); records every command it was
    /// asked to run, in order, so call/unwind order can be asserted.
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
        fn run(&self, command: &ArgvCommand) -> Result<String, ExecutorError> {
            let mut calls = self.calls.lock().unwrap();
            let index = calls.len();
            calls.push(command.args.join(","));
            if self.fail_at == Some(index) {
                Err(ExecutorError::NonZeroExit(Some(1)))
            } else {
                Ok(String::new())
            }
        }

        fn run_with_stdin(
            &self,
            command: &ArgvCommand,
            _stdin: &str,
        ) -> Result<String, ExecutorError> {
            self.run(command)
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
        let plan = PlanBuilder::new(&snapshot)
            .build(&choice)
            .expect("fixture plan should be valid");
        (
            snapshot,
            ExecutionRequest {
                choice,
                plan,
                config: InstallConfig {
                    full_name: "Lyra User".to_string(),
                    username: "lyra".to_string(),
                    password: "harmonia-2026".to_string(),
                    ..InstallConfig::default()
                },
            },
        )
    }

    #[test]
    fn invalid_identity_data_fails_before_any_operation() {
        let (snapshot, mut request) = valid_request();
        request.config.username = "root".to_string();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", false)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| {
            events.push(event)
        });

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert!(executor.calls().is_empty());
        assert!(matches!(
            events.last(),
            Some(ExecutionEvent::Failed { step, .. }) if step == "validação da configuração"
        ));
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

        let outcome = execute(
            &request,
            &stale_snapshot,
            &ops,
            &executor,
            &cancel,
            |event| events.push(event),
        );

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert!(executor.calls().is_empty());
        assert!(
            matches!(events.last(), Some(ExecutionEvent::Failed { step, .. }) if step == "revalidação")
        );
    }

    #[test]
    fn an_unknown_plan_schema_fails_before_any_operation() {
        let (snapshot, mut request) = valid_request();
        request.plan.schema_version = INSTALL_PLAN_SCHEMA_VERSION + 1;
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", false)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| {
            events.push(event)
        });

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert!(executor.calls().is_empty());
        assert!(
            matches!(events.last(), Some(ExecutionEvent::Failed { step, .. }) if step == "versão do plano")
        );
    }

    #[test]
    fn cancellation_requested_before_an_operation_prevents_it_from_running() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(true);
        let mut events = Vec::new();
        let ops = fake_ops(&[("a", false), ("b", false)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| {
            events.push(event)
        });

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

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| {
            events.push(event)
        });

        assert_eq!(outcome, ExecutionOutcome::Failed);
        assert_eq!(executor.calls(), vec!["a", "b", "c", "undo-b", "undo-a"]);
    }

    #[test]
    fn a_successful_run_still_unwinds_every_completed_operation() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();
        let ops = fake_ops(&[("mount-root", true), ("mount-home", true)]);

        let outcome = execute(&request, &snapshot, &ops, &executor, &cancel, |event| {
            events.push(event)
        });

        assert_eq!(outcome, ExecutionOutcome::Completed);
        assert_eq!(
            executor.calls(),
            vec![
                "mount-root",
                "mount-home",
                "undo-mount-home",
                "undo-mount-root"
            ]
        );
    }

    #[test]
    fn a_clean_run_with_no_operations_completes() {
        let (snapshot, request) = valid_request();
        let executor = FakeExecutor::new(None);
        let cancel = AtomicBool::new(false);
        let mut events = Vec::new();

        let outcome = execute(&request, &snapshot, &[], &executor, &cancel, |event| {
            events.push(event)
        });

        assert_eq!(outcome, ExecutionOutcome::Completed);
        assert_eq!(
            events,
            vec![ExecutionEvent::Started, ExecutionEvent::Completed]
        );
    }
}
