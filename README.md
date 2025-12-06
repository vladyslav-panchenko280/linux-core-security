# Linux Core Security

Production-ready Linux hardening with Docker, automated patching, and continuous monitoring.

## Features

- Kernel hardening (ASLR, exploit protection, memory access control)
- AppArmor mandatory access control
- Automated security patching with rollback support
- File integrity monitoring (AIDE)
- Comprehensive audit logging
- Prometheus/Grafana monitoring stack
- Container vulnerability scanning (Trivy)

## Quick Start

```bash
# Clone and start
git clone https://github.com/your-org/linux-core-security.git
cd linux-core-security
docker-compose up -d
```

## Structure

```
configs/          # Security configurations (sysctl, apparmor, auditd, aide)
scripts/          # Automation scripts (patching, scanning, auditing)
systemd/          # Service and timer units
monitoring/       # Prometheus and Grafana configs
docs/             # Documentation
```

## Core Components

| Component | Purpose |
|-----------|---------|
| sysctl.d/99-security.conf | Kernel hardening parameters |
| apparmor.d/ | Mandatory access control profiles |
| auditd/audit.rules | System call auditing |
| auto-patch.sh | Automated security updates |
| security-scan.sh | Vulnerability scanning |

## Usage

```bash
# Run security scan
sudo ./scripts/security-scan.sh

# Run security audit
sudo ./scripts/security-audit.sh

# Check update compatibility
sudo ./scripts/compatibility-check.sh

# Apply kernel hardening
sudo ./scripts/kernel-hardening.sh
```

## Systemd Timers

| Timer | Schedule | Purpose |
|-------|----------|---------|
| auto-patch.timer | Daily 03:00 | Security updates |
| security-scan.timer | Daily 02:00 | Vulnerability scan |
| integrity-check.timer | Daily 04:00 | File integrity check |

## Documentation

- [SECURITY.md](SECURITY.md) - Security policies
- [docs/patch-management.md](docs/patch-management.md) - Patching procedures
- [docs/compliance-checklist.md](docs/compliance-checklist.md) - Security checklist
- [docs/incident-response.md](docs/incident-response.md) - Incident response plan

## Requirements

- Docker 24.x+
- Docker Compose 2.x+
- Ubuntu 24.04 LTS or Debian 12 (for host)

## License

MIT
