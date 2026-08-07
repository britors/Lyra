#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

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

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![discover_storage])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Lyra Installer");
}
