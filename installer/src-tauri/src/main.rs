#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

use lyra_installer_core::InstallConfig;
use lyra_installer_core::service::{ExecutionEvent, ExecutionRequest};
use lyra_installer_core::storage::{
    DiscoveryBackend, GuidedChoice, InstallPlan, PlanBuilder, StorageSnapshot,
    SystemDiscoveryBackend,
};

/// Read-only: lists disks, RAID arrays and LVM volumes currently visible to
/// the live session. Never touches the disk — planning and execution are
/// separate steps until the user confirms the summary screen.
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
/// still don't cross the privilege boundary — only `execute_plan` does that,
/// after this validation succeeds and the user accepts the destructive
/// confirmation on the summary screen.
#[tauri::command]
fn validate_install_config(config: InstallConfig) -> Result<(), String> {
    config.validate().map_err(|errors| errors.join(" · "))
}

/// Path the polkit action (`io.lyra.Installer.execute-plan`) is scoped to —
/// keep both in sync. Development builds may use a locally staged service;
/// the live image receives this path from the `lyra-installer` RPM.
const SERVICE_PATH: &str = "/usr/libexec/lyra-installer-service";
const TRACE_FILENAME: &str = "lyra-installer-trace.log";

fn redacted_config(config: &InstallConfig) -> serde_json::Value {
    serde_json::json!({
        "locale": config.locale,
        "timezone": config.timezone,
        "keyboard_layout": config.keyboard_layout,
        "hostname": config.hostname,
        "full_name": config.full_name,
        "username": config.username,
        "password": "<redacted>"
    })
}

/// Creates the diagnostic log as the unprivileged desktop user, before
/// pkexec is launched. The privileged service therefore never opens a path
/// controlled by the live user, and the resulting file remains easy for the
/// tester to copy from their own home directory.
fn create_install_trace(request: &ExecutionRequest) -> Result<(File, PathBuf), String> {
    let home = env::var_os("HOME").ok_or("HOME não está definido")?;
    let home = PathBuf::from(home);
    if !home.is_absolute() || !home.is_dir() {
        return Err(format!("diretório HOME inválido: {}", home.display()));
    }

    let path = home.join(TRACE_FILENAME);
    if let Ok(metadata) = fs::symlink_metadata(&path)
        && (!metadata.file_type().is_file() || metadata.file_type().is_symlink())
    {
        return Err(format!(
            "o caminho do trace não é um arquivo regular: {}",
            path.display()
        ));
    }

    let mut trace = OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .mode(0o600)
        .open(&path)
        .map_err(|error| format!("não foi possível criar {}: {error}", path.display()))?;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600))
        .map_err(|error| format!("não foi possível proteger {}: {error}", path.display()))?;

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default();
    let source = fs::read_to_string("/usr/share/lyra-installer/build-source.txt")
        .unwrap_or_else(|error| format!("indisponível: {error}"));
    let summary = serde_json::json!({
        "choice": &request.choice,
        "plan": &request.plan,
        "config": redacted_config(&request.config)
    });

    writeln!(trace, "Lyra Installer trace")
        .and_then(|_| writeln!(trace, "timestamp_unix={timestamp}"))
        .and_then(|_| writeln!(trace, "installer_version={}", env!("CARGO_PKG_VERSION")))
        .and_then(|_| writeln!(trace, "build_source={}", source.trim()))
        .and_then(|_| writeln!(trace, "request={summary}"))
        .and_then(|_| trace.flush())
        .map_err(|error| format!("não foi possível escrever {}: {error}", path.display()))?;

    Ok((trace, path))
}

fn append_trace(trace: &mut File, line: &str) {
    let _ = writeln!(trace, "{line}");
    let _ = trace.flush();
}

/// Reuses the packaged application artwork inside the static frontend instead
/// of maintaining a second copy that can drift from the RPM/window icon.
#[tauri::command]
fn installer_logo() -> Vec<u8> {
    include_bytes!("../icons/256x256.png").to_vec()
}

const PREFERRED_WINDOW_WIDTH: u32 = 1180;
const PREFERRED_WINDOW_HEIGHT: u32 = 880;
const WINDOW_HORIZONTAL_MARGIN: u32 = 48;
const WINDOW_VERTICAL_MARGIN: u32 = 72;

fn fitted_window_size(
    current: tauri::PhysicalSize<u32>,
    work_area: tauri::PhysicalSize<u32>,
) -> tauri::PhysicalSize<u32> {
    let available_width = work_area.width.saturating_sub(WINDOW_HORIZONTAL_MARGIN);
    let available_height = work_area.height.saturating_sub(WINDOW_VERTICAL_MARGIN);

    tauri::PhysicalSize::new(
        current
            .width
            .min(PREFERRED_WINDOW_WIDTH)
            .min(available_width),
        current
            .height
            .min(PREFERRED_WINDOW_HEIGHT)
            .min(available_height),
    )
}

/// Keeps the entire installer inside the monitor work area after the VM or
/// desktop changes resolution. The margin accounts for GNOME's title bar and
/// leaves the wizard footer reachable instead of allowing it below the screen.
#[tauri::command]
fn fit_window_to_monitor(window: tauri::WebviewWindow) -> Result<(), String> {
    let current_monitor = window
        .current_monitor()
        .map_err(|error| error.to_string())?;
    let monitor = match current_monitor {
        Some(monitor) => monitor,
        None => window
            .primary_monitor()
            .map_err(|error| error.to_string())?
            .ok_or("não foi possível detectar o monitor atual")?,
    };
    let current = window.inner_size().map_err(|error| error.to_string())?;
    let size = fitted_window_size(current, monitor.work_area().size);

    window.set_size(size).map_err(|error| error.to_string())?;
    window.center().map_err(|error| error.to_string())?;
    Ok(())
}

/// Moves the blocking child-process/pipe loop off the Tauri command thread.
/// Keeping it in a synchronous command made WebKit's window stop repainting,
/// so GNOME repeatedly offered an "Aguarde" response while the installation
/// itself continued normally in the background.
#[tauri::command]
async fn execute_plan(request: ExecutionRequest) -> Result<Vec<ExecutionEvent>, String> {
    tauri::async_runtime::spawn_blocking(move || execute_plan_blocking(request))
        .await
        .map_err(|error| format!("a tarefa de instalação foi interrompida: {error}"))?
}

/// Launches the privileged service via `pkexec` for the duration of this one
/// call only — never the whole UI (see `docs/installer-architecture.md`).
/// Sends the confirmed plan on stdin, collects every event from stdout, and
/// returns once the child exits. The frontend remains responsive and shows
/// its indeterminate animation while this function runs on the blocking pool;
/// live event streaming remains a separate improvement.
fn execute_plan_blocking(request: ExecutionRequest) -> Result<Vec<ExecutionEvent>, String> {
    let (mut trace, trace_path) = create_install_trace(&request)?;
    append_trace(&mut trace, "frontend=starting privileged service");

    let mut child = Command::new("pkexec")
        .arg(SERVICE_PATH)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| {
            let message = format!("não foi possível iniciar o serviço privilegiado: {error}");
            append_trace(&mut trace, &format!("frontend_error={message}"));
            message
        })?;

    let payload = serde_json::to_string(&request).map_err(|error| error.to_string())?;
    {
        let mut stdin = child.stdin.take().ok_or("stdin do serviço indisponível")?;
        writeln!(stdin, "{payload}").map_err(|error| error.to_string())?;
    }

    let stdout = child
        .stdout
        .take()
        .ok_or("stdout do serviço indisponível")?;
    let stderr = child
        .stderr
        .take()
        .ok_or("stderr do serviço indisponível")?;
    let stderr_reader = thread::spawn(move || {
        let mut message = String::new();
        let _ = BufReader::new(stderr).read_to_string(&mut message);
        message
    });

    let mut events = Vec::new();
    for line in BufReader::new(stdout).lines() {
        let line = line.map_err(|error| error.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        append_trace(&mut trace, &format!("service_event={line}"));
        let event = serde_json::from_str::<ExecutionEvent>(&line)
            .map_err(|error| format!("evento inesperado do serviço: {error}"))?;
        events.push(event);
    }

    let status = child.wait().map_err(|error| error.to_string())?;
    let stderr = stderr_reader
        .join()
        .unwrap_or_else(|_| "não foi possível ler o erro do serviço".to_string());
    if !stderr.trim().is_empty() {
        append_trace(&mut trace, &format!("service_stderr={}", stderr.trim()));
    }
    append_trace(&mut trace, &format!("service_status={status}"));
    append_trace(&mut trace, &format!("trace_path={}", trace_path.display()));
    let failed_event = events
        .iter()
        .any(|event| matches!(event, ExecutionEvent::Failed { .. }));
    let completed_event = events
        .iter()
        .any(|event| matches!(event, ExecutionEvent::Completed));

    if !status.success() && !failed_event {
        let detail = stderr.trim();
        return Err(if detail.is_empty() {
            format!("o serviço privilegiado terminou com {status}")
        } else {
            format!("o serviço privilegiado não iniciou: {detail}")
        });
    }
    if status.success() && !completed_event {
        return Err("o serviço terminou sem confirmar a conclusão".to_string());
    }

    Ok(events)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            discover_storage,
            plan_install,
            validate_install_config,
            installer_logo,
            fit_window_to_monitor,
            execute_plan
        ])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Lyra Installer");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn embedded_installer_logo_is_a_png() {
        let logo = installer_logo();
        assert!(logo.starts_with(b"\x89PNG\r\n\x1a\n"));
    }

    #[test]
    fn diagnostic_config_never_contains_the_password() {
        let mut config = InstallConfig::default();
        config.password = "segredo-que-nao-pode-ir-ao-log".to_string();
        let summary = redacted_config(&config);
        assert_eq!(summary["password"], "<redacted>");
        assert!(!summary.to_string().contains(&config.password));
    }

    #[test]
    fn fitted_window_leaves_room_for_desktop_chrome() {
        let fitted = fitted_window_size(
            tauri::PhysicalSize::new(1180, 880),
            tauri::PhysicalSize::new(1024, 728),
        );

        assert_eq!(fitted, tauri::PhysicalSize::new(976, 656));
    }

    #[test]
    fn fitted_window_does_not_enlarge_a_user_resized_window() {
        let fitted = fitted_window_size(
            tauri::PhysicalSize::new(800, 600),
            tauri::PhysicalSize::new(1920, 1040),
        );

        assert_eq!(fitted, tauri::PhysicalSize::new(800, 600));
    }
}
