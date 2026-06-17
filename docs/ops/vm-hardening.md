# VM Hardening — STORY-001 Runbook

> **Status:** Draft (Issue #15)
> **Owner:** @developer (script + runbook), @atilcan65 (applies on target VM)
> **Story:** [Issue #15 (STORY-001)](https://github.com/atilcan65/AtilCalculator/issues/15)
> **Target VM:** `192.168.1.199` (Ubuntu 24.04 LTS, amd64)
> **Apply on:** the target VM directly, NOT from dev-studio (192.168.1.198).

## Overview

This document is the operator-facing runbook for the STORY-001 VM hardening work. The actual implementation is in [`scripts/ops/apply-vm-hardening.sh`](../../scripts/ops/apply-vm-hardening.sh) — an idempotent shell script that applies AC1-AC5 and verifies AC7 in one shot.

**Pattern**: "developer writes runbook + script in repo; owner applies on target VM; both verify". This preserves the cardinal safety rule (never disable password SSH before verifying key auth works) because the script's preflight rejects the run if key auth is broken.

## Prerequisites (MUST be done BEFORE running the script)

1. **Generate a key on dev-studio** (or any host you'll SSH from):
   ```bash
   ssh-keygen -t ed25519 -C "atilcan@dev-studio-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_atilcalc
   ```
2. **Upload the public key to the target VM** (password auth must still work for this step!):
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519_atilcalc.pub atilcan@192.168.1.199
   ```
3. **Verify key auth works from another host** (DO THIS BEFORE RUNNING THE SCRIPT):
   ```bash
   ssh -i ~/.ssh/id_ed25519_atilcalc -o BatchMode=yes atilcan@192.168.1.199 'echo key-auth works'
   ```
   If this fails (e.g., "Permission denied (publickey)"), the script will refuse to proceed.

## Apply

SSH to the target VM as root (via `sudo` from the key-authenticated user) and run:

```bash
sudo bash /path/to/apply-vm-hardening.sh
```

Optional env vars (defaults match the design decisions documented below):

```bash
sudo \
  SSH_PORT=22 \
  HTTP_PORT=8000 \
  FAIL2BAN_BAN_TIME=600 \
  FAIL2BAN_MAX_RETRY=5 \
  FAIL2BAN_FIND_TIME=60 \
  BACKUP_CRON_EXPR='-*-*-* 02:00:00' \
  bash /path/to/apply-vm-hardening.sh
```

To preview changes without applying:

```bash
sudo bash /path/to/apply-vm-hardening.sh --dry-run
```

## AC1 — SSH password auth disabled

### Applied command (via script)

The script writes `/etc/ssh/sshd_config.d/00-vm-hardening.conf`:
```sshd_config
# STORY-001: VM hardening — disable password + root SSH
PasswordAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Then reloads sshd (NOT restart — preserves existing sessions).

### Before state

```bash
$ sshd -T | grep -E '^(passwordauthentication|permitrootlogin)'
passwordauthentication yes
permitrootlogin prohibit-password
```

### After state

```bash
$ sshd -T | grep -E '^(passwordauthentication|permitrootlogin)'
passwordauthentication no
permitrootlogin no
```

### Verification (manual, AC7)

From a fresh terminal on dev-studio (or any other LAN host):
```bash
# This MUST fail with "Permission denied (publickey)" or "Permission denied (publickey,password)"
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no atilcan@192.168.1.199
```

### Rollback

```bash
sudo rm /etc/ssh/sshd_config.d/00-vm-hardening.conf
sudo sshd -t && sudo systemctl reload ssh
```

## AC2 — SSH key auth verified (precondition + ongoing)

### Applied (preflight + verification)

The script refuses to run unless:
1. `/root/.ssh/authorized_keys` exists and is non-empty.
2. Loopback SSH with key (`ssh -o BatchMode=yes atilcan@localhost`) succeeds.

### Before state

```bash
$ ls -la /root/.ssh/authorized_keys
-rw------- 1 root root 0 Jun 17 21:00 /root/.ssh/authorized_keys
# ^ size 0 = no keys = script will refuse to run
```

### After state (after owner adds a key)

```bash
$ ls -la /root/.ssh/authorized_keys
-rw------- 1 root root 412 Jun 17 21:05 /root/.ssh/authorized_keys
# ^ size > 0 = at least one key = script will proceed
```

### Verification (manual, AC7)

```bash
ssh -i ~/.ssh/id_ed25519_atilcalc atilcan@192.168.1.199 'echo "key auth works at $(date -u +%FT%TZ)"'
```

### Rollback

If the script accidentally disables key auth (shouldn't happen — drop-in only adds `PubkeyAuthentication yes`), remove the drop-in and reload. See AC1 rollback.

## AC3 — ufw firewall active

### Applied commands (via script)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "STORY-001: SSH"
ufw allow 8000/tcp comment "STORY-001: HTTP surface (STORY-003a)"
ufw --force enable
```

(Port `8000` is the FastAPI/uvicorn default; matches STORY-003a's planned deployment.)

### Before state

```bash
$ ufw status
Status: inactive
```

### After state

```bash
$ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere         # SSH
8000/tcp                   ALLOW IN    Anywhere         # HTTP surface (STORY-003a)
```

### Verification (AC7)

From another LAN host:
```bash
nmap -p 1-1024 192.168.1.199
# Only port 22 (or custom SSH port) should show "open"
# Everything else should be "filtered" or "closed"
```

### Rollback

```bash
sudo ufw disable
sudo ufw reset  # removes all rules
```

## AC4 — fail2ban with SSH jail

### Applied (via script)

`/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime = 600
maxretry = 5
findtime = 60

[sshd]
enabled = true
port = 22
backend = systemd
```

(Defaults match AC4: "5 failed SSH attempts within 60 seconds → ban for default duration". Tightened from distro defaults where necessary — see Open Questions §Q2.)

### Before state

```bash
$ systemctl is-active fail2ban
inactive
```

### After state

```bash
$ systemctl is-active fail2ban
active
$ fail2ban-client status sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

### Verification (AC7)

From another LAN host, attempt 6 password SSHs in 60 seconds:
```bash
for i in 1 2 3 4 5 6; do
  sshpass -p 'wrong-password' ssh -o ConnectTimeout=3 atilcan@192.168.1.199 || true
done
```

Then on the VM:
```bash
sudo fail2ban-client status sshd
# Should show the source IP in "Banned IP list"
```

### Rollback

```bash
sudo systemctl stop fail2ban
sudo systemctl disable fail2ban
sudo rm /etc/fail2ban/jail.local
sudo apt-get remove --purge fail2ban
```

## AC5 — State-file backup script + systemd timer

### Applied (via script)

Three files written:
- `/usr/local/bin/backup-agent-state.sh` — the backup script
- `/etc/systemd/system/agent-state-backup.service` — the systemd service
- `/etc/systemd/system/agent-state-backup.timer` — the systemd timer

Backup cadence: daily at 02:00 UTC (matches OPERATIONS.md §6.2).

### Before state

```bash
$ systemctl list-timers | grep agent-state
# (no output — no timer exists)
```

### After state

```bash
$ systemctl list-timers agent-state-backup
NEXT                        LEFT     LAST                        PASSED  UNIT                     ACTIVATES
Wed 2026-06-18 02:00:00 UTC 4h 50min Tue 2026-06-17 21:10:00 UTC 2s ago  agent-state-backup.timer agent-state-backup.service
```

### Verification (AC7)

```bash
# Trigger backup manually
sudo systemctl start agent-state-backup.service
ls -la /var/backups/agent-state/agent-state-*.tar.gz
# ^ should show a new tarball created within seconds
```

### Rollback

```bash
sudo systemctl stop agent-state-backup.timer
sudo systemctl disable agent-state-backup.timer
sudo rm /etc/systemd/system/agent-state-backup.{service,timer}
sudo rm /usr/local/bin/backup-agent-state.sh
sudo systemctl daemon-reload
```

## AC7 — End-to-end verification (master checklist)

After running the script, verify all ACs from a fresh terminal on dev-studio:

```bash
# AC1: password SSH fails
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no atilcan@192.168.1.199
# Expected: Permission denied (publickey) — i.e., server rejected password attempt

# AC2: key SSH works
ssh -i ~/.ssh/id_ed25519_atilcalc atilcan@192.168.1.199 'echo key auth ok'
# Expected: "key auth ok"

# AC3: port scan shows only SSH + HTTP open
nmap -p 22,80,443,8000 192.168.1.199
# Expected: 22/tcp open, 8000/tcp open (when STORY-003a is running), others closed/filtered

# AC4: fail2ban SSH jail active
ssh atilcan@192.168.1.199 'sudo fail2ban-client status sshd | head -20'
# Expected: jail listed as enabled

# AC5: backup timer active
ssh atilcan@192.168.1.199 'systemctl list-timers agent-state-backup --no-pager'
# Expected: NEXT column populated
```

If any check fails, **do not** roll back the entire hardening — diagnose the specific AC and apply targeted rollback (per the per-AC rollback sections above). The full rollback is a last resort.

## Open Questions (pending owner input)

### Q1 — Custom SSH port: keep `22` (default) or move to non-standard?

**Script default**: `SSH_PORT=22` (standard).

**Rationale**: Custom ports reduce noise (port scanners) but add operational overhead (every new client needs to know the port). For a single-user LAN VM, the security gain is marginal; the convenience loss is real. Until the owner answers, the script defaults to `22` and the runbook documents the override:

```bash
sudo SSH_PORT=2222 bash apply-vm-hardening.sh
```

**Owner action**: confirm `22` (default) or specify a port.

### Q2 — fail2ban defaults: keep distro defaults or tighten?

**Script defaults**: `bantime=600` (10 min), `maxretry=5`, `findtime=60` (1 min).

**Rationale**: matches AC4 ("5 failed SSH attempts within 60 seconds"). The `bantime=600` is the distro default (Debian/Ubuntu). Tightening further (e.g., `bantime=3600`) is reasonable but increases the risk of self-lockout via fat-fingered password attempts. The script's defaults match the AC4 spec exactly.

**Developer answer** (to the open question in the issue): keep the defaults documented above. They match AC4 verbatim. No tightening needed for Sprint 1.

## Metrics of success (per issue body)

- **Leading**: this runbook merged to main with all 7 ACs verified on the target VM.
- **Lagging**: no successful brute-force attempt in 30 days post-deployment (verified via `journalctl -u sshd | grep "Failed password"`).

## Files in this delivery

- [`scripts/ops/apply-vm-hardening.sh`](../../scripts/ops/apply-vm-hardening.sh) — the idempotent apply script (496 lines).
- [`scripts/tests/test-vm-hardening.sh`](../../scripts/tests/test-vm-hardening.sh) — shell tests for script behavior (syntax, env override, dry-run).
- This document — the operator-facing runbook.