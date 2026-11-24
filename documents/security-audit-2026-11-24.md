# Project D — Full Code, Configuration and Security Audit

**Date:** 24 November 2026  
**Audited revision:** `6d6bcd899f9fa922746fe50a4574bfbc6fb20b56` (`szczecin-wol-vpn`)  
**Scope:** application code, Docker Compose and environment templates, Mosquitto, Telegraf, InfluxDB, Grafana, Team Dashboard, WireGuard/firewall scripts, backup/restore, standalone provisioning, CI, tests and secret exposure.  
**Method:** non-destructive static review, local automated tests, syntax/configuration validation, Gitleaks scans and a deterministic concurrency probe. No exploit, denial-of-service, destructive restore or disruptive VPN test was performed.

## 1. Executive summary

The repository has several sound security controls: service ports are bound to the VPN or loopback, InfluxDB is not published, MQTT uses TLS and per-account ACLs, anonymous MQTT access is disabled, and the Team Dashboard runs with a notably restrictive container profile. Automated secret scans found no detected credentials in either the working tree or the 76-commit history.

The system should nevertheless **not be treated as security-cleared in its current revision**. Four findings need priority attention:

1. **Critical:** the pinned Grafana 12.1.1 is affected by CVE-2026-27876 and CVE-2026-27880. Upgrade to a patched release before relying on Viewer/Editor accounts as a security boundary.
2. **High:** Mosquitto 2.0.22 predates security release 2.0.23. Upgrade and repeat the client-ID and packet-limit acceptance tests.
3. **High / unverified live:** production backups made with a separate deployment `.env` may not satisfy the restore script's fixed project-layout check. This must be tested with a real B2 snapshot on an isolated VM.
4. **Medium:** a confirmed race in the optional WoL relay can emit two final results for the same request ID.

A live read-only server-audit script was prepared and syntax-checked, but no `server-standalone-2026-11-24.log` result was available when this report was finalised. Therefore this report does **not** assert the current live firewall, patch, listener, container-health, WireGuard-handshake or backup-timer state. Production Contabo observations are limited to previously reported team evidence; Contabo was not directly audited here.

## 2. Findings and remediation priorities

| ID | Severity | Confidence | Area | Finding | Owner / priority |
|---|---|---|---|---|---|
| F-01 | **Critical** | Confirmed version exposure; exploit not run | Grafana | 12.1.1 is affected by critical authenticated RCE and high unauthenticated DoS vulnerabilities | Darek + Jeslito / **P0** |
| F-02 | **High** | Confirmed version exposure | Mosquitto | Repository pins 2.0.22; security release 2.0.23 is available. Production was reported as 2.1.2, while 2.1.3/2.1.4 contain newer security fixes | Darek + Jeslito / **P0** |
| F-03 | **High** | Strong static finding; real snapshot not tested | Backup/restore | External production `.env` is stored under `extra/`, but restore always requires `project/deployment/contabo/.env` | Darek + Jeslito / **P0 before final restore evidence** |
| F-04 | **Medium** | Reproduced deterministically | WoL relay | Check-then-insert race permits duplicate concurrent execution and duplicate final results | Darek / **P1 if WoL is enabled** |
| F-05 | **Medium** | Confirmed versions; exploitability not established | Dependencies | Telegraf 1.35.4 and InfluxDB 2.7.12 are substantially behind current release lines | Darek + Jeslito / **P1** |
| F-06 | **Medium** | Conditional configuration risk | Backup retention | Without genuinely enforced append-only/delete-denied B2 permissions, the server can delete its own snapshots during retention | Jeslito + Darek / **P1** |
| F-07 | **Low** | Confirmed by code | Secret handling | Influx tokens and generated MQTT passwords are briefly exposed in process argument lists | Darek / **P2** |
| F-08 | **Low** | Confirmed by code | File permissions | Scoped-token update preserves an existing permissive `.env` mode instead of enforcing `0600` | Darek / **P2** |
| F-09 | **Low** | Confirmed by code and Windows cleanup behaviour | WoL lifecycle | SQLite connection has no explicit close lifecycle | Darek / **P2** |
| F-10 | **Low / supply chain** | Confirmed by Compose | Images | Images are selected by tags, not immutable digests; `python:3.12-alpine` is a moving tag | Darek / **P2** |

Severity reflects potential impact and exposure in the documented architecture, not proof that an attack occurred.

## 3. Detailed findings

### F-01 — Grafana 12.1.1 requires an urgent security update

**Evidence:** `deployment/contabo/compose.yml:59–80` pins `grafana/grafana:12.1.1`. The Compose environment does not disable the `sqlExpressions` feature toggle. Grafana's current documentation lists SQL expressions as enabled by default.

Grafana's official security announcement states:

- **CVE-2026-27876, CVSS 9.1 Critical:** SQL expressions can permit arbitrary file writes chained to remote code execution. Exploitation requires data-source query access with Viewer permissions or higher and enabled SQL expressions. Versions 11.6.0 and later are affected.
- **CVE-2026-27880, CVSS 7.5 High:** the unauthenticated OpenFeature endpoint accepts unbounded input and can exhaust server memory. Versions 12.1.0 and later are affected.
- Grafana 12.1.10 is a patched 12.1.x release.

VPN-only binding reduces public exposure, but it does not remove the risk from authenticated Viewer/Editor users, compromised VPN peers or another compromised service able to reach Grafana. No exploit was attempted during this audit.

**Required action:**

1. Back up Grafana and test a staged upgrade to **12.1.10 or a newer supported patched release**.
2. Recreate only Grafana after review, then verify dashboards, alert rules, data-source tokens, account roles and health.
3. If an immediate upgrade is impossible, disable `sqlExpressions` as a temporary risk reduction; this does not fully remediate every issue.
4. Do not claim remediation until the running image version is read back from the actual server.

Official references:
- https://grafana.com/blog/grafana-security-release-critical-and-high-severity-security-fixes-for-cve-2026-27876-and-cve-2026-27880/
- https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/feature-toggles/

### F-02 — Mosquitto security updates and regression testing

**Evidence:** `deployment/contabo/compose.yml:7–18` pins `eclipse-mosquitto:2.0.22`.

Mosquitto's official 24 November 2026 release notice identifies 2.0.23 as a security release and 2.1.3 as a critical security release. The 2.1.3 WebSocket flaw could potentially lead to remote code execution, but **this repository configures only a TLS MQTT listener and no WebSocket listener**, so that specific attack surface is not shown here. FIPS authentication and dynamic-security conditions also are not part of this configuration. The finding remains valid because security fixes should not be selectively dismissed without a complete image/configuration review.

Both release lines also include fixes to maximum-packet-size handling. Existing protection in `docker/mosquitto/config/mosquitto.conf` includes `allow_anonymous false`, TLS listener 8883, `use_username_as_clientid true` and `max_packet_size 16384`, but the live effectiveness of these settings must be tested after an upgrade.

**Required action:**

- Standalone repository path: test **2.0.23** or a currently supported patched image.
- Production was **reported by Jeslito** as 2.1.2 on 24 November; upgrade planning should use **2.1.4**, not 2.1.3 alone, because 2.1.4 fixes a legacy SHA-512 password regression introduced in 2.1.3.
- Repeat direct client-ID takeover and 1 MB packet rejection tests on the actual broker. The reported production negative ACL test is useful, but it does not prove both controls.
- Confirm authentication, Telegraf ingestion, simulator reconnection and ACL behaviour after recreation.

Official reference: https://mosquitto.org/blog/2026/11/version-2-1-3-released/

### F-03 — Restore assumes one `.env` layout that external production backup may not contain

**Evidence:**

- `backup/backup.sh:9–16` supports a stack whose `.env` and Compose file live outside the repository through `PROJECTD_ENV_FILE` and `PROJECTD_COMPOSE_FILE`.
- `backup/backup.sh:78–90` stores such deployment directories under `extra/<absolute-path>` when `BACKUP_EXTRA_PATHS` is configured.
- `backup/restore.sh:48–56` restores the snapshot, locates the one `project` directory and then unconditionally requires `PROJECT_SRC/deployment/contabo/.env`.
- `backup/restore.sh:60–76` immediately builds Compose from that fixed path and uses its token for InfluxDB restore.

For a production snapshot whose real `.env` exists only in `extra/`, the script exits at line 56 before restoring data. Documentation telling an operator to recover configuration from `extra/` later does not remove this earlier hard failure.

**Impact:** the most important disaster-recovery path may fail even though the encrypted backup upload succeeded. This is a static, high-confidence code-path mismatch; it is **not** a claim that every real B2 snapshot lacks the fixed file.

**Required action:**

1. Add explicit `--env-file` and `--compose-file` restore inputs, or safely discover and validate the external deployment directory before constructing Compose.
2. Reject ambiguous candidates and never print secrets while validating them.
3. Add an integration fixture for both repository-local and external production layouts.
4. Run a timed restore from the real B2 snapshot to a fresh isolated VM and complete `tests/restore/restore-log.md`.

### F-04 — WoL duplicate-request race is reproducible

**Evidence:** `wol-relay/wol_relay.py:235–244` first calls `Store.get()` and then calls `Store.begin()` without checking its Boolean result. `Store.begin()` at lines 110–119 is individually locked and uses a primary key, but the earlier read and subsequent insert are not atomic across two `Relay.handle()` calls.

Two concurrent callbacks can both observe the request as unknown. One inserts successfully; the other receives `False` but proceeds anyway. The audit probe forced exactly this interleaving and produced two final results where one was expected:

```text
CONCURRENT_DUPLICATE_FINALS=2 EXPECTED=1
RESULT=CONFIRMED
```

Evidence: `../../audit-2026-11-24/wol-concurrency-probe.log`.

The target busy/rate-limit controls normally reduce duplicate wake impact, but they do not restore the promised exactly-once final-result behaviour. WoL is optional and was not shown as deployed in this audit, which limits current exposure.

**Required action:** treat successful `Store.begin()` as the single admission decision. If it returns `False`, re-read the record: emit the stored final result when complete; otherwise return the in-progress duplicate result. Add a regression test with two concurrent handlers.

### F-05 — Telegraf and InfluxDB lifecycle update required

**Evidence:** `deployment/contabo/compose.yml:21–57` pins Telegraf 1.35.4 and InfluxDB 2.7.12. Official release pages available during the audit list Telegraf 1.40.4 and InfluxDB OSS 2.10.1. This establishes outdated versions, not a specific exploitable CVE in Project D's enabled plugins.

InfluxDB 2.9 introduces token hashing by default and changes restore/downgrade handling. An upgrade therefore needs a backup/token plan, not only a tag change.

**Required action:** stage the update, preserve plaintext tokens needed for administration before hashing, verify the official 2.9 upgrade/restore procedure, test Flux dashboards and alerts, and measure ingestion before production rollout.

Official references:
- https://docs.influxdata.com/influxdb/v2/reference/release-notes/influxdb/
- https://docs.influxdata.com/telegraf/v1/release-notes/

### F-06 — Append-only backup protection is optional, not guaranteed

**Evidence:** `backup/backup.sh:110–118` runs `restic forget ... --prune` unless `RESTIC_APPEND_ONLY=1`. The comments correctly note that retention must then run from a separate trusted machine.

A variable alone cannot enforce backend permissions. If the B2 application key used by the server can delete objects, a compromised server can delete backups regardless of the intended operational model.

**Required action:** verify B2 key capabilities externally, prefer delete-denied/append-only architecture, move retention to a separate trusted machine and test that the server credential cannot destroy snapshots. Do not perform deletion tests against the only production backup.

### F-07 — Secrets appear transiently in process arguments

**Evidence:**

- `deployment/contabo/scoped_tokens.py:87–92` appends `--token <operator-token>` to a subprocess argument list.
- `backup/backup.sh:52` similarly supplies the Influx operator token on the command line.
- `backup/restore.sh:76` supplies the token during full restore.
- `docker/mosquitto/scripts/gen-passwd.sh:42–45` invokes `mosquitto_passwd -b` with the plaintext password argument.

On a single-administrator Linux host this is a limited, transient exposure. Co-administrators or process-monitoring tooling can increase it. It is not equivalent to storing credentials in Git.

**Required action:** use supported environment, file-descriptor or interactive secret-input mechanisms where available; ensure logs and error paths redact secrets; retain restrictive host access.

### F-08 — Scoped-token writer preserves unsafe existing `.env` permissions

**Evidence:** `deployment/contabo/scoped_tokens.py:49–74` deliberately copies the existing file mode to the temporary replacement. The docstring says mode 600 is kept, but the implementation does not enforce that mode if the source is already group/world-readable.

**Required action:** require or set `0600`, preserve appropriate ownership, fail loudly when ownership cannot be secured and test the pre-existing `0644` case on Linux.

### F-09 — WoL Store lacks explicit cleanup

**Evidence:** `wol-relay/wol_relay.py:92–150` opens SQLite but provides no `close()` or context-manager shutdown. Original Windows test teardown produced 17 cleanup errors because open database handles prevented temporary-file removal. The audit-only wrapper closed all test stores without changing project assertions, after which all 17 tests passed.

**Required action:** add an idempotent `Store.close()` and invoke it during service/test shutdown. This is principally reliability and test hygiene, not a demonstrated production security vulnerability.

### F-10 — Image provenance is not immutable

**Evidence:** all services in `deployment/contabo/compose.yml` use tags. The versioned tags reduce accidental upgrades, but tags can be republished; `python:3.12-alpine` also changes over time.

**Required action:** after selecting and testing fixed versions, record/pull by digest, review updates deliberately and redeploy from known artifacts. Include actual running digests in deployment evidence.

## 4. Controls that passed review

### Network and broker

- `deployment/contabo/compose.yml:10–12,65–67,111–113` binds MQTT, Grafana and Team Dashboard to `10.66.0.1` and loopback rather than all interfaces.
- InfluxDB has no host `ports` mapping (`compose.yml:38–57`).
- Mosquitto configuration has TLS-only listener 8883, no plaintext listener, anonymous access disabled, password/ACL files, client ID derived from username and a 16 KiB packet limit.
- Broker hardening on Contabo is a **team-reported status**, not an independently reproduced result in this audit. Direct client-ID and 1 MB tests remain recommended.

### Team Dashboard

- Runs as UID/GID 65534, with a read-only root filesystem, all capabilities dropped and `no-new-privileges` (`compose.yml:99–127`).
- Static-file allowlisting, security headers/CSP and DOM text insertion were reviewed. No obvious path traversal or DOM XSS was found in the reviewed paths.
- Influx failure tests check that tokens are not returned to clients.
- The dashboard is read-only and reachable by VPN peers; this is an architectural trust decision, not proof that every peer should have access to all data.

### CI and source control

- CI uses read-only token permissions and actions pinned to full commit SHAs.
- No repository secrets were detected by Gitleaks in the working tree or available history. This is a scanner result, not a mathematical guarantee against every possible credential format.

### Backup and restore design

- Restic encryption, restrictive umask, native InfluxDB backup, stopped-service Grafana/Mosquitto copies, and non-automatic activation of restored WireGuard configuration are sound design choices.
- Restore defaults to dry-run and requires both `--apply --yes`; destination checks reduce accidental overwrite risk.
- These positives do not replace a successful timed restore test.

## 5. Verification performed

All commands ran against the clean audit copy at revision `6d6bcd899f9fa922746fe50a4574bfbc6fb20b56`.

| Check | Result | Evidence |
|---|---|---|
| Simulator contract tests | **9/9 passed** | `../../audit-2026-11-24/tests-simulators.log` |
| Team Dashboard tests | **8/8 passed** | `../../audit-2026-11-24/tests-team-dashboard.log` |
| Telegraf registry/Starlark tests | **6/6 passed** | `../../audit-2026-11-24/tests-telegraf.log` |
| WoL relay tests with audit-only Windows cleanup wrapper | **17/17 passed** | `../../audit-2026-11-24/tests-wol-relay-windows-rerun.log` |
| Grafana account tests | 5 passed, 1 failed | `../../audit-2026-11-24/tests-grafana-telegraf-influx.log` |
| Influx scoped-token tests | 1 passed, 4 failed, 1 error | `../../audit-2026-11-24/tests-influx.log` |
| Compose/environment tests | 1 passed, 3 skipped | `../../audit-2026-11-24/tests-compose-env.log` |
| Configuration/syntax validation | 6 JSON, 6 YAML, 22 Python sources and 17 Bash/JavaScript files passed | `../../audit-2026-11-24/config-validation.log` |
| Gitleaks working tree | No leaks detected | `../../audit-2026-11-24/gitleaks.log` |
| Gitleaks full available history | 76 commits; no leaks detected | `../../audit-2026-11-24/gitleaks-history.log` |
| WoL concurrency probe | Duplicate final result confirmed | `../../audit-2026-11-24/wol-concurrency-probe.log` |

### Interpreting failed or skipped local tests

- The Grafana failure is the POSIX permission assertion `0600` versus Windows-reported `0666` (`438 != 384`). The implementation uses `umask(077)` and `chmod(600)`, but the POSIX assertion still needs confirmation on Ubuntu. It is not counted as a passed security check.
- Influx failures/errors arise when Windows `CreateProcess` cannot execute the extensionless mock `docker` file. They do not establish a production token-logic defect, and the original suite remains unverified on Linux.
- Three Compose tests require Docker and were skipped. Port-binding assertions were reviewed statically, but the Docker-based suite was not passed locally.
- The WoL wrapper is test infrastructure only. It changes no project code or assertions; it closes SQLite connections before Windows temporary-directory cleanup.
- Historical evidence of 56/56 or 28/28 tests belongs to older revision `b0414de`; it must not be attributed to this audit revision.

## 6. Live-system and production coverage

### Prepared but not completed

`../../audit-2026-11-24/server-readonly-audit.sh` and `run-server-audit.ps1` were prepared and syntax-checked. They are intended to collect only non-secret operational facts: OS/package status, listeners, firewall rules, service state, effective SSH settings, WireGuard handshakes, repository HEAD, selected container metadata, image digests, health endpoints and file modes.

No result log was present at report completion. The following therefore remain **unverified now**:

- standalone Ubuntu security-patch state;
- actual public listeners and effective UFW/iptables/DOCKER-USER rules;
- running image versions/digests and container health;
- SSH effective configuration and account permissions;
- WireGuard peer handshakes and whether provisioned users have logged in;
- backup timer status and presence/metadata of `backup.env`;
- current deployed Git revision;
- real B2 restore duration and acceptance checks.

### Production Contabo

There was no direct Contabo access in this audit. The following is only prior team-reported evidence: Mosquitto 2.1.2 with both hardening options, ACL ownership/mode, a negative ACL test and Mati sensor ingestion. No claim is made here about current Contabo firewall, Coolify/Supabase exposure, host patch level or running image digests.

## 7. Remediation and acceptance plan

### P0 — before calling the deployment secure

1. Upgrade Grafana on a staged copy and verify the running patched version.
2. Upgrade Mosquitto on the appropriate 2.0/2.1 release line; repeat direct client-ID and 1 MB tests.
3. Correct the restore configuration-layout mismatch and complete a timed B2 restore on an isolated fresh VM.
4. Run the read-only live audit and retain its log as evidence.

### P1 — next maintenance window

1. Fix and regression-test WoL concurrent duplicate admission before enabling WoL.
2. Stage Telegraf and InfluxDB updates with explicit token/backup/rollback procedures.
3. Verify delete-denied/append-only B2 controls and move retention off the backed-up server.
4. Re-run the complete Ubuntu test suite with Docker, including firewall network-namespace tests.

### P2 — hardening and maintainability

1. Remove secrets from process argument lists where supported.
2. Enforce secret-file mode `0600` and secure ownership.
3. Add explicit WoL SQLite shutdown.
4. Pin tested images by digest and record deployed digests.

### Required evidence after remediation

For each closed finding, retain the commit, exact non-secret command output, running version/digest, timestamp and acceptance-test result. A code change alone is not evidence that production or the standalone server has been remediated.

## 8. Overall assessment

**Code/configuration security posture: promising architecture, but remediation required.**  
**Secrets currently detected in Git: none by Gitleaks.**  
**Standalone live security state: unverified because the live audit result is missing.**  
**Production Contabo security state: not independently audited.**  
**Disaster-recovery readiness: not accepted until the real B2 restore succeeds end to end.**

This is a point-in-time audit of the stated revision, not a guarantee that the system is free of vulnerabilities or secure against every threat.

## 9. Remediation status — 24 November 2026 (evening)

Paths such as `../../audit-2026-11-24/*.log` refer to the auditor's local evidence folder and are not part of this repository.

| ID | Status in the repository | Still required |
|---|---|---|
| F-01 Grafana | Image pinned to `12.1.10` (patched for CVE-2026-27876 and CVE-2026-27880). The 12.1 line is past end of support, so 12.1.10 is a stopgap | Recreate Grafana on the standalone server and read the running version back; Jeslito: same on production. Plan a move to a supported line (12.4.x or newer) after the final, tested on the standalone server first |
| F-02 Mosquitto | Image pinned to `2.0.23` | Recreate the broker and repeat the client-ID takeover and 1 MB tests (`tests/security/broker_abuse_test.py`); production stays on the 2.1 line at the latest patch release |
| F-03 Restore layout | Fixed: `backup/restore.sh` accepts `--compose-file`, `--env-file` and `--influx-token-var` (original server paths), picks a single `.env` under `extra/` automatically, refuses ambiguous candidates without printing secrets. Regression test `tests/restore/test_restore_layouts.sh` (18 checks, fails on the previous version) runs in CI | Timed end-to-end restore from the real B2 snapshot |
| F-04 WoL race | Fixed: `Store.begin()` is the single admission decision; a handler that loses the race re-emits the stored final result or reports in-progress. Regression test `test_concurrent_duplicate_is_executed_once` (fails on the previous version) | — |
| F-05 Telegraf/InfluxDB | Unchanged on purpose: InfluxDB 2.9+ changes token storage and restore; not changed one week before the final | Staged upgrade after the final |
| F-06 Append-only B2 | Unchanged | Jeslito: verify the B2 key capabilities; restore test should use a read-only key |
| F-07 Secrets in argv | Unchanged | P2 |
| F-08 `.env` mode | Fixed: `scoped_tokens.py` always writes `.env` as 0600; regression test for a pre-existing 0644 file | — |
| F-09 WoL SQLite close | Unchanged | P2 |
| F-10 Image digests | Unchanged | P2 |

The Windows-only test failures in section 5 (POSIX mode check, extension-less mock `docker`, Docker-dependent skips) were re-run on Linux for this revision; see the commit message for counts.
