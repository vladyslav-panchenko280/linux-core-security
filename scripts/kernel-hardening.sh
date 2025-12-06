#!/bin/bash

set -euo pipefail

SYSCTL_CONF="/etc/sysctl.d/99-security.conf"
LOG_FILE="/var/log/security/kernel-hardening.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

apply_sysctl() {
    log "Applying sysctl security parameters..."

    if [[ -f "$SYSCTL_CONF" ]]; then
        sysctl -p "$SYSCTL_CONF" 2>&1 | while read -r line; do
            log "  $line"
        done
        log "Sysctl parameters applied successfully"
    else
        log "ERROR: $SYSCTL_CONF not found"
        exit 1
    fi
}

verify_aslr() {
    log "Verifying ASLR status..."

    local aslr_value
    aslr_value=$(cat /proc/sys/kernel/randomize_va_space)

    case $aslr_value in
        0) log "  WARNING: ASLR is DISABLED" ;;
        1) log "  INFO: ASLR is in conservative mode" ;;
        2) log "  OK: ASLR is fully enabled" ;;
        *) log "  ERROR: Unknown ASLR value: $aslr_value" ;;
    esac
}

verify_memory_protection() {
    log "Verifying memory protection settings..."

    local params=(
        "kernel.kptr_restrict:Kernel pointer restriction"
        "kernel.dmesg_restrict:Dmesg restriction"
        "kernel.yama.ptrace_scope:Ptrace scope"
        "fs.protected_symlinks:Symlink protection"
        "fs.protected_hardlinks:Hardlink protection"
    )

    for param in "${params[@]}"; do
        local key="${param%%:*}"
        local desc="${param##*:}"
        local value

        if value=$(sysctl -n "$key" 2>/dev/null); then
            if [[ "$value" -gt 0 ]]; then
                log "  OK: $desc is enabled ($key=$value)"
            else
                log "  WARNING: $desc is disabled ($key=$value)"
            fi
        else
            log "  INFO: $key not available"
        fi
    done
}

verify_network_security() {
    log "Verifying network security settings..."

    local params=(
        "net.ipv4.tcp_syncookies:SYN cookies"
        "net.ipv4.conf.all.rp_filter:Reverse path filtering"
        "net.ipv4.conf.all.accept_redirects:ICMP redirects (should be 0)"
        "net.ipv4.icmp_echo_ignore_broadcasts:ICMP broadcast ignore"
    )

    for param in "${params[@]}"; do
        local key="${param%%:*}"
        local desc="${param##*:}"
        local value

        if value=$(sysctl -n "$key" 2>/dev/null); then
            log "  $desc: $key=$value"
        fi
    done
}

check_secure_boot() {
    log "Checking Secure Boot status..."

    if [[ -d /sys/firmware/efi ]]; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            log "  OK: Secure Boot is enabled"
        else
            log "  INFO: Secure Boot is not enabled or not available"
        fi
    else
        log "  INFO: System is not using UEFI"
    fi
}

generate_report() {
    log "=== Kernel Hardening Report ==="
    verify_aslr
    verify_memory_protection
    verify_network_security
    check_secure_boot
    log "=== End of Report ==="
}

main() {
    log "Starting kernel hardening process..."

    case "${1:-apply}" in
        apply)
            check_root
            apply_sysctl
            generate_report
            ;;
        verify)
            generate_report
            ;;
        *)
            echo "Usage: $0 [apply|verify]"
            exit 1
            ;;
    esac

    log "Kernel hardening complete"
}

main "$@"
