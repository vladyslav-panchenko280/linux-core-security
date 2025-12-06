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

## Web Interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / changeme |
| Prometheus | http://localhost:9090 | - |
| Trivy Server | http://localhost:8080 | - |

## Working with Containers

Access the secure Linux container:
```bash
docker exec -it secure-linux bash
```

Run security audit inside container:
```bash
docker exec secure-linux sudo /opt/security/scripts/security-audit.sh
```

Check kernel hardening status:
```bash
docker exec secure-linux sudo /opt/security/scripts/kernel-hardening.sh verify
```

View container logs:
```bash
docker-compose logs -f secure-linux
```

## Scanning Images with Trivy

Check Trivy server status:
```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/version
```

Scan a Docker image using Trivy CLI with server:
```bash
docker run --rm --network linux-core-security_security-net \
  aquasec/trivy image --server http://trivy:8080 ubuntu:24.04
```

Scan the secure-linux image:
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image linux-core-security-secure-linux:latest
```

Quick standalone scan:
```bash
docker run --rm aquasec/trivy image alpine:latest
```

## Monitoring and Alerts

View Prometheus metrics:
```bash
# Check targets status
curl http://localhost:9090/api/v1/targets

# Query specific metric
curl 'http://localhost:9090/api/v1/query?query=up'
```

Grafana dashboards:
1. Open http://localhost:3000
2. Login with admin/changeme
3. Import dashboards from monitoring/grafana-dashboards/

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
