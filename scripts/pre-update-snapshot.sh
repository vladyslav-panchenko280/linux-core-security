#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/security/snapshot.log"
SNAPSHOT_DIR="/var/backups/system-snapshots"
MAX_SNAPSHOTS=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

create_snapshot_dir() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_path="${SNAPSHOT_DIR}/${timestamp}"

    mkdir -p "$snapshot_path"
    echo "$snapshot_path"
}

snapshot_packages() {
    local snapshot_path=$1
    log "Capturing package state..."

    dpkg --get-selections > "${snapshot_path}/dpkg-selections.list"
    dpkg -l > "${snapshot_path}/dpkg-list.txt"
    apt-mark showmanual > "${snapshot_path}/manually-installed.list"
    apt-mark showauto > "${snapshot_path}/auto-installed.list"

    if command -v snap >/dev/null 2>&1; then
        snap list > "${snapshot_path}/snap-list.txt" 2>/dev/null || true
    fi

    log "  Package state saved"
}

snapshot_configs() {
    local snapshot_path=$1
    log "Backing up configuration files..."

    local config_dirs=(
        "/etc/sysctl.d"
        "/etc/security"
        "/etc/apparmor.d"
        "/etc/audit"
        "/etc/ssh"
        "/etc/pam.d"
        "/etc/apt"
    )

    mkdir -p "${snapshot_path}/configs"

    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local basename
            basename=$(basename "$dir")
            cp -r "$dir" "${snapshot_path}/configs/${basename}" 2>/dev/null || true
        fi
    done

    log "  Configuration files backed up"
}

snapshot_services() {
    local snapshot_path=$1
    log "Capturing service state..."

    systemctl list-units --type=service --state=running > "${snapshot_path}/running-services.txt" 2>/dev/null || true
    systemctl list-unit-files --type=service > "${snapshot_path}/all-services.txt" 2>/dev/null || true

    log "  Service state saved"
}

snapshot_kernel() {
    local snapshot_path=$1
    log "Capturing kernel information..."

    {
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime)"
        echo ""
        echo "Loaded modules:"
        lsmod
        echo ""
        echo "Kernel parameters:"
        sysctl -a 2>/dev/null
    } > "${snapshot_path}/kernel-info.txt"

    log "  Kernel information saved"
}

snapshot_network() {
    local snapshot_path=$1
    log "Capturing network configuration..."

    {
        echo "=== IP Addresses ==="
        ip addr
        echo ""
        echo "=== Routes ==="
        ip route
        echo ""
        echo "=== Listening Ports ==="
        ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null
        echo ""
        echo "=== Firewall Rules ==="
        iptables -L -n 2>/dev/null || echo "iptables not available"
    } > "${snapshot_path}/network-info.txt"

    log "  Network configuration saved"
}

create_manifest() {
    local snapshot_path=$1
    log "Creating snapshot manifest..."

    {
        echo "Snapshot Manifest"
        echo "================"
        echo "Created: $(date -Iseconds)"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo ""
        echo "Contents:"
        find "$snapshot_path" -type f | while read -r file; do
            echo "  - ${file#$snapshot_path/}"
        done
    } > "${snapshot_path}/MANIFEST.txt"

    log "  Manifest created"
}

compress_snapshot() {
    local snapshot_path=$1
    log "Compressing snapshot..."

    local archive_name="${snapshot_path}.tar.gz"
    tar -czf "$archive_name" -C "$(dirname "$snapshot_path")" "$(basename "$snapshot_path")"
    rm -rf "$snapshot_path"

    log "  Snapshot compressed: $archive_name"
    echo "$archive_name"
}

cleanup_old_snapshots() {
    log "Cleaning up old snapshots..."

    local snapshot_count
    snapshot_count=$(ls -1 "${SNAPSHOT_DIR}"/*.tar.gz 2>/dev/null | wc -l)

    if [[ $snapshot_count -gt $MAX_SNAPSHOTS ]]; then
        local to_remove=$((snapshot_count - MAX_SNAPSHOTS))
        ls -1t "${SNAPSHOT_DIR}"/*.tar.gz | tail -n "$to_remove" | while read -r file; do
            log "  Removing old snapshot: $file"
            rm -f "$file"
        done
    fi

    log "  Cleanup complete"
}

restore_snapshot() {
    local archive=$1

    if [[ ! -f "$archive" ]]; then
        log "ERROR: Snapshot archive not found: $archive"
        exit 1
    fi

    log "Restoring from snapshot: $archive"

    local temp_dir
    temp_dir=$(mktemp -d)
    tar -xzf "$archive" -C "$temp_dir"

    local snapshot_dir
    snapshot_dir=$(find "$temp_dir" -maxdepth 1 -type d | tail -1)

    # Restore packages
    if [[ -f "${snapshot_dir}/dpkg-selections.list" ]]; then
        log "  Restoring package selections..."
        dpkg --set-selections < "${snapshot_dir}/dpkg-selections.list"
        apt-get dselect-upgrade -y
    fi

    rm -rf "$temp_dir"
    log "Restore complete"
}

main() {
    check_root

    case "${1:-create}" in
        create)
            log "=== Creating System Snapshot ==="
            mkdir -p "$SNAPSHOT_DIR"

            local snapshot_path
            snapshot_path=$(create_snapshot_dir)

            snapshot_packages "$snapshot_path"
            snapshot_configs "$snapshot_path"
            snapshot_services "$snapshot_path"
            snapshot_kernel "$snapshot_path"
            snapshot_network "$snapshot_path"
            create_manifest "$snapshot_path"

            local archive
            archive=$(compress_snapshot "$snapshot_path")

            cleanup_old_snapshots

            log "=== Snapshot Complete ==="
            log "Archive: $archive"
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                log "ERROR: Please specify snapshot archive to restore"
                echo "Usage: $0 restore /path/to/snapshot.tar.gz"
                exit 1
            fi
            restore_snapshot "$2"
            ;;
        list)
            log "Available snapshots:"
            ls -lh "${SNAPSHOT_DIR}"/*.tar.gz 2>/dev/null || echo "No snapshots found"
            ;;
        *)
            echo "Usage: $0 [create|restore <archive>|list]"
            exit 1
            ;;
    esac
}

main "$@"
