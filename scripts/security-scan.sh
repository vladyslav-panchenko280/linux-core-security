#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/security/security-scan.log"
REPORT_DIR="/var/log/security/reports"
REPORT_DATE=$(date +%Y%m%d-%H%M%S)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

init_report() {
    mkdir -p "$REPORT_DIR"
    local report_file="${REPORT_DIR}/scan-${REPORT_DATE}.json"
    echo "{\"timestamp\": \"$(date -Iseconds)\", \"hostname\": \"$(hostname)\", \"scans\": []}" > "$report_file"
    echo "$report_file"
}

add_scan_result() {
    local report_file=$1
    local scan_name=$2
    local status=$3
    local findings=$4

    local temp_file
    temp_file=$(mktemp)

    jq --arg name "$scan_name" \
       --arg status "$status" \
       --arg findings "$findings" \
       '.scans += [{"name": $name, "status": $status, "findings": $findings}]' \
       "$report_file" > "$temp_file" && mv "$temp_file" "$report_file"
}

run_lynis_scan() {
    local report_file=$1
    log "Running Lynis security audit..."

    if command -v lynis >/dev/null 2>&1; then
        local lynis_report="${REPORT_DIR}/lynis-${REPORT_DATE}.log"
        lynis audit system --quiet --no-colors > "$lynis_report" 2>&1 || true

        local hardening_index
        hardening_index=$(grep "Hardening index" "$lynis_report" | awk '{print $NF}' || echo "N/A")

        local warnings
        warnings=$(grep -c "Warning:" "$lynis_report" || echo "0")

        local suggestions
        suggestions=$(grep -c "Suggestion:" "$lynis_report" || echo "0")

        log "  Hardening Index: $hardening_index"
        log "  Warnings: $warnings"
        log "  Suggestions: $suggestions"

        add_scan_result "$report_file" "lynis" "completed" "Hardening: $hardening_index, Warnings: $warnings, Suggestions: $suggestions"
    else
        log "  WARNING: Lynis not installed"
        add_scan_result "$report_file" "lynis" "skipped" "Not installed"
    fi
}

run_rkhunter_scan() {
    local report_file=$1
    log "Running rootkit scan..."

    if command -v rkhunter >/dev/null 2>&1; then
        local rkhunter_report="${REPORT_DIR}/rkhunter-${REPORT_DATE}.log"

        rkhunter --update --quiet 2>/dev/null || true
        rkhunter --check --skip-keypress --quiet --logfile "$rkhunter_report" 2>/dev/null || true

        local warnings
        warnings=$(grep -c "Warning:" "$rkhunter_report" 2>/dev/null || echo "0")

        local infected
        infected=$(grep -c "Rootkit" "$rkhunter_report" 2>/dev/null | grep -v "not found" || echo "0")

        log "  Warnings: $warnings"
        add_scan_result "$report_file" "rkhunter" "completed" "Warnings: $warnings"
    else
        log "  WARNING: RKHunter not installed"
        add_scan_result "$report_file" "rkhunter" "skipped" "Not installed"
    fi
}

run_aide_check() {
    local report_file=$1
    log "Running file integrity check..."

    if command -v aide >/dev/null 2>&1; then
        local aide_report="${REPORT_DIR}/aide-${REPORT_DATE}.log"

        if [[ -f /var/lib/aide/aide.db ]]; then
            aide --check > "$aide_report" 2>&1 || true

            local added
            added=$(grep -c "Added entries:" "$aide_report" 2>/dev/null || echo "0")

            local removed
            removed=$(grep -c "Removed entries:" "$aide_report" 2>/dev/null || echo "0")

            local changed
            changed=$(grep -c "Changed entries:" "$aide_report" 2>/dev/null || echo "0")

            log "  Added: $added, Removed: $removed, Changed: $changed"
            add_scan_result "$report_file" "aide" "completed" "Added: $added, Removed: $removed, Changed: $changed"
        else
            log "  WARNING: AIDE database not initialized"
            add_scan_result "$report_file" "aide" "warning" "Database not initialized"
        fi
    else
        log "  WARNING: AIDE not installed"
        add_scan_result "$report_file" "aide" "skipped" "Not installed"
    fi
}

check_open_ports() {
    local report_file=$1
    log "Checking open ports..."

    local ports
    ports=$(ss -tulpn 2>/dev/null | grep LISTEN | wc -l)

    local port_list
    port_list=$(ss -tulpn 2>/dev/null | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u | tr '\n' ',' | sed 's/,$//')

    log "  Open ports: $ports"
    log "  Ports: $port_list"

    add_scan_result "$report_file" "open_ports" "completed" "Count: $ports, Ports: $port_list"
}

check_failed_logins() {
    local report_file=$1
    log "Checking failed login attempts..."

    local failed_count=0
    if [[ -f /var/log/auth.log ]]; then
        failed_count=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
    elif [[ -f /var/log/secure ]]; then
        failed_count=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo "0")
    fi

    log "  Failed login attempts: $failed_count"

    local status="ok"
    if [[ $failed_count -gt 100 ]]; then
        status="warning"
    fi

    add_scan_result "$report_file" "failed_logins" "$status" "Count: $failed_count"
}

check_running_processes() {
    local report_file=$1
    log "Checking running processes..."

    local process_count
    process_count=$(ps aux | wc -l)

    local root_processes
    root_processes=$(ps aux | grep -c "^root" || echo "0")

    log "  Total processes: $process_count"
    log "  Root processes: $root_processes"

    add_scan_result "$report_file" "processes" "completed" "Total: $process_count, Root: $root_processes"
}

check_suid_files() {
    local report_file=$1
    log "Checking SUID/SGID files..."

    local suid_count
    suid_count=$(find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)

    log "  SUID/SGID files: $suid_count"

    # Save list to file
    find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null > "${REPORT_DIR}/suid-files-${REPORT_DATE}.txt"

    add_scan_result "$report_file" "suid_files" "completed" "Count: $suid_count"
}

check_world_writable() {
    local report_file=$1
    log "Checking world-writable files..."

    local ww_count
    ww_count=$(find / -xdev -type f -perm -0002 2>/dev/null | wc -l)

    log "  World-writable files: $ww_count"

    local status="ok"
    if [[ $ww_count -gt 0 ]]; then
        status="warning"
        find / -xdev -type f -perm -0002 2>/dev/null > "${REPORT_DIR}/world-writable-${REPORT_DATE}.txt"
    fi

    add_scan_result "$report_file" "world_writable" "$status" "Count: $ww_count"
}

check_security_updates() {
    local report_file=$1
    log "Checking for security updates..."

    apt-get update -qq 2>/dev/null || true

    local security_updates
    security_updates=$(apt-get -s upgrade 2>/dev/null | grep -c "security" || echo "0")

    log "  Pending security updates: $security_updates"

    local status="ok"
    if [[ $security_updates -gt 0 ]]; then
        status="warning"
    fi

    add_scan_result "$report_file" "security_updates" "$status" "Pending: $security_updates"
}

check_kernel_hardening() {
    local report_file=$1
    log "Checking kernel hardening..."

    local issues=0
    local checks=""

    # Check ASLR
    local aslr
    aslr=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "0")
    if [[ "$aslr" != "2" ]]; then
        issues=$((issues + 1))
        checks="$checks ASLR:$aslr"
    fi

    # Check ptrace scope
    local ptrace
    ptrace=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "0")
    if [[ "$ptrace" -lt 1 ]]; then
        issues=$((issues + 1))
        checks="$checks Ptrace:$ptrace"
    fi

    # Check kptr_restrict
    local kptr
    kptr=$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null || echo "0")
    if [[ "$kptr" -lt 1 ]]; then
        issues=$((issues + 1))
        checks="$checks Kptr:$kptr"
    fi

    log "  Kernel hardening issues: $issues"

    local status="ok"
    if [[ $issues -gt 0 ]]; then
        status="warning"
    fi

    add_scan_result "$report_file" "kernel_hardening" "$status" "Issues: $issues $checks"
}

generate_summary() {
    local report_file=$1
    log "Generating summary..."

    local warnings
    warnings=$(jq '[.scans[] | select(.status == "warning")] | length' "$report_file")

    local errors
    errors=$(jq '[.scans[] | select(.status == "error")] | length' "$report_file")

    local overall_status="ok"
    if [[ $errors -gt 0 ]]; then
        overall_status="error"
    elif [[ $warnings -gt 0 ]]; then
        overall_status="warning"
    fi

    local temp_file
    temp_file=$(mktemp)
    jq --arg status "$overall_status" \
       --arg warnings "$warnings" \
       --arg errors "$errors" \
       '. + {"summary": {"status": $status, "warnings": $warnings, "errors": $errors}}' \
       "$report_file" > "$temp_file" && mv "$temp_file" "$report_file"

    log "=== Security Scan Complete ==="
    log "Status: $overall_status"
    log "Warnings: $warnings"
    log "Errors: $errors"
    log "Report: $report_file"
}

main() {
    log "=== Starting Security Scan ==="

    check_root

    local report_file
    report_file=$(init_report)

    run_lynis_scan "$report_file"
    run_rkhunter_scan "$report_file"
    run_aide_check "$report_file"
    check_open_ports "$report_file"
    check_failed_logins "$report_file"
    check_running_processes "$report_file"
    check_suid_files "$report_file"
    check_world_writable "$report_file"
    check_security_updates "$report_file"
    check_kernel_hardening "$report_file"

    generate_summary "$report_file"
}

main "$@"
