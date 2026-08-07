#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

use lyra_installer_core::service::{ExecutionEvent, ExecutionRequest};
use lyra_installer_core::storage::{DiscoveryBackend, StorageSnapshot, SystemDiscoveryBackend};

/// Read-only: lists disks, RAID arrays and LVM volumes currently visible to
/// the live session. Never touches the disk — planning and execution are
/// separate steps the UI has not wired up yet.
#[tauri::command]
fn discover_storage() -> Result<StorageSnapshot, String> {
    SystemDiscoveryBackend
        .snapshot()
        .map_err(|error| error.to_string())
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
        .invoke_handler(tauri::generate_handler![discover_storage, execute_plan])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Lyra Installer");
}
