#!/bin/bash
# Memory Protection Configuration Script
# Configures memory encryption and access controls

set -euo pipefail

LOG_FILE="/var/log/security/memory-protection.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

check_cpu_features() {
    log "Checking CPU security features..."

    # Check for NX bit (No-eXecute)
    if grep -q " nx " /proc/cpuinfo 2>/dev/null; then
        log "  OK: NX (No-eXecute) bit is supported"
    else
        log "  WARNING: NX bit not detected"
    fi

    # Check for SMEP (Supervisor Mode Execution Prevention)
    if grep -q " smep " /proc/cpuinfo 2>/dev/null; then
        log "  OK: SMEP is supported"
    else
        log "  INFO: SMEP not available"
    fi

    # Check for SMAP (Supervisor Mode Access Prevention)
    if grep -q " smap " /proc/cpuinfo 2>/dev/null; then
        log "  OK: SMAP is supported"
    else
        log "  INFO: SMAP not available"
    fi

    # Check for AMD SME/SEV
    if grep -q " sme " /proc/cpuinfo 2>/dev/null; then
        log "  OK: AMD SME (Secure Memory Encryption) is supported"
    fi

    if grep -q " sev " /proc/cpuinfo 2>/dev/null; then
        log "  OK: AMD SEV (Secure Encrypted Virtualization) is supported"
    fi

    # Check for Intel TME
    if grep -q " tme " /proc/cpuinfo 2>/dev/null; then
        log "  OK: Intel TME (Total Memory Encryption) is supported"
    fi
}

configure_encrypted_swap() {
    log "Configuring encrypted swap..."

    local swap_file="/etc/crypttab"

    if [[ -f "$swap_file" ]]; then
        if grep -q "swap" "$swap_file"; then
            log "  OK: Encrypted swap already configured"
        else
            log "  INFO: No encrypted swap in crypttab"
        fi
    else
        log "  INFO: /etc/crypttab not found, skipping swap encryption"
    fi
}

check_memory_allocator() {
    log "Checking memory allocator hardening..."

    # Check for hardened malloc
    if [[ -f /etc/ld.so.preload ]]; then
        if grep -q "libhardened_malloc" /etc/ld.so.preload; then
            log "  OK: Hardened malloc is enabled"
        else
            log "  INFO: Standard malloc in use"
        fi
    else
        log "  INFO: No preloaded libraries configured"
    fi
}

configure_memory_limits() {
    log "Configuring memory limits..."

    local limits_conf="/etc/security/limits.d/99-memory.conf"

    if [[ ! -f "$limits_conf" ]]; then
        cat > "$limits_conf" << 'LIMITS'
# Memory security limits
* soft core 0
* hard core 0
* soft memlock 65536
* hard memlock 65536
* soft nofile 65535
* hard nofile 65535
LIMITS
        log "  OK: Memory limits configured in $limits_conf"
    else
        log "  INFO: Memory limits already configured"
    fi
}

check_kaslr() {
    log "Checking Kernel ASLR (KASLR)..."

    if [[ -f /proc/cmdline ]]; then
        if grep -q "nokaslr" /proc/cmdline; then
            log "  WARNING: KASLR is disabled via kernel command line"
        else
            log "  OK: KASLR is enabled"
        fi
    fi
}

check_stack_protection() {
    log "Checking stack protection..."

    # Check kernel stack protector
    if [[ -f /proc/config.gz ]]; then
        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_STACKPROTECTOR=y"; then
            log "  OK: Kernel stack protector is enabled"
        fi
        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_STACKPROTECTOR_STRONG=y"; then
            log "  OK: Strong stack protector is enabled"
        fi
    else
        log "  INFO: Kernel config not available for inspection"
    fi
}

check_amd_sev() {
    log "Checking AMD SEV status..."

    if [[ -d /sys/module/kvm_amd/parameters ]]; then
        if [[ -f /sys/module/kvm_amd/parameters/sev ]]; then
            local sev_enabled
            sev_enabled=$(cat /sys/module/kvm_amd/parameters/sev)
            if [[ "$sev_enabled" == "Y" ]] || [[ "$sev_enabled" == "1" ]]; then
                log "  OK: AMD SEV is enabled"
            else
                log "  INFO: AMD SEV is available but not enabled"
            fi
        fi
    else
        log "  INFO: AMD SEV not available on this system"
    fi
}

generate_report() {
    log "=== Memory Protection Report ==="
    check_cpu_features
    check_kaslr
    check_stack_protection
    check_memory_allocator
    check_amd_sev
    log "=== End of Report ==="
}

main() {
    log "Starting memory protection configuration..."

    case "${1:-check}" in
        configure)
            check_root
            configure_memory_limits
            configure_encrypted_swap
            generate_report
            ;;
        check)
            generate_report
            ;;
        *)
            echo "Usage: $0 [configure|check]"
            exit 1
            ;;
    esac

    log "Memory protection check complete"
}

main "$@"
