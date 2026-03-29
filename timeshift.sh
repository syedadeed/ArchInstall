#!/bin/bash

set -euo pipefail

MAPPER="/dev/mapper/root"
EFI_DIR="/efi/EFI/Linux"
SNAPSHOTS_DIR="/.snapshots"

#------------------------------Helpers------------------------------

die() {
    echo "Error: $*" >&2
    exit 1
}

check_root() {
    [[ "$EUID" -eq 0 ]] || die "This script must be run as root."
}

get_efi_disk_and_part() {
    local source
    source=$(findmnt -n -o SOURCE /efi) || die "Could not detect /efi mountpoint. Is it mounted?"
    if [[ "$source" == *"nvme"* || "$source" == *"mmcblk"* ]]; then
        EFI_DISK=$(echo "$source" | sed 's/p[0-9]*$//')
        EFI_PART=$(echo "$source" | grep -oP 'p\K[0-9]+$')
    else
        EFI_DISK=$(echo "$source" | sed 's/[0-9]*$//')
        EFI_PART=$(echo "$source" | grep -oP '[0-9]+$')
    fi
}

#------------------------------Create------------------------------

create() {
    local name="$1"
    [[ -z "$name" ]] && die "Usage: $0 -c <snapshot_name>"

    local snapshot_path="${SNAPSHOTS_DIR}/${name}"
    local snapshot_uki="${EFI_DIR}/arch-linux-${name}.efi"
    local preset_file="/etc/mkinitcpio.d/snap-${name}.preset"
    local cmdline_tmp
    cmdline_tmp=$(mktemp --suffix=.conf)

    [[ -d "$snapshot_path" ]] && die "Snapshot '${name}' already exists at ${snapshot_path}."
    [[ -f "$snapshot_uki" ]] && die "UKI for '${name}' already exists at ${snapshot_uki}."

    echo "==> Creating btrfs snapshot: ${snapshot_path}"
    btrfs subvolume snapshot / "$snapshot_path"

    printf 'rootflags=subvol=@snapshots/%s rw' "$name" > "$cmdline_tmp"

    echo "==> Writing mkinitcpio preset: ${preset_file}"
    cat > "$preset_file" << EOF
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')
default_uki="${snapshot_uki}"
default_cmdline="${cmdline_tmp}"
EOF

    echo "==> Building UKI via mkinitcpio"
    mkinitcpio -p "snap-${name}" || {
        rm -f "$preset_file" "$cmdline_tmp"
        die "mkinitcpio failed."
    }

    rm -f "$preset_file" "$cmdline_tmp"

    echo "==> Registering EFI boot entry"
    get_efi_disk_and_part
    efibootmgr --create \
        --disk "$EFI_DISK" \
        --part "$EFI_PART" \
        --label "Arch Linux (${name})" \
        --loader "\\EFI\\Linux\\arch-linux-${name}.efi" \
        --unicode

    echo "==> Done. Snapshot '${name}' created and registered."
}

#------------------------------Delete------------------------------

delete() {
    local name="$1"
    [[ -z "$name" ]] && die "Usage: $0 -d <snapshot_name>"

    local snapshot_path="${SNAPSHOTS_DIR}/${name}"
    local snapshot_uki="${EFI_DIR}/arch-linux-${name}.efi"

    [[ -d "$snapshot_path" ]] || die "Snapshot '${name}' not found at ${snapshot_path}."

    echo "==> Deleting btrfs subvolume: ${snapshot_path}"
    btrfs subvolume delete "$snapshot_path"

    if [[ -f "$snapshot_uki" ]]; then
        echo "==> Deleting UKI: ${snapshot_uki}"
        rm -f "$snapshot_uki"
    else
        echo "Warning: UKI not found at ${snapshot_uki}, skipping."
    fi

    echo "==> Removing EFI boot entry"
    local boot_num
    boot_num=$(efibootmgr | grep "Arch Linux (${name})" | grep -oP 'Boot\K[0-9A-F]+' || true)
    if [[ -n "$boot_num" ]]; then
        efibootmgr --delete-bootnum --bootnum "$boot_num"
    else
        echo "Warning: No EFI entry found for 'Arch Linux (${name})', skipping."
    fi

    echo "==> Done. Snapshot '${name}' deleted."
}

#------------------------------Restore------------------------------

restore() {
    local tmp_mount
    tmp_mount=$(mktemp -d)

    echo "==> Mounting btrfs top-level from ${MAPPER} to ${tmp_mount}"
    mount "$MAPPER" "$tmp_mount"

    echo "==> Clearing @root contents"
    find "${tmp_mount}/@root" -mindepth 1 -delete

    echo "==> Deleting @root subvolume"
    btrfs subvolume delete "${tmp_mount}/@root"

    echo "==> Snapshotting current running '/' into new @root"
    btrfs subvolume snapshot / "${tmp_mount}/@root"

    echo "==> Unmounting ${tmp_mount}"
    umount "$tmp_mount"
    rmdir "$tmp_mount"

    echo "==> Done. Reboot to boot into the restored root via the default UKI."
}

#------------------------------Maintenance------------------------------

maintenance() {
    echo "==> Starting btrfs balance (this may take a while)"
    btrfs balance start --full-balance /

    echo "==> Defragmenting btrfs filesystem"
    btrfs filesystem defragment -r /

    echo "==> Starting btrfs scrub"
    btrfs scrub start /

    echo "==> Done."
}

#------------------------------Entrypoint------------------------------

check_root

case "${1:-}" in
    -c) create "${2:-}" ;;
    -d) delete "${2:-}" ;;
    -r) restore ;;
    -m) maintenance ;;
    *)
        echo "Usage: $0 {-c <n> | -d <n> | -r | -m}"
        exit 1
        ;;
esac
