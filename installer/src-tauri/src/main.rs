#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

use lyra_installer_core::service::{ExecutionEvent, ExecutionRequest};
use lyra_installer_core::storage::{DiscoveryBackend, GuidedChoice, InstallPlan, PlanBuilder, StorageSnapshot, SystemDiscoveryBackend};
use lyra_installer_core::InstallConfig;

/// Read-only: lists disks, RAID arrays and LVM volumes currently visible to
/// the live session. Never touches the disk — planning and execution are
/// separate steps the UI has not wired up yet.
#[tauri::command]
fn discover_storage() -> Result<StorageSnapshot, String> {
    SystemDiscoveryBackend
        .snapshot()
        .map_err(|error| error.to_string())
}

/// Dry-run only, same guarantee as `PlanBuilder::build` itself: no I/O, safe
/// to call from the unprivileged frontend as the user builds a target choice
/// on the storage step. `snapshot` is the one the UI already fetched via
/// `discover_storage` rather than a fresh read, so the plan is built against
/// exactly what the user was shown. Takes the full `GuidedChoice` — both the
/// "whole disk, direct layout" and "new RAID array, direct layout" screens
/// send one of these; `volume_layer` stays `Direct` from every screen so
/// far (no LVM authoring UI), but nothing here assumes that.
#[tauri::command]
fn plan_install(snapshot: StorageSnapshot, choice: GuidedChoice) -> Result<InstallPlan, String> {
    PlanBuilder::new(&snapshot)
        .build(&choice)
        .map_err(|error| error.0.join(" · "))
}

/// Runs the real `InstallConfig::validate()` against whatever the wizard has
/// collected so far — no I/O, same dry-run guarantee as `plan_install`.
/// This is the summary step's own check, not a duplicate of it: page 4's
/// client-side `validate()` in `app.js` only covers full name/username/
/// hostname/password, so this is what actually catches an invalid
/// `timezone`/`locale` (there's no client-side rule for those). Errors
/// still don't cross the privilege boundary — that's `execute_plan`, and
/// nothing calls it with a wizard-built config yet (see `installer/README.md`).
#[tauri::command]
fn validate_install_config(config: InstallConfig) -> Result<(), String> {
    config.validate().map_err(|errors| errors.join(" · "))
}

/// Path the polkit action (`io.lyra.Installer.execute-plan`) is scoped to —
/// keep both in sync. Not present on a dev machine: packaging the service
/// as an RPM is #53's job, still pending.
const SERVICE_PATH: &str = "/usr/libexec/lyra-installer-service";

/// Launches the privileged service via `pkexec` for the duration of this
/// one call only — never the whole UI, unlike the Calamares launcher this
/// project is replacing (see `docs/installer-architecture.md`). Sends the
/// confirmed plan on stdin, collects every event from stdout, and returns
/// once the child exits; no live streaming to the window and no new screen
/// yet, same scope boundary as `discover_storage`.
#[tauri::command]
fn execute_plan(request: ExecutionRequest) -> Result<Vec<ExecutionEvent>, String> {
    let mut child = Command::new("pkexec")
        .arg(SERVICE_PATH)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(|error| format!("não foi possível iniciar o serviço privilegiado: {error}"))?;

    let payload = serde_json::to_string(&request).map_err(|error| error.to_string())?;
    {
        let mut stdin = child.stdin.take().ok_or("stdin do serviço indisponível")?;
        writeln!(stdin, "{payload}").map_err(|error| error.to_string())?;
    }

    let stdout = child.stdout.take().ok_or("stdout do serviço indisponível")?;
    let mut events = Vec::new();
    for line in BufReader::new(stdout).lines() {
        let line = line.map_err(|error| error.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        let event = serde_json::from_str::<ExecutionEvent>(&line)
            .map_err(|error| format!("evento inesperado do serviço: {error}"))?;
        events.push(event);
    }

    child.wait().map_err(|error| error.to_string())?;
    Ok(events)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            discover_storage,
            plan_install,
            validate_install_config,
            execute_plan
        ])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Lyra Installer");
}
