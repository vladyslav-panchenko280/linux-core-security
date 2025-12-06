# Incident Response Plan

This document outlines procedures for responding to security incidents.

## Incident Classification

### Priority 1 - Critical

Indicators:
- Active system compromise
- Data breach confirmed
- Ransomware or malware infection
- Unauthorized root access
- Critical service disruption

Response time: Immediate (within 15 minutes)

### Priority 2 - High

Indicators:
- Attempted exploitation detected
- Suspicious privileged activity
- Multiple failed authentication attempts
- Unusual network traffic patterns
- Security control bypass attempt

Response time: Within 4 hours

### Priority 3 - Medium

Indicators:
- Vulnerability discovered
- Configuration drift detected
- Minor policy violation
- Anomalous but non-critical activity

Response time: Within 24 hours

### Priority 4 - Low

Indicators:
- Minor security findings
- Documentation gaps
- Low-risk misconfigurations

Response time: Within 72 hours

## Response Phases

### Phase 1: Detection and Triage

1. Identify the incident
   - Review alerts and logs
   - Determine affected systems
   - Assess initial scope

2. Classify severity
   - Use priority matrix above
   - Consider data sensitivity
   - Evaluate business impact

3. Notify stakeholders
   - Alert security team
   - Escalate if needed
   - Document initial findings

### Phase 2: Containment

Short-term containment:

1. Isolate affected systems
   - Disable network access if needed
   - Block malicious IPs
   - Disable compromised accounts

2. Preserve evidence
   - Take memory dumps
   - Capture disk images
   - Save log files

3. Implement temporary controls
   - Enable additional logging
   - Increase monitoring
   - Apply emergency rules

Long-term containment:

1. Identify all affected systems
2. Apply patches if available
3. Reset credentials
4. Update security controls

### Phase 3: Eradication

1. Remove malware/backdoors
   - Scan all systems
   - Remove malicious files
   - Clean registry/config entries

2. Close attack vectors
   - Patch vulnerabilities
   - Update firewall rules
   - Strengthen authentication

3. Verify removal
   - Run integrity checks
   - Scan for indicators of compromise
   - Validate system state

### Phase 4: Recovery

1. Restore from clean backups
   - Verify backup integrity
   - Restore affected systems
   - Test functionality

2. Validate security
   - Run security scans
   - Verify controls active
   - Check monitoring

3. Resume operations
   - Enable services gradually
   - Monitor closely
   - Document recovery

### Phase 5: Post-Incident

1. Root cause analysis
   - How did incident occur
   - What was the timeline
   - What controls failed

2. Documentation
   - Complete incident report
   - Update runbooks
   - Record lessons learned

3. Improvements
   - Update security controls
   - Enhance monitoring
   - Train team

## Incident Response Commands

### Immediate Isolation

    # Block all incoming connections except SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -j DROP

    # Disable network interface
    ip link set eth0 down

### Evidence Collection

    # Memory dump
    dd if=/dev/mem of=/mnt/evidence/memory.dump bs=1M

    # Disk image
    dd if=/dev/sda of=/mnt/evidence/disk.img bs=4M

    # Running processes
    ps auxwww > /mnt/evidence/processes.txt

    # Network connections
    ss -tulpn > /mnt/evidence/network.txt
    netstat -an > /mnt/evidence/netstat.txt

    # Open files
    lsof > /mnt/evidence/lsof.txt

    # Loaded modules
    lsmod > /mnt/evidence/modules.txt

    # System logs
    cp -r /var/log /mnt/evidence/logs/

### User Investigation

    # Recent logins
    last -100

    # Failed logins
    lastb -100

    # Current users
    w

    # User processes
    ps -u <username>

    # User files modified recently
    find /home/<user> -mtime -1 -type f

### Malware Scanning

    # Run rkhunter
    rkhunter --check --skip-keypress

    # Run chkrootkit
    chkrootkit

    # Check for hidden files
    find / -name ".*" -type f 2>/dev/null

    # Check for unusual SUID files
    find / -type f -perm -4000 2>/dev/null

### Network Investigation

    # Active connections
    ss -tupn

    # Listening services
    ss -tulpn

    # Recent DNS queries (if logging enabled)
    grep -r "query" /var/log/dns/

    # Firewall logs
    grep -i "blocked" /var/log/ufw.log

## Communication Templates

### Initial Notification

    Subject: [SECURITY INCIDENT] Priority X - Brief Description

    Incident ID: INC-YYYYMMDD-XXX
    Priority: X
    Status: Investigating

    Summary:
    [Brief description of incident]

    Affected Systems:
    [List systems]

    Current Actions:
    [What is being done]

    Next Update: [Time]

### Status Update

    Subject: [UPDATE] INC-YYYYMMDD-XXX - Status Update

    Incident ID: INC-YYYYMMDD-XXX
    Status: [Investigating/Contained/Resolved]

    Progress:
    [What has been done]

    Findings:
    [What was discovered]

    Next Steps:
    [Planned actions]

    Next Update: [Time]

### Closure Report

    Subject: [CLOSED] INC-YYYYMMDD-XXX - Incident Resolved

    Incident ID: INC-YYYYMMDD-XXX
    Status: Resolved
    Duration: [Start to end time]

    Summary:
    [What happened]

    Root Cause:
    [Why it happened]

    Resolution:
    [How it was fixed]

    Lessons Learned:
    [What we learned]

    Follow-up Actions:
    [Improvements to implement]

## Contacts

Security Team:
- Email: security@example.com
- On-call: [Phone number]

Escalation Path:
1. Security Analyst
2. Security Lead
3. CISO
4. Executive Team

External Resources:
- Law enforcement (if required)
- Forensics vendor
- Legal counsel
- PR/Communications

## Regular Testing

Schedule regular incident response drills:
- Tabletop exercises: Quarterly
- Technical simulations: Semi-annually
- Full drills: Annually

Document results and update procedures accordingly.
