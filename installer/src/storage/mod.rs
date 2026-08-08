//! Disk/RAID/LVM discovery and declarative install planning (issue #39).
//!
//! Two concerns, kept separate: [`discovery`] only *reads* the machine's
//! current block-device state (runs unprivileged, as the live user);
//! [`plan`] turns that state plus a user's choice into an immutable,
//! dry-run [`InstallPlan`] — no I/O, so it's safe to call from the frontend
//! before any privilege escalation. Executing a plan is out of scope here
//! (issues #37/#40).

pub mod device;
pub mod discovery;
pub mod plan;

pub use device::{
    DeviceRole, Disk, LogicalVolume, Partition, RaidArray, RaidLevel, StorageSnapshot, Transport,
    VolumeGroup,
};
pub use discovery::{DiscoveryBackend, DiscoveryError, SystemDiscoveryBackend};
pub use plan::{
    DISK_SWAP_SIZE_BYTES, DestructiveSummary, EspPlan, FilesystemPlan, GuidedChoice,
    INSTALL_PLAN_SCHEMA_VERSION, InstallPlan, LogicalVolumePlan, PlanBuilder, PlanError, RawTarget,
    SizePolicy, SubvolumePlan, SwapChoice, SwapPlan, VolumeLayer,
};

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    fn disk(kname: &str, size_bytes: u64) -> Disk {
        Disk {
            path: PathBuf::from(format!("/dev/{kname}")),
            kname: kname.to_string(),
            size_bytes,
            transport: Transport::Nvme,
            vendor: Some("QEMU".to_string()),
            model: Some("QEMU HARDDISK".to_string()),
            removable: false,
            is_live_media: false,
            role: DeviceRole::Free,
            partitions: Vec::new(),
        }
    }

    const LARGE: u64 = 40 * 1024 * 1024 * 1024;
    const TOO_SMALL: u64 = 5 * 1024 * 1024 * 1024;

    fn snapshot_with_disks(disks: Vec<Disk>) -> StorageSnapshot {
        StorageSnapshot {
            uefi: true,
            disks,
            raid_arrays: Vec::new(),
            volume_groups: Vec::new(),
            logical_volumes: Vec::new(),
        }
    }

    fn whole_disk_choice(path: &str) -> GuidedChoice {
        GuidedChoice {
            raw_target: Some(RawTarget::Disk(PathBuf::from(path))),
            volume_layer: VolumeLayer::Direct,
            swap: SwapChoice::Zram,
        }
    }

    #[test]
    fn empty_disk_is_an_eligible_target() {
        let backend = discovery::FixtureBackend(snapshot_with_disks(vec![disk("sda", LARGE)]));
        let snapshot = backend.snapshot().expect("fixture backend never fails");
        let plan = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sda"))
            .expect("empty disk should be accepted");

        assert_eq!(
            plan.raw_target,
            Some(RawTarget::Disk(PathBuf::from("/dev/sda")))
        );
        assert!(plan.destructive_summary.erased.is_empty());
        assert_eq!(plan.schema_version, INSTALL_PLAN_SCHEMA_VERSION);
        assert_eq!(plan.root_filesystem, FilesystemPlan::default());
    }

    #[test]
    fn serialized_plan_carries_an_explicit_schema_version() {
        let snapshot = snapshot_with_disks(vec![disk("sda", LARGE)]);
        let plan = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sda"))
            .expect("fixture plan should be valid");

        let json = serde_json::to_value(plan).expect("plan should serialize");
        assert_eq!(json["schema_version"], INSTALL_PLAN_SCHEMA_VERSION);
    }

    #[test]
    fn guided_swap_choices_become_explicit_plans() {
        let snapshot = snapshot_with_disks(vec![disk("sda", LARGE)]);
        let mut choice = whole_disk_choice("/dev/sda");

        choice.swap = SwapChoice::None;
        let none = PlanBuilder::new(&snapshot).build(&choice).unwrap();
        assert_eq!(none.swap, SwapPlan::None);

        choice.swap = SwapChoice::Disk;
        let disk = PlanBuilder::new(&snapshot).build(&choice).unwrap();
        assert_eq!(
            disk.swap,
            SwapPlan::Partition {
                size_bytes: DISK_SWAP_SIZE_BYTES
            }
        );

        choice.swap = SwapChoice::Zram;
        let zram = PlanBuilder::new(&snapshot).build(&choice).unwrap();
        assert_eq!(zram.swap, SwapPlan::Zram);
    }

    #[test]
    fn disk_swap_space_is_reserved_before_approving_the_root() {
        let barely_root_only = plan::MINIMUM_ROOT_SIZE_BYTES + plan::ESP_RECOMMENDED_SIZE_BYTES;
        let snapshot = snapshot_with_disks(vec![disk("sda", barely_root_only)]);
        let mut choice = whole_disk_choice("/dev/sda");
        choice.swap = SwapChoice::Disk;

        let error = PlanBuilder::new(&snapshot).build(&choice).unwrap_err();
        assert!(
            error
                .0
                .iter()
                .any(|reason| reason.contains("após ESP/swap"))
        );
    }

    #[test]
    fn occupied_disk_is_blocked_with_a_clear_reason() {
        let mut occupied = disk("sda", LARGE);
        occupied.role = DeviceRole::Unsupported;
        occupied.partitions.push(Partition {
            path: PathBuf::from("/dev/sda1"),
            number: 1,
            size_bytes: LARGE,
            filesystem: Some("ext4".to_string()),
            mountpoints: vec![PathBuf::from("/mnt/dados")],
            part_type: None,
            uuid: None,
        });
        let snapshot = snapshot_with_disks(vec![occupied]);

        let error = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sda"))
            .unwrap_err();

        assert!(
            error
                .0
                .iter()
                .any(|reason| reason.contains("partições ou dados"))
        );
    }

    #[test]
    fn existing_esp_is_reused_never_recreated() {
        let mut with_esp = disk("sda", LARGE);
        with_esp.partitions.push(Partition {
            path: PathBuf::from("/dev/sda1"),
            number: 1,
            size_bytes: 300 * 1024 * 1024,
            filesystem: Some("vfat".to_string()),
            mountpoints: vec![PathBuf::from("/boot/efi")],
            part_type: Some("esp".to_string()),
            uuid: None,
        });
        // The ESP disk itself stays free-role: only its partition is the ESP,
        // the rest of the disk (or another disk) is still a valid target.
        let target = disk("sdb", LARGE);
        let snapshot = snapshot_with_disks(vec![with_esp, target]);

        let plan = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sdb"))
            .expect("target disk should be accepted");

        assert_eq!(
            plan.esp,
            EspPlan::Reuse {
                path: PathBuf::from("/dev/sda1")
            }
        );
    }

    #[test]
    fn insufficient_space_is_blocked() {
        let snapshot = snapshot_with_disks(vec![disk("sda", TOO_SMALL)]);
        let error = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sda"))
            .unwrap_err();

        assert!(
            error
                .0
                .iter()
                .any(|reason| reason.contains("espaço insuficiente"))
        );
    }

    #[test]
    fn live_media_is_never_offered_as_a_target() {
        let mut live_usb = disk("sdz", LARGE);
        live_usb.is_live_media = true;
        let snapshot = snapshot_with_disks(vec![live_usb]);

        let error = PlanBuilder::new(&snapshot)
            .build(&whole_disk_choice("/dev/sdz"))
            .unwrap_err();

        assert!(
            error
                .0
                .iter()
                .any(|reason| reason.contains("mídia de instalação"))
        );
    }

    #[test]
    fn healthy_existing_raid1_is_a_valid_target() {
        let snapshot = StorageSnapshot {
            uefi: true,
            disks: Vec::new(),
            raid_arrays: vec![RaidArray {
                path: PathBuf::from("/dev/md0"),
                level: RaidLevel::Raid1,
                members: vec![PathBuf::from("/dev/sda"), PathBuf::from("/dev/sdb")],
                degraded: false,
                size_bytes: LARGE,
            }],
            volume_groups: Vec::new(),
            logical_volumes: Vec::new(),
        };
        let choice = GuidedChoice {
            raw_target: Some(RawTarget::ExistingRaid {
                array: PathBuf::from("/dev/md0"),
            }),
            volume_layer: VolumeLayer::Direct,
            swap: SwapChoice::Zram,
        };

        let plan = PlanBuilder::new(&snapshot)
            .build(&choice)
            .expect("healthy array should be accepted");
        assert_eq!(
            plan.raw_target,
            Some(RawTarget::ExistingRaid {
                array: PathBuf::from("/dev/md0")
            })
        );
    }

    #[test]
    fn degraded_raid_is_blocked_with_a_clear_reason() {
        let snapshot = StorageSnapshot {
            uefi: true,
            disks: Vec::new(),
            raid_arrays: vec![RaidArray {
                path: PathBuf::from("/dev/md0"),
                level: RaidLevel::Raid1,
                members: vec![PathBuf::from("/dev/sda")],
                degraded: true,
                size_bytes: LARGE,
            }],
            volume_groups: Vec::new(),
            logical_volumes: Vec::new(),
        };
        let choice = GuidedChoice {
            raw_target: Some(RawTarget::ExistingRaid {
                array: PathBuf::from("/dev/md0"),
            }),
            volume_layer: VolumeLayer::Direct,
            swap: SwapChoice::Zram,
        };

        let error = PlanBuilder::new(&snapshot).build(&choice).unwrap_err();
        assert!(error.0.iter().any(|reason| reason.contains("degradado")));
    }

    #[test]
    fn new_raid1_with_lvm_on_top_produces_a_valid_plan() {
        let snapshot = snapshot_with_disks(vec![disk("sda", LARGE), disk("sdb", LARGE)]);
        let choice = GuidedChoice {
            raw_target: Some(RawTarget::NewRaid {
                level: RaidLevel::Raid1,
                members: vec![PathBuf::from("/dev/sda"), PathBuf::from("/dev/sdb")],
                name: "md0".to_string(),
            }),
            volume_layer: VolumeLayer::NewVolumeGroup {
                name: "vg-lyra".to_string(),
                logical_volumes: vec![LogicalVolumePlan {
                    name: "root".to_string(),
                    mount_point: PathBuf::from("/"),
                    size: SizePolicy::FillRemaining,
                }],
            },
            swap: SwapChoice::Zram,
        };

        let plan = PlanBuilder::new(&snapshot)
            .build(&choice)
            .expect("RAID1 + LVM should be accepted");
        assert!(matches!(plan.raw_target, Some(RawTarget::NewRaid { .. })));
        assert!(matches!(
            plan.volume_layer,
            VolumeLayer::NewVolumeGroup { .. }
        ));
    }

    #[test]
    fn existing_volume_group_without_enough_free_space_is_blocked() {
        let snapshot = StorageSnapshot {
            uefi: true,
            disks: Vec::new(),
            raid_arrays: Vec::new(),
            volume_groups: vec![VolumeGroup {
                name: "vg-lyra".to_string(),
                physical_volumes: vec![PathBuf::from("/dev/sda1")],
                size_bytes: LARGE,
                free_bytes: TOO_SMALL,
            }],
            logical_volumes: Vec::new(),
        };
        let choice = GuidedChoice {
            raw_target: None,
            volume_layer: VolumeLayer::ExistingVolumeGroup {
                name: "vg-lyra".to_string(),
                logical_volumes: vec![LogicalVolumePlan {
                    name: "root".to_string(),
                    mount_point: PathBuf::from("/"),
                    size: SizePolicy::Fixed(LARGE),
                }],
            },
            swap: SwapChoice::Zram,
        };

        let error = PlanBuilder::new(&snapshot).build(&choice).unwrap_err();
        assert!(error.0.iter().any(|reason| reason.contains("disponível")));
    }
}
