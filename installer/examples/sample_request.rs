//! Prints an `ExecutionRequest` JSON line for a whole-disk, direct-layout
//! plan targeting the disk given as the first argument (default `/dev/sda`)
//! — pipe it into `lyra-installer-service`'s stdin. Runs real discovery
//! (`SystemDiscoveryBackend`), so the printed plan matches exactly what the
//! service will re-discover when it revalidates.
//!
//! Used by `installer/service/test-loop-device.sh` to drive the service
//! against a disposable loop device.

use std::env;
use std::path::PathBuf;

use lyra_installer_core::service::ExecutionRequest;
use lyra_installer_core::storage::{
    DiscoveryBackend, GuidedChoice, PlanBuilder, RawTarget, SystemDiscoveryBackend, VolumeLayer,
};

fn main() {
    let disk = env::args().nth(1).unwrap_or_else(|| "/dev/sda".to_string());

    let snapshot = SystemDiscoveryBackend.snapshot().unwrap_or_else(|error| {
        eprintln!("descoberta falhou: {error}");
        std::process::exit(1);
    });

    let choice = GuidedChoice {
        raw_target: Some(RawTarget::Disk(PathBuf::from(&disk))),
        volume_layer: VolumeLayer::Direct,
    };
    let plan = PlanBuilder::new(&snapshot).build(&choice).unwrap_or_else(|error| {
        eprintln!("plano inválido para {disk}: {:?}", error.0);
        std::process::exit(1);
    });

    let request = ExecutionRequest { choice, plan };
    println!("{}", serde_json::to_string(&request).expect("request always serializes"));
}
