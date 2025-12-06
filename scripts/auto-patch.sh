#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/security/auto-patch.log"
SNAPSHOT_DIR="/var/backups/pre-patch"
LOCK_FILE="/var/run/auto-patch.lock"
MAX_LOG_SIZE=10485760  # 10MB

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "ERROR: Another instance is running (PID: $pid)"
            exit 1
        else
            log "WARN: Stale lock file found, removing"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

rotate_logs() {
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.1"
        log "Log rotated"
    fi
}

create_snapshot() {
    log "Creating pre-patch snapshot..."

    mkdir -p "$SNAPSHOT_DIR"
    local snapshot_file="${SNAPSHOT_DIR}/packages-$(date +%Y%m%d-%H%M%S).list"

    dpkg --get-selections > "$snapshot_file"
    log "Package snapshot saved to $snapshot_file"

    # Keep only last 5 snapshots
    ls -t "${SNAPSHOT_DIR}"/packages-*.list 2>/dev/null | tail -n +6 | xargs -r rm -f
}

check_disk_space() {
    log "Checking disk space..."

    local available
    available=$(df -P /var | awk 'NR==2 {print $4}')

    if [[ $available -lt 1048576 ]]; then  # Less than 1GB
        log "ERROR: Insufficient disk space (${available}KB available)"
        exit 1
    fi

    log "Disk space OK (${available}KB available)"
}

check_network() {
    log "Checking network connectivity..."

    if ! ping -c 1 -W 5 archive.ubuntu.com >/dev/null 2>&1; then
        if ! ping -c 1 -W 5 security.ubuntu.com >/dev/null 2>&1; then
            log "ERROR: No network connectivity to update servers"
            exit 1
        fi
    fi

    log "Network connectivity OK"
}

update_package_lists() {
    log "Updating package lists..."

    if ! apt-get update -qq; then
        log "ERROR: Failed to update package lists"
        exit 1
    fi

    log "Package lists updated"
}

check_pending_updates() {
    log "Checking for pending security updates..."

    local updates
    updates=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo "0")

    if [[ $updates -eq 0 ]]; then
        log "No updates available"
        return 1
    fi

    log "Found $updates pending update(s)"
    apt-get -s upgrade 2>/dev/null | grep "^Inst" | head -20 | while read -r line; do
        log "  $line"
    done

    return 0
}

run_security_updates() {
    log "Installing security updates..."

    if ! DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        upgrade; then
        log "ERROR: Update installation failed"
        return 1
    fi

    log "Security updates installed successfully"
}

check_services() {
    log "Checking if services need restart..."

    if command -v needrestart >/dev/null 2>&1; then
        needrestart -b 2>/dev/null | while read -r line; do
            log "  $line"
        done
    fi
}

cleanup() {
    log "Cleaning up..."

    apt-get -y autoremove -qq
    apt-get -y autoclean -qq

    log "Cleanup complete"
}

send_notification() {
    local status=$1
    local message=$2

    log "Patch status: $status - $message"

    # Send email if mail is configured
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "[Auto-Patch] $status on $(hostname)" root 2>/dev/null || true
    fi
}

main() {
    log "=== Starting automated patching ==="

    check_root
    acquire_lock
    rotate_logs

    check_disk_space
    check_network

    create_snapshot
    update_package_lists

    if check_pending_updates; then
        if run_security_updates; then
            check_services
            cleanup
            send_notification "SUCCESS" "Security updates installed successfully"
        else
            send_notification "FAILED" "Security update installation failed"
            exit 1
        fi
    else
        log "System is up to date"
    fi

    log "=== Automated patching complete ==="
}

main "$@"
