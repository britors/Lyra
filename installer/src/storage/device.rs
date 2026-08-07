//! Snapshot of the block-device state of the machine running the installer.
//!
//! Devices are kept as flat, path-referenced collections rather than a
//! nested tree: an LVM volume group can span physical volumes on several
//! disks, which is a graph, not a tree, and `lsblk` itself represents that
//! by duplicating holder devices under every slave. Flat collections plus
//! `PathBuf` references are simpler to validate and to build fixtures for.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct StorageSnapshot {
    pub uefi: bool,
    pub disks: Vec<Disk>,
    pub raid_arrays: Vec<RaidArray>,
    pub volume_groups: Vec<VolumeGroup>,
    pub logical_volumes: Vec<LogicalVolume>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Transport {
    Nvme,
    Sata,
    Virtio,
    Usb,
    Unknown,
}

/// What a disk is currently used for, decided by discovery before any plan
/// is built. Only `Free` disks may be offered as a whole-disk install target
/// or as a RAID/LVM member.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeviceRole {
    Free,
    RaidMember,
    LvmPhysicalVolume,
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Disk {
    pub path: PathBuf,
    pub kname: String,
    pub size_bytes: u64,
    pub transport: Transport,
    pub vendor: Option<String>,
    pub model: Option<String>,
    pub removable: bool,
    pub is_live_media: bool,
    pub role: DeviceRole,
    pub partitions: Vec<Partition>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Partition {
    pub path: PathBuf,
    pub number: u32,
    pub size_bytes: u64,
    pub filesystem: Option<String>,
    pub mountpoints: Vec<PathBuf>,
    pub part_type: Option<String>,
    pub uuid: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RaidLevel {
    Raid0,
    Raid1,
    Raid5,
    Raid6,
    Raid10,
}

impl RaidLevel {
    /// Minimum number of member devices a level needs to be created or to
    /// be considered a non-degraded array.
    pub fn minimum_members(self) -> usize {
        match self {
            RaidLevel::Raid0 | RaidLevel::Raid1 => 2,
            RaidLevel::Raid5 => 3,
            RaidLevel::Raid6 | RaidLevel::Raid10 => 4,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RaidArray {
    pub path: PathBuf,
    pub level: RaidLevel,
    pub members: Vec<PathBuf>,
    pub degraded: bool,
    pub size_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VolumeGroup {
    pub name: String,
    pub physical_volumes: Vec<PathBuf>,
    pub size_bytes: u64,
    pub free_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogicalVolume {
    pub vg: String,
    pub name: String,
    pub path: PathBuf,
    pub size_bytes: u64,
}
