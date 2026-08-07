//! Read-only discovery of the machine's current block-device state.
//!
//! Discovery never touches the disk and never needs the privileged service —
//! it runs as the live-session user, exactly like `docs/installer-architecture.md`
//! describes the frontend doing ("O frontend descobre opções..."). Only plan
//! *execution* (issue #40) crosses the polkit privilege boundary.

use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use super::device::{Disk, DeviceRole, LogicalVolume, Partition, RaidArray, RaidLevel, StorageSnapshot, Transport, VolumeGroup};

#[derive(Debug)]
pub enum DiscoveryError {
    /// `lsblk` itself failed or is missing — without it we have no reliable
    /// disk/partition data at all, so this is fatal.
    LsblkUnavailable(String),
    Parse(String),
}

impl fmt::Display for DiscoveryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DiscoveryError::LsblkUnavailable(reason) => {
                write!(f, "não foi possível listar os discos (lsblk): {reason}")
            }
            DiscoveryError::Parse(reason) => write!(f, "resposta inesperada do lsblk: {reason}"),
        }
    }
}

pub trait DiscoveryBackend {
    fn snapshot(&self) -> Result<StorageSnapshot, DiscoveryError>;
}

/// Returns a pre-built snapshot — used by tests, which can't run `lsblk`,
/// `pvs` or read real `/sys/block` state for arbitrary machine shapes
/// (empty disk, degraded RAID, existing ESP, ...).
#[cfg(test)]
pub struct FixtureBackend(pub StorageSnapshot);

#[cfg(test)]
impl DiscoveryBackend for FixtureBackend {
    fn snapshot(&self) -> Result<StorageSnapshot, DiscoveryError> {
        Ok(self.0.clone())
    }
}

/// Real backend: shells out to `lsblk`/sysfs/`pvs`/`vgs`/`lvs` via argv
/// (never through a shell interpreter, per the architecture doc's "chamadas
/// sem shell").
pub struct SystemDiscoveryBackend;

impl DiscoveryBackend for SystemDiscoveryBackend {
    fn snapshot(&self) -> Result<StorageSnapshot, DiscoveryError> {
        let mut disks = discover_disks()?;
        let raid_arrays = discover_raid_arrays();
        let (volume_groups, logical_volumes) = discover_lvm();
        apply_membership_roles(&mut disks, &raid_arrays, &volume_groups);

        Ok(StorageSnapshot {
            uefi: Path::new("/sys/firmware/efi").is_dir(),
            disks,
            raid_arrays,
            volume_groups,
            logical_volumes,
        })
    }
}

/// A disk used *whole* as a bare RAID member or LVM PV (no partition table
/// of its own, e.g. `pvcreate /dev/sdb` directly) has nothing in its own
/// `children` to reveal that — cross-reference against the arrays/VGs
/// already discovered so it isn't mistaken for a free, installable disk.
/// Partition-level membership doesn't need this: a disk with any partition
/// at all is already `Unsupported` from `disk_from_lsblk`.
fn apply_membership_roles(disks: &mut [Disk], raid_arrays: &[RaidArray], volume_groups: &[VolumeGroup]) {
    let raid_members: Vec<&PathBuf> = raid_arrays.iter().flat_map(|r| r.members.iter()).collect();
    let pv_members: Vec<&PathBuf> = volume_groups.iter().flat_map(|vg| vg.physical_volumes.iter()).collect();

    for disk in disks.iter_mut() {
        if disk.role != DeviceRole::Free {
            continue;
        }
        if raid_members.contains(&&disk.path) {
            disk.role = DeviceRole::RaidMember;
        } else if pv_members.contains(&&disk.path) {
            disk.role = DeviceRole::LvmPhysicalVolume;
        }
    }
}

// --- lsblk -----------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct LsblkOutput {
    blockdevices: Vec<LsblkDevice>,
}

#[derive(Debug, Deserialize)]
struct LsblkDevice {
    name: String,
    kname: String,
    #[serde(rename = "type")]
    kind: String,
    size: u64,
    #[serde(default)]
    tran: Option<String>,
    #[serde(default)]
    vendor: Option<String>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    rm: bool,
    #[serde(default)]
    fstype: Option<String>,
    #[serde(default)]
    mountpoints: Vec<Option<String>>,
    #[serde(default)]
    parttype: Option<String>,
    #[serde(default)]
    uuid: Option<String>,
    #[serde(default)]
    children: Vec<LsblkDevice>,
}

fn discover_disks() -> Result<Vec<Disk>, DiscoveryError> {
    let output = Command::new("lsblk")
        .args([
            "--json",
            "--bytes",
            "--output",
            "NAME,KNAME,TYPE,SIZE,TRAN,VENDOR,MODEL,RM,FSTYPE,MOUNTPOINTS,PARTTYPE,UUID",
        ])
        .output()
        .map_err(|error| DiscoveryError::LsblkUnavailable(error.to_string()))?;

    if !output.status.success() {
        return Err(DiscoveryError::LsblkUnavailable(
            String::from_utf8_lossy(&output.stderr).into_owned(),
        ));
    }

    let parsed: LsblkOutput = serde_json::from_slice(&output.stdout)
        .map_err(|error| DiscoveryError::Parse(error.to_string()))?;

    let live_media = live_media_disks();

    Ok(parsed
        .blockdevices
        .into_iter()
        // "loop" is included so a disposable image set up via `losetup` can
        // stand in for a real disk during integration testing (see
        // installer/service/test-loop-device.sh) - no real install flow
        // would ever have a live squashfs's own loop device pass the
        // eligibility checks in storage::plan (occupied/live-media rules).
        .filter(|device| device.kind == "disk" || device.kind == "loop")
        .map(|device| disk_from_lsblk(device, &live_media))
        .collect())
}

fn disk_from_lsblk(device: LsblkDevice, live_media: &[String]) -> Disk {
    let is_live_media = live_media.contains(&device.kname);
    let partitions: Vec<Partition> = device
        .children
        .into_iter()
        .filter(|child| child.kind == "part")
        .map(partition_from_lsblk)
        .collect();

    let role = if is_live_media {
        DeviceRole::Unsupported
    } else if !partitions.is_empty() {
        DeviceRole::Unsupported
    } else {
        DeviceRole::Free
    };

    Disk {
        path: PathBuf::from(format!("/dev/{}", device.kname)),
        kname: device.kname,
        size_bytes: device.size,
        transport: transport_from_str(device.tran.as_deref()),
        vendor: non_empty(device.vendor),
        model: non_empty(device.model),
        removable: device.rm,
        is_live_media,
        role,
        partitions,
    }
}

fn partition_from_lsblk(device: LsblkDevice) -> Partition {
    Partition {
        path: PathBuf::from(format!("/dev/{}", device.kname)),
        number: trailing_digits(&device.name).parse().unwrap_or(0),
        size_bytes: device.size,
        filesystem: non_empty(device.fstype),
        mountpoints: device
            .mountpoints
            .into_iter()
            .flatten()
            .map(PathBuf::from)
            .collect(),
        part_type: non_empty(device.parttype),
        uuid: non_empty(device.uuid),
    }
}

fn transport_from_str(tran: Option<&str>) -> Transport {
    match tran {
        Some("nvme") => Transport::Nvme,
        Some("sata") | Some("ata") => Transport::Sata,
        Some("virtio") => Transport::Virtio,
        Some("usb") => Transport::Usb,
        _ => Transport::Unknown,
    }
}

fn non_empty(value: Option<String>) -> Option<String> {
    value.map(|v| v.trim().to_string()).filter(|v| !v.is_empty())
}

/// The partition number suffix of a device name, e.g. `"3"` from both
/// `"sda3"` and `"nvme0n1p3"`. A leading-trim would stop at the first digit
/// it meets (`"nvme0n1p3"` has one right after `nvme`), so this reads from
/// the end instead.
fn trailing_digits(name: &str) -> String {
    name.chars().rev().take_while(|c| c.is_ascii_digit()).collect::<Vec<_>>().into_iter().rev().collect()
}

/// Resolve the disk(s) backing the current root and the live boot media, by
/// walking `/proc/mounts` up to the parent disk. Neither may ever be offered
/// as an install target.
fn live_media_disks() -> Vec<String> {
    let mounts = fs::read_to_string("/proc/mounts").unwrap_or_default();
    let mut disks = Vec::new();

    for line in mounts.lines() {
        let mut fields = line.split_whitespace();
        let Some(source) = fields.next() else { continue };
        let Some(mount_point) = fields.next() else { continue };

        if mount_point != "/" && !mount_point.starts_with("/run/overlay") {
            continue;
        }
        if let Some(kname) = source.strip_prefix("/dev/").map(parent_disk_kname) {
            disks.push(kname);
        }
    }

    disks
}

/// `/sys/class/block/<part>/../<disk>` — strip trailing partition digits as a
/// fallback when the sysfs symlink itself isn't readable.
fn parent_disk_kname(kname: &str) -> String {
    let sys_path = format!("/sys/class/block/{kname}");
    if let Ok(target) = fs::read_link(&sys_path) {
        if let Some(parent) = target
            .parent()
            .and_then(|p| p.file_name())
            .and_then(|f| f.to_str())
        {
            if parent != kname {
                return parent.to_string();
            }
        }
    }
    kname
        .trim_end_matches(|c: char| c.is_ascii_digit())
        .trim_end_matches('p')
        .to_string()
}

// --- RAID (sysfs, no mdadm binary required for detection) ------------------

fn discover_raid_arrays() -> Vec<RaidArray> {
    let Ok(entries) = fs::read_dir("/sys/block") else {
        return Vec::new();
    };

    entries
        .filter_map(Result::ok)
        .filter(|entry| entry.file_name().to_string_lossy().starts_with("md"))
        .filter_map(|entry| raid_array_from_sysfs(&entry.path()))
        .collect()
}

fn raid_array_from_sysfs(disk_path: &Path) -> Option<RaidArray> {
    let name = disk_path.file_name()?.to_str()?.to_string();
    let md_dir = disk_path.join("md");
    if !md_dir.is_dir() {
        return None;
    }

    let level = read_sysfs(&md_dir, "level").and_then(|v| raid_level_from_str(&v))?;
    let degraded = read_sysfs(&md_dir, "degraded").is_some_and(|v| v.trim() != "0");
    let size_bytes = read_sysfs(disk_path, "size")
        .and_then(|v| v.trim().parse::<u64>().ok())
        .map(|sectors| sectors * 512)
        .unwrap_or(0);

    let members = fs::read_dir(&md_dir)
        .into_iter()
        .flatten()
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let file_name = entry.file_name();
            let file_name = file_name.to_str()?;
            file_name
                .strip_prefix("dev-")
                .map(|kname| PathBuf::from(format!("/dev/{kname}")))
        })
        .collect();

    Some(RaidArray {
        path: PathBuf::from(format!("/dev/{name}")),
        level,
        members,
        degraded,
        size_bytes,
    })
}

fn raid_level_from_str(value: &str) -> Option<RaidLevel> {
    match value.trim() {
        "raid0" => Some(RaidLevel::Raid0),
        "raid1" => Some(RaidLevel::Raid1),
        "raid5" => Some(RaidLevel::Raid5),
        "raid6" => Some(RaidLevel::Raid6),
        "raid10" => Some(RaidLevel::Raid10),
        _ => None,
    }
}

fn read_sysfs(dir: &Path, file: &str) -> Option<String> {
    fs::read_to_string(dir.join(file)).ok()
}

// --- LVM (pvs/vgs/lvs, best-effort: absent binaries are not a hard error) --

#[derive(Debug, Deserialize)]
struct VgReportOutput {
    report: Vec<VgReportEntry>,
}

#[derive(Debug, Deserialize)]
struct VgReportEntry {
    #[serde(default)]
    vg: Vec<VgRow>,
}

#[derive(Debug, Deserialize)]
struct VgRow {
    vg_name: String,
    #[serde(default)]
    pv_name: Vec<String>,
    vg_size: String,
    vg_free: String,
}

#[derive(Debug, Deserialize)]
struct LvReportOutput {
    report: Vec<LvReportEntry>,
}

#[derive(Debug, Deserialize)]
struct LvReportEntry {
    #[serde(default)]
    lv: Vec<LvRow>,
}

#[derive(Debug, Deserialize)]
struct LvRow {
    lv_name: String,
    vg_name: String,
    lv_size: String,
    lv_path: String,
}

fn discover_lvm() -> (Vec<VolumeGroup>, Vec<LogicalVolume>) {
    let volume_groups = run_vgs()
        .map(|rows| {
            group_vg_rows(rows)
                .into_iter()
                .map(|(name, physical_volumes, size_bytes, free_bytes)| VolumeGroup {
                    name,
                    physical_volumes: physical_volumes.into_iter().map(PathBuf::from).collect(),
                    size_bytes,
                    free_bytes,
                })
                .collect()
        })
        .unwrap_or_default();

    let logical_volumes = run_lvs()
        .map(|rows| {
            rows.into_iter()
                .map(|row| LogicalVolume {
                    vg: row.vg_name,
                    name: row.lv_name,
                    path: PathBuf::from(row.lv_path),
                    size_bytes: parse_lvm_bytes(&row.lv_size),
                })
                .collect()
        })
        .unwrap_or_default();

    (volume_groups, logical_volumes)
}

fn group_vg_rows(rows: Vec<VgRow>) -> Vec<(String, Vec<String>, u64, u64)> {
    let mut groups: Vec<(String, Vec<String>, u64, u64)> = Vec::new();
    for row in rows {
        let size = parse_lvm_bytes(&row.vg_size);
        let free = parse_lvm_bytes(&row.vg_free);
        if let Some(existing) = groups.iter_mut().find(|(name, ..)| *name == row.vg_name) {
            existing.1.extend(row.pv_name);
        } else {
            groups.push((row.vg_name, row.pv_name, size, free));
        }
    }
    groups
}

/// lvm2's `--units b --nosuffix` output is a bare byte count.
fn parse_lvm_bytes(value: &str) -> u64 {
    value.trim().parse().unwrap_or(0)
}

fn run_vgs() -> Option<Vec<VgRow>> {
    let output = lvm_command("vgs", "vg_name,pv_name,vg_size,vg_free")?;
    let parsed: VgReportOutput = serde_json::from_slice(&output).ok()?;
    Some(parsed.report.into_iter().next()?.vg)
}

fn run_lvs() -> Option<Vec<LvRow>> {
    let output = lvm_command("lvs", "lv_name,vg_name,lv_size,lv_path")?;
    let parsed: LvReportOutput = serde_json::from_slice(&output).ok()?;
    Some(parsed.report.into_iter().next()?.lv)
}

/// Runs an lvm2 reporting command and returns its stdout. Binary missing or
/// non-zero exit (e.g. lvm2 not installed on this image yet, or the lock
/// directory under `/run/lock/lvm` isn't readable without root) yields
/// `None` rather than an error — LVM data is simply unavailable, not fatal.
/// `vgs`/`pvs`/`lvs` live under `/usr/sbin` on Leap, which isn't on an
/// unprivileged user's `$PATH` by default — confirmed by running this
/// against a real Leap-family desktop, where the bare command name silently
/// resolved to "not found" (verified against a real system, not guessed).
fn lvm_command(command: &str, fields: &str) -> Option<Vec<u8>> {
    let candidates = [command.to_string(), format!("/usr/sbin/{command}"), format!("/sbin/{command}")];

    for candidate in candidates {
        let Ok(output) = Command::new(&candidate)
            .args(["--reportformat", "json", "--units", "b", "--nosuffix", "-o", fields])
            .output()
        else {
            continue;
        };
        if output.status.success() {
            return Some(output.stdout);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Not run by default (`cargo test`) — depends on the real machine's
    /// block devices, which fixtures deliberately avoid. Run explicitly with
    /// `cargo test -- --ignored` to sanity-check `lsblk`/sysfs/lvm2 parsing
    /// against whatever hardware is actually present.
    #[test]
    #[ignore]
    fn system_backend_produces_a_snapshot_on_this_machine() {
        let snapshot = SystemDiscoveryBackend.snapshot().expect("discovery should not fail");
        assert!(!snapshot.disks.is_empty(), "expected at least one disk");
        println!("{snapshot:#?}");
    }
}
