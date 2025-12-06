#!/bin/bash
# Security Audit Script
# Comprehensive security configuration audit

set -euo pipefail

LOG_FILE="/var/log/security/security-audit.log"
AUDIT_REPORT="/var/log/security/audit-report-$(date +%Y%m%d).txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

pass() {
    echo -e "[${GREEN}PASS${NC}] $1" | tee -a "$AUDIT_REPORT"
}

fail() {
    echo -e "[${RED}FAIL${NC}] $1" | tee -a "$AUDIT_REPORT"
}

warn() {
    echo -e "[${YELLOW}WARN${NC}] $1" | tee -a "$AUDIT_REPORT"
}

info() {
    echo -e "[INFO] $1" | tee -a "$AUDIT_REPORT"
}

header() {
    echo "" | tee -a "$AUDIT_REPORT"
    echo "=== $1 ===" | tee -a "$AUDIT_REPORT"
    echo "" | tee -a "$AUDIT_REPORT"
}

init_audit() {
    mkdir -p "$(dirname "$AUDIT_REPORT")"
    echo "Security Audit Report" > "$AUDIT_REPORT"
    echo "Generated: $(date)" >> "$AUDIT_REPORT"
    echo "Hostname: $(hostname)" >> "$AUDIT_REPORT"
    echo "Kernel: $(uname -r)" >> "$AUDIT_REPORT"
    echo "========================================" >> "$AUDIT_REPORT"
}

audit_kernel_security() {
    header "Kernel Security Settings"

    # ASLR
    local aslr
    aslr=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "-1")
    if [[ "$aslr" == "2" ]]; then
        pass "ASLR fully enabled (randomize_va_space=2)"
    elif [[ "$aslr" == "1" ]]; then
        warn "ASLR partially enabled (randomize_va_space=1)"
    else
        fail "ASLR disabled (randomize_va_space=$aslr)"
    fi

    # Kernel pointer restriction
    local kptr
    kptr=$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null || echo "0")
    if [[ "$kptr" -ge 2 ]]; then
        pass "Kernel pointers hidden (kptr_restrict=$kptr)"
    elif [[ "$kptr" == "1" ]]; then
        warn "Kernel pointers partially restricted (kptr_restrict=1)"
    else
        fail "Kernel pointers exposed (kptr_restrict=$kptr)"
    fi

    # Dmesg restriction
    local dmesg
    dmesg=$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null || echo "0")
    if [[ "$dmesg" == "1" ]]; then
        pass "Dmesg access restricted"
    else
        fail "Dmesg accessible to non-root users"
    fi

    # Ptrace scope
    local ptrace
    ptrace=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "0")
    if [[ "$ptrace" -ge 2 ]]; then
        pass "Ptrace restricted (scope=$ptrace)"
    elif [[ "$ptrace" == "1" ]]; then
        warn "Ptrace limited to parent processes"
    else
        fail "Ptrace unrestricted"
    fi

    # SysRq
    local sysrq
    sysrq=$(cat /proc/sys/kernel/sysrq 2>/dev/null || echo "1")
    if [[ "$sysrq" == "0" ]]; then
        pass "SysRq disabled"
    else
        warn "SysRq enabled (value=$sysrq)"
    fi

    # Core dumps
    local core_pattern
    core_pattern=$(cat /proc/sys/kernel/core_pattern 2>/dev/null || echo "")
    if [[ -z "$core_pattern" ]] || [[ "$core_pattern" == "|/bin/false" ]]; then
        pass "Core dumps disabled"
    else
        warn "Core dumps enabled"
    fi

    local suid_dumpable
    suid_dumpable=$(cat /proc/sys/fs/suid_dumpable 2>/dev/null || echo "1")
    if [[ "$suid_dumpable" == "0" ]]; then
        pass "SUID core dumps disabled"
    else
        fail "SUID programs can create core dumps"
    fi
}

audit_network_security() {
    header "Network Security Settings"

    # IP forwarding
    local ip_forward
    ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "1")
    if [[ "$ip_forward" == "0" ]]; then
        pass "IPv4 forwarding disabled"
    else
        warn "IPv4 forwarding enabled"
    fi

    # SYN cookies
    local syncookies
    syncookies=$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo "0")
    if [[ "$syncookies" == "1" ]]; then
        pass "SYN cookies enabled"
    else
        fail "SYN cookies disabled"
    fi

    # ICMP redirects
    local icmp_redirects
    icmp_redirects=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || echo "1")
    if [[ "$icmp_redirects" == "0" ]]; then
        pass "ICMP redirects disabled"
    else
        fail "ICMP redirects accepted"
    fi

    # Source routing
    local source_route
    source_route=$(cat /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null || echo "1")
    if [[ "$source_route" == "0" ]]; then
        pass "Source routing disabled"
    else
        fail "Source routing enabled"
    fi

    # Reverse path filtering
    local rp_filter
    rp_filter=$(cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null || echo "0")
    if [[ "$rp_filter" == "1" ]]; then
        pass "Reverse path filtering enabled"
    else
        fail "Reverse path filtering disabled"
    fi

    # Log martians
    local log_martians
    log_martians=$(cat /proc/sys/net/ipv4/conf/all/log_martians 2>/dev/null || echo "0")
    if [[ "$log_martians" == "1" ]]; then
        pass "Martian packets logged"
    else
        warn "Martian packets not logged"
    fi
}

audit_filesystem_security() {
    header "Filesystem Security"

    # Symlink protection
    local symlinks
    symlinks=$(cat /proc/sys/fs/protected_symlinks 2>/dev/null || echo "0")
    if [[ "$symlinks" == "1" ]]; then
        pass "Symlink protection enabled"
    else
        fail "Symlink protection disabled"
    fi

    # Hardlink protection
    local hardlinks
    hardlinks=$(cat /proc/sys/fs/protected_hardlinks 2>/dev/null || echo "0")
    if [[ "$hardlinks" == "1" ]]; then
        pass "Hardlink protection enabled"
    else
        fail "Hardlink protection disabled"
    fi

    # Check /tmp mount options
    if mount | grep -q "on /tmp "; then
        local tmp_opts
        tmp_opts=$(mount | grep "on /tmp " | awk '{print $6}')
        if echo "$tmp_opts" | grep -q "noexec"; then
            pass "/tmp mounted with noexec"
        else
            warn "/tmp not mounted with noexec"
        fi
        if echo "$tmp_opts" | grep -q "nosuid"; then
            pass "/tmp mounted with nosuid"
        else
            warn "/tmp not mounted with nosuid"
        fi
    else
        info "/tmp is not a separate mount point"
    fi

    # World-writable directories with sticky bit
    local ww_dirs
    ww_dirs=$(find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null | wc -l)
    if [[ "$ww_dirs" -eq 0 ]]; then
        pass "All world-writable directories have sticky bit"
    else
        fail "Found $ww_dirs world-writable directories without sticky bit"
    fi
}

audit_authentication() {
    header "Authentication Security"

    # Password hashing
    if grep -q "yescrypt\|SHA512" /etc/login.defs 2>/dev/null; then
        pass "Strong password hashing configured"
    else
        warn "Check password hashing algorithm in /etc/login.defs"
    fi

    # Empty passwords
    local empty_pw
    empty_pw=$(awk -F: '($2 == "" ) { print $1 }' /etc/shadow 2>/dev/null | wc -l)
    if [[ "$empty_pw" -eq 0 ]]; then
        pass "No accounts with empty passwords"
    else
        fail "Found $empty_pw accounts with empty passwords"
    fi

    # UID 0 accounts
    local uid0_count
    uid0_count=$(awk -F: '($3 == "0") { print $1 }' /etc/passwd | wc -l)
    if [[ "$uid0_count" -eq 1 ]]; then
        pass "Only root has UID 0"
    else
        fail "Multiple accounts with UID 0"
    fi

    # SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            pass "SSH root login disabled"
        else
            warn "SSH root login may be enabled"
        fi

        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            pass "SSH password authentication disabled"
        else
            warn "SSH password authentication enabled"
        fi

        if grep -q "^Protocol 2" /etc/ssh/sshd_config || ! grep -q "^Protocol" /etc/ssh/sshd_config; then
            pass "SSH using protocol 2"
        else
            fail "SSH may be using protocol 1"
        fi
    else
        info "SSH server not installed"
    fi
}

audit_services() {
    header "Service Security"

    # Check for unnecessary services
    local unnecessary_services=(
        "telnet.socket"
        "rsh.socket"
        "rlogin.socket"
        "rexec.socket"
        "tftp.socket"
        "xinetd.service"
    )

    for service in "${unnecessary_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            fail "Insecure service running: $service"
        else
            pass "Service not running: $service"
        fi
    done

    # Check essential security services
    if systemctl is-active auditd >/dev/null 2>&1; then
        pass "Auditd is running"
    else
        fail "Auditd is not running"
    fi

    if systemctl is-active apparmor >/dev/null 2>&1 || aa-status >/dev/null 2>&1; then
        pass "AppArmor is active"
    else
        warn "AppArmor is not active"
    fi
}

audit_logging() {
    header "Logging Configuration"

    # Check if rsyslog/syslog is running
    if systemctl is-active rsyslog >/dev/null 2>&1 || systemctl is-active syslog-ng >/dev/null 2>&1; then
        pass "System logging daemon is running"
    else
        warn "No system logging daemon detected"
    fi

    # Check log file permissions
    if [[ -f /var/log/auth.log ]]; then
        local auth_perms
        auth_perms=$(stat -c %a /var/log/auth.log)
        if [[ "$auth_perms" -le 640 ]]; then
            pass "Auth log permissions are restrictive ($auth_perms)"
        else
            warn "Auth log permissions too permissive ($auth_perms)"
        fi
    fi

    # Check for log rotation
    if [[ -f /etc/logrotate.conf ]] && [[ -d /etc/logrotate.d ]]; then
        pass "Log rotation configured"
    else
        warn "Log rotation may not be configured"
    fi
}

generate_summary() {
    header "Audit Summary"

    local pass_count
    pass_count=$(grep -c "\[PASS\]" "$AUDIT_REPORT" || echo "0")

    local fail_count
    fail_count=$(grep -c "\[FAIL\]" "$AUDIT_REPORT" || echo "0")

    local warn_count
    warn_count=$(grep -c "\[WARN\]" "$AUDIT_REPORT" || echo "0")

    echo "Passed: $pass_count" | tee -a "$AUDIT_REPORT"
    echo "Failed: $fail_count" | tee -a "$AUDIT_REPORT"
    echo "Warnings: $warn_count" | tee -a "$AUDIT_REPORT"

    local score
    local total=$((pass_count + fail_count + warn_count))
    if [[ $total -gt 0 ]]; then
        score=$(echo "scale=0; ($pass_count * 100) / $total" | bc)
    else
        score=0
    fi

    echo "" | tee -a "$AUDIT_REPORT"
    echo "Security Score: $score%" | tee -a "$AUDIT_REPORT"
    echo "" | tee -a "$AUDIT_REPORT"
    echo "Report saved to: $AUDIT_REPORT"
}

main() {
    log "=== Starting Security Audit ==="

    init_audit

    audit_kernel_security
    audit_network_security
    audit_filesystem_security
    audit_authentication
    audit_services
    audit_logging

    generate_summary

    log "=== Security Audit Complete ==="
}

main "$@"
