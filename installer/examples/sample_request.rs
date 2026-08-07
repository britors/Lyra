use std::path::PathBuf;

use lyra_installer_core::service::ExecutionRequest;
use lyra_installer_core::storage::{
    Disk, DeviceRole, GuidedChoice, PlanBuilder, RawTarget, StorageSnapshot, Transport, VolumeLayer,
};

fn main() {
    let snapshot = StorageSnapshot {
        uefi: true,
        disks: vec![Disk {
            path: PathBuf::from("/dev/sda"),
            kname: "sda".to_string(),
            size_bytes: 40 * 1024 * 1024 * 1024,
            transport: Transport::Sata,
            vendor: None,
            model: None,
            removable: false,
            is_live_media: false,
            role: DeviceRole::Free,
            partitions: Vec::new(),
        }],
        raid_arrays: Vec::new(),
        volume_groups: Vec::new(),
        logical_volumes: Vec::new(),
    };
    let choice = GuidedChoice {
        raw_target: Some(RawTarget::Disk(PathBuf::from("/dev/sda"))),
        volume_layer: VolumeLayer::Direct,
    };
    let plan = PlanBuilder::new(&snapshot).build(&choice).expect("fixture plan should be valid");
    let request = ExecutionRequest { choice, plan };
    println!("{}", serde_json::to_string(&request).unwrap());
}
