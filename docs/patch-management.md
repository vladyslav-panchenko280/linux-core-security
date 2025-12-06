# Patch Management Guide

This document describes the automated patching system and procedures.

## Overview

The patch management system automatically applies security updates while maintaining system stability through pre-flight checks and rollback capabilities.

## Components

### 1. Automated Patching Script

Location: scripts/auto-patch.sh

Features:
- Automatic security update installation
- Pre-patch system snapshots
- Disk space validation
- Network connectivity checks
- Post-patch service verification
- Email notifications

### 2. Compatibility Checker

Location: scripts/compatibility-check.sh

Performs validation before updates:
- Kernel compatibility analysis
- Dependency conflict detection
- Configuration file change detection
- Service impact assessment
- Upgrade simulation

### 3. Snapshot System

Location: scripts/pre-update-snapshot.sh

Creates restore points:
- Package state capture
- Configuration backup
- Service state recording
- Kernel information logging

## Configuration

### Unattended Upgrades

File: configs/unattended-upgrades/50unattended-upgrades

Key settings:

    Allowed-Origins: Security updates only
    Automatic-Reboot: Disabled by default
    Mail: root (for notifications)
    Remove-Unused-Dependencies: Enabled

### Systemd Timer

Files:
- systemd/auto-patch.service
- systemd/auto-patch.timer

Schedule: Daily at 03:00 UTC with 30-minute random delay

Installation:

    sudo cp systemd/auto-patch.* /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable auto-patch.timer
    sudo systemctl start auto-patch.timer

## Manual Operations

### Check for Updates

    sudo apt-get update
    apt list --upgradable

### Run Compatibility Check

    sudo /opt/security/scripts/compatibility-check.sh

### Apply Updates Manually

    sudo /opt/security/scripts/auto-patch.sh

### Create Snapshot

    sudo /opt/security/scripts/pre-update-snapshot.sh create

### List Snapshots

    sudo /opt/security/scripts/pre-update-snapshot.sh list

### Restore from Snapshot

    sudo /opt/security/scripts/pre-update-snapshot.sh restore /path/to/snapshot.tar.gz

## Exclusions

Packages requiring manual approval are listed in:
configs/unattended-upgrades/50unattended-upgrades

Default exclusions:
- Kernel packages (linux-image-*)
- Container runtime (docker-ce, containerd)

To add exclusions, edit the Package-Blacklist section:

    Unattended-Upgrade::Package-Blacklist {
        "package-name";
    };

## Monitoring

### Check Timer Status

    systemctl status auto-patch.timer
    systemctl list-timers auto-patch.timer

### View Logs

    journalctl -u auto-patch.service
    cat /var/log/security/auto-patch.log

### Check Compatibility Report

    cat /var/log/security/compatibility-report.json

## Troubleshooting

### Update Failure

1. Check logs: journalctl -u auto-patch.service
2. Run compatibility check: /opt/security/scripts/compatibility-check.sh
3. Check disk space: df -h
4. Verify network: ping archive.ubuntu.com

### Rollback Required

1. Stop services if needed
2. List available snapshots
3. Restore from snapshot
4. Restart services
5. Document incident

### Lock File Issues

If auto-patch reports another instance running:

    rm /var/run/auto-patch.lock

Only do this if you confirm no other instance is running:

    ps aux | grep auto-patch

## Best Practices

1. Test updates in staging environment first
2. Review compatibility reports before production deployment
3. Maintain recent snapshots
4. Monitor logs regularly
5. Document any manual interventions
6. Keep exclusion list minimal and reviewed
