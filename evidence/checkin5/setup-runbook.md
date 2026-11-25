# Project D — Deployment and Restore Runbook

**Check-in 5 evidence package — status as of 25 November 2026**

Purpose: deploy Project D on a new server, restore data and configuration from restic/B2, measure the restore time, and retain reproducible evidence.

> Never add secrets to Git, screenshots, logs, or chat. Mark a task complete only when its observed result and evidence are available.

## Current standalone status

The baseline deployment was commit `b0414de7ea38f8ab7dea5da778ff7f7e03b45188`. Following the 24 November audit, the live server was fast-forwarded to `cacdbcb`; Grafana 12.1.10 is healthy and Mosquitto 2.0.23, Telegraf and all six simulators reconnected successfully. Earlier local fixes were replaced without `git clean`, volume deletion, or disclosure of existing secrets.

Verified on the standalone server:

- repeated `deployment/standalone/deploy.sh --endpoint <standalone-server>`: `DEPLOY_STATUS=0`, 47 seconds; this was a **redeployment, not a from-scratch installation measurement**;
- fresh data from 6/6 sensors; Grafana and Team Dashboard healthy; MQTT over TLS working;
- only SSH `22/tcp` and WireGuard `51820/udp` listen publicly; project services bind to `10.66.0.1` or loopback;
- 56/56 Ubuntu unit tests passed, together with Python compilation, shell syntax checks, and `docker compose config -q`;
- baseline isolated network-namespace firewall test: 28/28 passed;
- updated per-peer firewall policy including qwerty `.12`: **31/31 passed on 25 November**, using only temporary network namespaces; the revised rules were **not enabled** on the live host;
- Alert 2 for all three Szczecin sensors and recovery of all six alert instances to `Normal` passed; see section 8;
- `delay_ms` analysis completed for 444 normal-operation samples and a separate recovery window; see section 9.

The running standalone stack uses **new secrets and WireGuard keys** and an independent peer registry at `/root/projectd-profiles/peers.md`. A real production B2 snapshot was restored **to separate files only** on 25 November; no restored production configuration or service was activated. Do not use the production QR profiles as profiles for this server.

## 1. Prerequisites

- a new Ubuntu/Debian server with working root SSH access;
- a second terminal session to confirm that the firewall does not lock out SSH;
- Jeslito's root access to Contabo, where `/etc/projectd/backup.env` is stored;
- access to the B2 bucket and the restic password;
- the new server address and a working SSH key;
- the project repository, including the deployment and backup READMEs.

## 2. Copy setup scripts to the new server

From the prepared setup directory in Git Bash:

```bash
NEW_SERVER='root@NEW_SERVER_ADDRESS'
ssh "$NEW_SERVER" 'mkdir -p /root/projectd-setup && chmod 700 /root/projectd-setup'
scp server/*.sh "$NEW_SERVER:/root/projectd-setup/"
ssh "$NEW_SERVER" 'chmod 700 /root/projectd-setup/*.sh'
```

After copying scripts from Windows, normalize line endings to LF:

```bash
ssh "$NEW_SERVER" 'sed -i "s/\r$//" /root/projectd-setup/*.sh'
```

## 3. Firewall and updates

```bash
ssh "$NEW_SERVER"
cd /root/projectd-setup
bash ./01-firewall-updates.sh
```

The script:

- detects the effective SSH port (`SSH_PORT=2222` can override it);
- allows SSH and WireGuard UDP/51820 before enabling UFW;
- sets incoming traffic to deny and outgoing traffic to allow by default;
- installs automatic security updates and runs `full-upgrade`;
- writes a log under `/root/projectd-evidence/`;
- does not reboot automatically.

**Before closing the first session, open a second one and verify `ssh "$NEW_SERVER"`.** If the system reports `REBOOT_REQUIRED=yes`, schedule a reboot and verify SSH and UFW again afterwards.

Published Docker container ports can bypass UFW. After starting services, inspect `docker ps`, `ss -lntup`, and actual external reachability. The repository test `tests/security/firewall-netns-test.sh` requires `socat` and `iproute2`.

## 4. Install Docker and WireGuard

```bash
cd /root/projectd-setup
bash ./02-docker-wireguard-install.sh
```

The script installs Docker from the official repository, Docker Compose, WireGuard, restic, and qrencode. It enables IPv4 forwarding. If `/etc/wireguard/wg0.conf` exists, it starts `wg-quick@wg0`.

If that configuration is absent, the script **does not generate new keys** during restoration. Restore the previous `/etc/wireguard` first to preserve existing QR profiles. Generating new keys requires reissuing profiles to faculty and clients.

For the standalone deployment with new keys, run:

```bash
cd /opt/coil-projectD
bash deployment/standalone/deploy.sh --endpoint <standalone-server>
```

After a server reboot, Docker should start after `wg-quick@wg0` through `deployment/contabo/docker-after-wireguard.conf`. A complete reboot → Docker → WireGuard → application test has not yet been performed.

## 5. Transfer restic/B2 credentials securely from Contabo

The source files are `/etc/projectd/backup.env` and the credentials file named by its `BACKUP_ENV` setting **on Contabo**. In the delivered configuration that target is `/etc/projectd/restic.env`. Jeslito has root access there. Do not substitute addresses found in `known_hosts` or terminal history for Contabo. `bilewski.am.szczecin.pl:40071` is not a Project D server.

**Status on 25 November:** both files are present, root-owned and mode `600`. Variable-name inspection confirmed that `restic.env` contains `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID` and `B2_ACCOUNT_KEY`. No values were printed or copied into evidence.

For a future transfer, Jeslito can use his standalone SSH account and copy the credentials to `/home/jeslito/restic.env` without posting them anywhere. A root administrator then installs and removes the temporary copy:

```bash
install -o root -g root -m 600 /home/jeslito/restic.env /etc/projectd/restic.env
rm -f /home/jeslito/restic.env
```

Check only presence, permissions and variable **names**, never values:

```bash
stat -c '%a %U:%G %n' /etc/projectd/backup.env /etc/projectd/restic.env
grep -oE '^[A-Z_0-9]+=' /etc/projectd/restic.env
```

Expected mode for both files is `600`. The credentials must include a Restic repository, a password through an appropriate Restic variable, and the B2 account credentials required by the repository type.

## 6. Restore from B2 with timing — file-only PASS; functional test open

```bash
ssh "$NEW_SERVER"
cd /root/projectd-setup
bash ./03-restore-b2.sh /etc/projectd/restic.env
```

By default, the script restores snapshot `latest` into the empty directory `/srv/projectd-restore`. To select another snapshot or target:

```bash
RESTIC_SNAPSHOT_ID='SNAPSHOT_ID' RESTORE_TARGET='/srv/projectd-restore' \
  bash ./03-restore-b2.sh /etc/projectd/restic.env
```

The result is written to `/root/projectd-evidence/restore-result.txt`, including exit code, start time, end time, elapsed seconds, and HH:MM:SS. The log does not print `restic.env` or the process environment.

**Observed run, 25 November 2026:**

| Item | Result |
| --- | --- |
| Snapshot | `982aa532`, `2026-11-24T21:00:23Z`, selected as `latest` |
| Start / end (UTC) | `2026-11-25T18:28:47Z` / `2026-11-25T18:28:56Z` |
| Timed `restic restore` | **9 seconds**, exit status `0` |
| Restic summary | **514 files/dirs, 51.523 MiB** |
| Disk verification | **400 regular files**, `du -sh` = **53M** |
| Scope | Files restored to `/srv/projectd-restore`; no service stopped or started and no restored configuration activated |

Evidence: [complete log](b2-file-restore-2026-11-25.log), [timing/result](b2-file-restore-result-2026-11-25.txt), and [restore record](../../tests/restore/restore-log.md).

For Check-in 5, retain:

- snapshot ID/date and repository size from `restic snapshots` / `restic stats` when available;
- timing from `restore-result.txt`;
- `du -sh /srv/projectd-restore`;
- a screenshot or log showing successful completion;
- separately measured download, service-start, and full-readiness times when available.

`restic restore` alone proves file recovery, not a working application. Also test simulator → MQTT/TLS → Telegraf → InfluxDB → Grafana/dashboard. `tests/restore/restore-log.md` now contains the observed file-only result and a separate, still-open full application acceptance checklist.

## 7. Start the restored configuration and services

> **Only on a clean replacement server for Contabo.** On the standalone server, never install the restored `wg0.conf`: it
> contains the production WireGuard server key and would replace the live standalone tunnel (all team peers lose access).
> A functional drill on the standalone must start the restored Compose services under a separate project name, without
> published ports and without WireGuard. The restored tree holds production secrets: keep it `root:root 700` and delete it
> after the drill.

If the restored file exists as `/srv/projectd-restore/etc/wireguard/wg0.conf`:

```bash
install -m 600 /srv/projectd-restore/etc/wireguard/wg0.conf /etc/wireguard/wg0.conf
systemctl enable --now wg-quick@wg0
wg show wg0
```

Locate the restored project directory and follow its deployment and backup READMEs. Do not blindly start every Compose file: inspect variables, volumes, ports, Compose project name, and network names first. Before changing a running Contabo stack, use read-only `deployment/contabo/reconcile_check.py`.

Minimum standalone validation:

```bash
cd /opt/coil-projectD/deployment/contabo
docker compose ps
ss -lntup
wg show
curl -fsS http://127.0.0.1:13000/api/health
curl -fsS http://127.0.0.1:18088/healthz
systemctl is-active projectd-sim@mati projectd-sim@szczecin
```

## 8. Alert 2 and missing data

### Completed sensor-silence tests — 23 November 2026

Both runs stopped only `projectd-sim@szczecin`; `projectd-sim@mati` remained the control. Grafana alert-instance states were polled through the API every 5 seconds. A trap restarted the service if the test script failed.

| Event | First test UTC | Recorded test UTC |
| --- | --- | --- |
| Szczecin simulator stopped | 19:59:53 | 20:12:01 |
| All three Szczecin sensors `Alerting` | 20:01:49 | 20:13:47 |
| Simulator restarted | 20:02:34 | 20:14:32 |
| All six instances `Normal` again | 20:02:49 | 20:14:48 |
| Stop-to-alert elapsed time | 116 s | 106 s |
| Restart-to-full-recovery elapsed time | 15 s | 16 s |

The alert evaluates the **age of the latest reading**, not elapsed time since `systemctl stop`. The last reading before shutdown explains an observed delay below 120 seconds. The rule uses a 120-second threshold and is evaluated every 30 seconds. Mati remained `Normal` throughout.

First-test evidence: `alert2/summary.json`, `alert2/run.log`, and the `alert2-before.json`, `alert2-firing.json`, and `alert2-recovered.json` state files.

Recorded-test evidence: `alert2-recorded/summary.json`, `alert2-recorded/run.log`, `alert2-recorded-run.log`, and state JSON files under `alert2-recorded/`.

Visual evidence from the recorded test:

- Grafana: `browser/grafana-alert2-before.png`, `grafana-alert2-firing.png`, and `grafana-alert2-recovered.png`;
- Team Dashboard: `browser/team-dashboard-before.png`, `team-dashboard-firing.png`, and `team-dashboard-recovered.png`;
- full-length recordings: kept outside the repository (only the 8× versions are committed);
- 8× versions: `browser/grafana-alert2-8x.webm` and `team-dashboard-alert2-8x.webm`;
- capture control: `browser-capture.log`, with `CAPTURE_STATUS=PASS`.

SMTP is disabled, so **email delivery was not tested**. This test demonstrates Grafana and dashboard reactions to missing data; it does not replace a physical WireGuard interruption and subsequent handshake.

### Physical VPN interruption — still to be performed

Use an agreed maintenance window and an access path that will not be cut off:

```bash
cd /root/projectd-setup
bash ./04-vpn-break-test.sh wg0
```

By default, VPN is disabled for `120 + 30` seconds and then restored automatically. A trap also restores VPN if the script is interrupted. Retain the log, `vpn-test-result.txt`, Alert 2 evidence, a fresh handshake, and a post-recovery connectivity test.

The Szczecin-side laptop procedure additionally requires stopping the server-side Szczecin simulator before starting the laptop instance. The laptop simulator must remain one uninterrupted process throughout baseline, interruption, and queue drain: its queue is **memory-only**, and restarting the process discards queued readings. Mati remains active as the control.

## 9. `delay_ms` analysis — completed

`tests/delay/analyze_delay.py` ran in a one-shot container attached to the internal Docker network with an existing read-only token. InfluxDB was not exposed publicly. Raw InfluxDB responses were retained as `*.raw.csv` beside the analysis results.

### Normal operation

Window: `2026-11-23T19:23:00Z`–`2026-11-23T19:59:50Z`; 444 samples.

| Scope | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Mati | 222 | 1.688 | 1.674 | 2.345 | 0.441 | 4.103 | 0 |
| Szczecin | 222 | 1.274 | 1.293 | 1.944 | 0.378 | 2.315 | 0 |

### Recovery

Window: `2026-11-23T20:02:34Z`–`2026-11-23T20:05:00Z`; 30 samples.

| Scope | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Mati | 15 | 1.639 | 1.606 | 2.191 | 1.128 | 2.191 | 0 |
| Szczecin | 15 | 10.921 | 2.192 | 47.370 | 1.154 | 47.370 | 0 |

The recovery window is short. Szczecin p95 equals the maximum with five samples per sensor and must not be compared directly with the long normal-operation window.

`delay_ms` is Telegraf processing time minus the payload timestamp, **not pure network latency**. Both simulators and the full stack ran on the same server, so this result describes local processing rather than a link between independent hosts. `timedatectl timesync-status` before and after analysis showed NTP synchronization with a +2.584 ms offset.

Evidence: `delay-normal.raw.csv`, `delay-normal.csv`, `delay-normal.md`, `delay-normal-chart.png`, corresponding `delay-recovery.*` files, and `delay-analysis-run.txt`.

Production delay measurements through the real inter-host/VPN path remain open and must not be inferred from this local baseline.

## 10. Evidence and definition of done

| Item | Minimum evidence | Status |
| --- | --- | --- |
| Firewall | log, `ufw status`, second SSH session, rule test | Host UFW hardening complete; updated per-peer policy **31/31** in isolated namespaces, `firewall-netns-qwerty-2026-11-25.txt`; revised rules not enabled live |
| Updates | apt log, reboot, and new SSH session | Completed on 22 November |
| Docker and stack | Compose status, health checks, 6/6 sensors | Complete; `redeploy-b0414de.txt` |
| Repository tests | Ubuntu result without skips | Current `cacdbcb`: 58 unit + 18 restore-layout + 28 firewall-netns checks passed; compile, shell, JSON/YAML and Compose also passed (`ubuntu-regression-cacdbcb.log`). Updated qwerty policy separately passed 31/31 on 25 Nov. Earlier baseline: 56/56 |
| WireGuard | `wg show`, handshake, and ping through tunnel | Server configured; qwerty handshake observed. Darek's old peer was replaced; laptop activation/handshake/ping not confirmed |
| B2 restore | exit code 0, snapshot, timing, functional test | **File-only PASS 25 Nov:** exit 0, snapshot `982aa532`, 9 seconds, 514 files/dirs, 400 regular files verified. Functional application restore and full-readiness timing remain open |
| Alert 2 — missing data | API log, alert, and recovery | Complete for a stopped simulator |
| VPN interruption | interruption log, alert, new handshake | **Not performed** |
| `delay_ms` | raw export, CSV, report, chart, and time window | Complete for the local standalone baseline; Mati production path reported separately |
| Dashboard and Grafana | screenshots/recording of the working system | Complete; screenshots and recordings under `browser/` |
| Security remediation | running versions, health, reconnections, file modes, direct broker tests | Standalone verified at `cacdbcb`: Grafana 12.1.10, Mosquitto 2.0.23; client-ID spoof and 1 MB packet rejection passed (`broker-live-security-cacdbcb.log`); production not independently verified |

## 11. Dependencies and follow-up

- Production MQTT broker fix: Jeslito reported it deployed on 24 Nov. Direct production client-ID takeover and 1 MB negative tests are still recommended; the passed ACL test does not replace them.
- Production Team Dashboard and optional B2 mirror: Jeslito.
- Faculty WireGuard QR profiles: send only after confirming key compatibility; standalone uses new keys.
- Team accounts: provisioned on 24 Nov. Jeslito has VPN `.10`, Grafana Admin and SSH/sudo; qwerty_l3y has VPN `.12` and Grafana Editor, with a real handshake observed; Mykyta has VPN `.21` and Grafana Editor. Darek reported all three Grafana logins completed; all three password files were deleted on 25 Nov and a follow-up check found zero. Jeslito/Mykyta VPN handshakes remain unconfirmed; do not grant everyone root/sudo/docker access.
- Darek's compromised laptop peer was revoked and a new public key enrolled on 24 Nov. The local profile requires administrator activation before handshake, ping or VPN-break testing.
- Faculty access evidence requires a real VPN login/handshake and a successful read-only application session, not merely a generated QR profile.
- Email alerts remain unverified on standalone because SMTP is disabled. If email notification is a minimum requirement, Jeslito must demonstrate it on production.
- Contabo firewall and public Coolify/Supabase exposure are **reported risks requiring owner verification**, not findings independently verified in this session. Record the observed configuration and remediation in the security report.
- Peer evaluation: document task assignments, deadlines, responses, and missing responses on Discord without speculating about motivation.

## 12. Production and repository update — 24 November 2026

- PR #3 was merged into `origin/main` as `a30a9d4`.
- The broker fix, audit report, remediation update and matrix update were published on the fork's `szczecin-wol-vpn` branch in commits `0064e93`, `36bb841`, `27d2eb0` and `6d6bcd8`. These later commits were not in `origin/main` when checked.
- Jeslito reported production Mosquitto 2.1.2 with `use_username_as_clientid true` and `max_packet_size 16384`; configuration validation, restart, Telegraf reconnection and Mati ingestion succeeded. The recorded negative test was an ACL denial.
- Jeslito reported the first real Mati-path measurement: 66 readings (22 per sensor), mean 127.5–131.8 ms and p95 138.7–147.7 ms. This is MQTT reception delay including clock offset, not pure network latency. Add `mati_normal_2026-11-24.csv` before treating the result as a complete evidence package.
- Szczecin real-path delay, both physical VPN interruption tests, the **functional application phase** of B2 restore, faculty sessions and email evidence remain open. The timed file-only B2 restore passed on 25 November.
