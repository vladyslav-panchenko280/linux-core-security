#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/security/compatibility-check.log"
REPORT_FILE="/var/log/security/compatibility-report.json"

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
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "checks": [],
  "status": "pending"
}
EOF
}

add_check_result() {
    local name=$1
    local status=$2
    local message=$3

    local temp_file
    temp_file=$(mktemp)

    jq --arg name "$name" \
       --arg status "$status" \
       --arg message "$message" \
       '.checks += [{"name": $name, "status": $status, "message": $message}]' \
       "$REPORT_FILE" > "$temp_file" && mv "$temp_file" "$REPORT_FILE"
}

check_kernel_compatibility() {
    log "Checking kernel compatibility..."

    local current_kernel
    current_kernel=$(uname -r)

    local pending_kernels
    pending_kernels=$(apt-get -s upgrade 2>/dev/null | grep -c "linux-image" || echo "0")

    if [[ $pending_kernels -gt 0 ]]; then
        log "  WARNING: Kernel update pending - reboot will be required"
        add_check_result "kernel" "warning" "Kernel update pending, reboot required"
        return 1
    fi

    log "  OK: No kernel updates pending"
    add_check_result "kernel" "ok" "Current kernel: $current_kernel"
    return 0
}

check_dependency_conflicts() {
    log "Checking for dependency conflicts..."

    local conflicts
    conflicts=$(apt-get -s upgrade 2>&1 | grep -c "conflict" || echo "0")

    if [[ $conflicts -gt 0 ]]; then
        log "  ERROR: Dependency conflicts detected"
        apt-get -s upgrade 2>&1 | grep -i "conflict" | while read -r line; do
            log "    $line"
        done
        add_check_result "dependencies" "error" "Dependency conflicts found"
        return 1
    fi

    log "  OK: No dependency conflicts"
    add_check_result "dependencies" "ok" "No conflicts detected"
    return 0
}

check_config_changes() {
    log "Checking for configuration file changes..."

    local config_changes=0

    # Check for packages that might replace config files
    apt-get -s upgrade 2>/dev/null | grep "Conf" | while read -r line; do
        log "  INFO: Config change - $line"
        config_changes=$((config_changes + 1))
    done

    if [[ $config_changes -gt 0 ]]; then
        add_check_result "config" "warning" "$config_changes config changes detected"
    else
        add_check_result "config" "ok" "No config changes expected"
    fi
}

check_held_packages() {
    log "Checking for held packages..."

    local held
    held=$(dpkg --get-selections | grep "hold" | wc -l)

    if [[ $held -gt 0 ]]; then
        log "  INFO: $held package(s) are held back"
        dpkg --get-selections | grep "hold" | while read -r pkg status; do
            log "    Held: $pkg"
        done
        add_check_result "held_packages" "info" "$held packages held back"
    else
        add_check_result "held_packages" "ok" "No packages held"
    fi
}

check_disk_space() {
    log "Checking disk space requirements..."

    local download_size
    download_size=$(apt-get -s upgrade 2>/dev/null | grep "Need to get" | awk '{print $4}' || echo "0")

    local install_size
    install_size=$(apt-get -s upgrade 2>/dev/null | grep "After this operation" | awk '{print $4}' || echo "0")

    local available
    available=$(df -h /var | awk 'NR==2 {print $4}')

    log "  Download size: ${download_size:-0}"
    log "  Install size: ${install_size:-0}"
    log "  Available: $available"

    add_check_result "disk_space" "ok" "Available: $available, Required: ${download_size:-0}"
}

check_running_services() {
    log "Checking affected services..."

    local services_affected=()

    # Check for common service packages in updates
    local update_list
    update_list=$(apt-get -s upgrade 2>/dev/null | grep "^Inst" | awk '{print $2}')

    for pkg in $update_list; do
        case $pkg in
            nginx*|apache*|httpd*)
                services_affected+=("web-server")
                ;;
            mysql*|mariadb*|postgresql*)
                services_affected+=("database")
                ;;
            docker*|containerd*)
                services_affected+=("container-runtime")
                ;;
            systemd*)
                services_affected+=("init-system")
                ;;
            ssh*|openssh*)
                services_affected+=("ssh")
                ;;
        esac
    done

    if [[ ${#services_affected[@]} -gt 0 ]]; then
        log "  WARNING: Critical services may be affected: ${services_affected[*]}"
        add_check_result "services" "warning" "Affected: ${services_affected[*]}"
    else
        log "  OK: No critical services affected"
        add_check_result "services" "ok" "No critical services affected"
    fi
}

check_security_updates() {
    log "Checking security update classification..."

    local security_count
    security_count=$(apt-get -s upgrade 2>/dev/null | grep -c "security" || echo "0")

    local total_count
    total_count=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo "0")

    log "  Security updates: $security_count"
    log "  Total updates: $total_count"

    add_check_result "security_classification" "ok" "Security: $security_count, Total: $total_count"
}

simulate_upgrade() {
    log "Simulating upgrade..."

    local simulation_output
    simulation_output=$(apt-get -s upgrade 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log "  ERROR: Simulation failed"
        add_check_result "simulation" "error" "Upgrade simulation failed"
        return 1
    fi

    log "  OK: Simulation successful"
    add_check_result "simulation" "ok" "Upgrade simulation passed"
    return 0
}

finalize_report() {
    local overall_status="ok"

    # Check if any errors in report
    if jq -e '.checks[] | select(.status == "error")' "$REPORT_FILE" >/dev/null 2>&1; then
        overall_status="error"
    elif jq -e '.checks[] | select(.status == "warning")' "$REPORT_FILE" >/dev/null 2>&1; then
        overall_status="warning"
    fi

    local temp_file
    temp_file=$(mktemp)
    jq --arg status "$overall_status" '.status = $status' "$REPORT_FILE" > "$temp_file"
    mv "$temp_file" "$REPORT_FILE"

    log "=== Compatibility Check Complete ==="
    log "Overall Status: $overall_status"
    log "Report saved to: $REPORT_FILE"

    if [[ "$overall_status" == "error" ]]; then
        return 1
    fi
    return 0
}

main() {
    log "=== Starting Compatibility Check ==="

    check_root
    init_report

    apt-get update -qq

    local has_errors=0

    check_kernel_compatibility || has_errors=1
    check_dependency_conflicts || has_errors=1
    check_config_changes
    check_held_packages
    check_disk_space
    check_running_services
    check_security_updates
    simulate_upgrade || has_errors=1

    finalize_report

    exit $has_errors
}

main "$@"
