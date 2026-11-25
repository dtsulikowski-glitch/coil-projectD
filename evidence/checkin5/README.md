# Check-in 5 evidence — status 25 Nov 2026

The production system stays on Contabo. Standalone results come from a **second, independent server** that Darek deployed from this repository to prove the setup guide works and to run tests without touching production. It uses its own keys and secrets; none of them are in this folder.

Start here: [requirements and evidence matrix](requirements-evidence.md) · [setup and restore runbook](setup-runbook.md) · [demo recording script](demo-script.md) · standalone deck `Project-D-standalone-testing-EN.pptx` · **joint final draft** `Project-D-joint-final-draft.pptx` · **rough-cut video** `Project-D-standalone-rough-cut.mp4` (70 s, captions, no narration; standalone evidence only).

## Done or started

| Item | Result | Evidence |
| --- | --- | --- |
| Standalone deployment | WireGuard, MQTT TLS + per-sensor accounts, Telegraf, InfluxDB, Grafana, Team Dashboard and both city simulators. `DEPLOY_STATUS=0`, 6/6 sensors with fresh readings. Re-run: 47 s; this is not a B2 restore | `redeploy-b0414de.txt`, `post-redeploy-health-b0414de.txt` |
| B2 restore and isolated functional drill | **PASS 25 Nov, with documented intervention:** snapshot `982aa532`; file-only extraction 9 s; functional-drill extraction 7 s; full RTO **264 s**, active functional phase **27 s**. InfluxDB, Grafana inventory and new MQTT → Telegraf → InfluxDB ingestion verified. Not a clean-machine/no-intervention pass: restored `.env` and Mosquitto hashes required isolated realignment; historical freshness at the backup boundary was not established | [restore record](../../tests/restore/restore-log.md), [functional result](functional-restore-2026-11-25/functional-result.txt), [cleanup](functional-restore-2026-11-25/functional-cleanup-verification-2026-11-25.log) |
| Standalone hardening | SSH key-only, UFW: only 22/tcp and 51820/udp public. Project services on VPN/loopback only. Scoped InfluxDB tokens. Per-peer policy including qwerty `.12`: 31/31 isolated checks, enabled live and matched `--check`; MQTT TLS, Grafana and dashboard worked through VPN | `post-redeploy-health-b0414de.txt`, `firewall-netns-qwerty-2026-11-25.txt`, [live firewall](../../../audit-2026-11-24/firewall-live-enable-2026-11-25.log) |
| Repo tests | Current `cacdbcb`: 58 unit + 18 restore-layout + 28 firewall-netns checks on Ubuntu, plus compilation, shell, JSON/YAML and Compose validation; updated qwerty policy separately passed 31/31 on 25 Nov. Earlier baseline: 56/56 offline tests | `audit-2026-11-24/ubuntu-regression-cacdbcb.log`, `firewall-netns-qwerty-2026-11-25.txt`, `offline-tests-linux-b0414de.txt` |
| Alert 2 (stopped simulator) | Szczecin simulator stopped → all 3 SZCZ alerts Firing after 106 s. Restart → all 6 Normal after 16 s. Mati stayed Normal as the control | `alert2-recorded/`, `browser/` |
| Physical VPN interruption — Szczecin | **PASS 25 Nov:** 180.299 s tunnel break; all 3 alerts fired and recovered; one uninterrupted process queued 6 readings/sensor, then drained with zero unacknowledged. InfluxDB: 30 sequential readings/sensor. Mati stayed Normal | [combined verification](vpn-break-szczecin-2026-11-25/log-alert-verification.json), [sequence analysis](vpn-break-szczecin-2026-11-25/sequence-analysis.json), [final health](vpn-break-szczecin-2026-11-25/final-stable-health.log) |
| Local `delay_ms` baseline | 444 samples, p95 Mati 2.345 ms, Szczecin 1.944 ms. **Single-host baseline only**, not system or VPN latency | `delay-normal.md`, `delay-normal-chart-en.png`, raw CSVs |
| Real Szczecin VPN-path `delay_ms` | 51 baseline samples: median **−61.872 ms**, p95 **358.501 ms**; 18 queued samples: median **100.524 s**, p95 **175.537 s**. Negative values retained as clock diagnostics; not ping or pure network latency | [baseline](vpn-break-szczecin-2026-11-25/delay-baseline.md), [queued](vpn-break-szczecin-2026-11-25/delay-queued.md), [raw export](vpn-break-szczecin-2026-11-25/influx-delay-laptop.csv) |
| Production MQTT hardening | Jeslito reported Mosquitto 2.1.2 with both new options deployed on 24 Nov; ACL negative test passed. Direct client-ID takeover and 1 MB production tests remain recommended | [audit remediation](../../documents/security-audit-2026-11-19.md#remediation-status--24-nov-2026), Discord report; screenshots not yet copied here |
| Mati real-path delay | Jeslito reported 66 readings (22 per sensor), mean 127.5–131.8 ms and p95 138.7–147.7 ms over Mati laptop → WireGuard → Contabo MQTT TLS. Reception delay includes clock offset | Discord report; `mati_normal_2026-11-24.csv` still to be added |
| Team accounts and VPN access | Jeslito, qwerty and Mykyta provisioned; Darek reports all three Grafana logins completed. VPN handshakes observed on 25 Nov (CET): Jeslito `.10` 12:57, qwerty `.12` 16:41, Mykyta `.21` 17:15, Darek `.22` 21:07 — server `latest-handshakes` joined with the raw `allowed-ips` key mapping. All Grafana password files were deleted | [handshake times](vpn-break-szczecin-2026-11-25/server-simulator-restore-and-handshakes.log), [key/address mapping](wg-allowed-ips-2026-11-25.txt), [joined table](wg-peer-mapping-2026-11-25.txt) |
| PR #3 | Merged into `origin/main` as `a30a9d4` | [merge commit](https://github.com/Jeslito30/coil-projectD/commit/a30a9d48c1477ee3a1b2281dd87c00eb0c1b1eac) |
| Security fix and audit | Published on the fork's `szczecin-wol-vpn` branch through `6d6bcd8`; these later commits are not yet in `origin/main` | commits `0064e93`, `36bb841`, `27d2eb0`, `6d6bcd8` |

SMTP is disabled on the standalone server, so email delivery is **not** covered by its Alert 2 test.

## Still open before the final (2 Dec)

| # | Task | Owner |
| --- | --- | --- |
| 1 | Complete the Mati-side physical VPN-drop test; add its raw evidence, the Mati delay CSV and production screenshots; run direct production client-ID and 1 MB negative tests | Jeslito |
| 2 | Repeat the restore on a fresh VM without intervention. Reconcile the source Mosquitto `.env`/password hashes and investigate historical freshness at the backup boundary. **Migration remains on hold until these checks pass** | Darek + Jeslito |
| 3 | Real faculty VPN handshakes and read-only sessions; email evidence if required | Jeslito / faculty |
| 4 | Final narration and group video edit; remove outdated restore/VPN-open statements from the rough cut | qwerty_l3y |
| 5 | Independent runbook review | Mykyta |
| 6 | Merge `szczecin-wol-vpn` into `main` after review; create `v1.0-final` only after the merge and final evidence review | Jeslito |
| 7 | Joint final presentation, evidence links and evidence-based peer evaluation | all |

No merge, account creation, B2 restore, VPN interruption or production test is claimed here without its observed result.
