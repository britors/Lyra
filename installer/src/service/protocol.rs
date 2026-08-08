//! JSON-lines wire protocol between the unprivileged Tauri frontend and
//! `lyra-installer-service`. One [`ExecutionRequest`] is sent as a single
//! JSON line on the child's stdin; the service replies with one
//! [`ExecutionEvent`] per line on stdout until it emits `Completed` or
//! `Failed`. An optional [`ExecutionControl`] line may follow on the same
//! stdin stream to request cancellation.

use serde::{Deserialize, Serialize};

use crate::InstallConfig;
use crate::storage::{GuidedChoice, InstallPlan};

/// `plan` is carried alongside `choice` (rather than derived from it again)
/// so the service can compare what it recomputes against exactly what the
/// user confirmed on screen — any mismatch is treated as staleness, not
/// silently re-applied. `config` is the identity data collected by the
/// unprivileged wizard (locale, hostname, account) — needed by the
/// deployment operations (issue #41), which never touch storage.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExecutionRequest {
    pub choice: GuidedChoice,
    pub plan: InstallPlan,
    pub config: InstallConfig,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExecutionEvent {
    Started,
    Step {
        name: String,
        detail: Option<String>,
    },
    Warning {
        message: String,
    },
    Failed {
        step: String,
        message: String,
    },
    Completed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExecutionControl {
    Cancel,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn execution_event_round_trips_through_json() {
        let event = ExecutionEvent::Failed {
            step: "particionar".to_string(),
            message: "disco ocupado".to_string(),
        };
        let json = serde_json::to_string(&event).expect("event should serialize");
        let decoded: ExecutionEvent =
            serde_json::from_str(&json).expect("event should deserialize");
        assert_eq!(event, decoded);
    }

    #[test]
    fn execution_control_round_trips_through_json() {
        let json =
            serde_json::to_string(&ExecutionControl::Cancel).expect("control should serialize");
        let decoded: ExecutionControl =
            serde_json::from_str(&json).expect("control should deserialize");
        assert_eq!(decoded, ExecutionControl::Cancel);
    }
}
