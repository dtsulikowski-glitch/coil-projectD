# Check-in 5 evidence — status 25 Nov 2026

The production system stays on Contabo. Standalone results come from a **second, independent server** that Darek deployed from this repository to prove the setup guide works and to run tests without touching production. It uses its own keys and secrets; none of them are in this folder.

Start here: [requirements and evidence matrix](requirements-evidence.md) · [setup and restore runbook](setup-runbook.md) · [demo recording script](demo-script.md) · standalone deck `Project-D-standalone-testing-EN.pptx` · **joint final draft** `Project-D-joint-final-draft.pptx` · **rough-cut video** `Project-D-standalone-rough-cut.mp4` (70 s, captions, no narration; standalone evidence only).

## Done or started

| Item | Result | Evidence |
| --- | --- | --- |
| Standalone deployment | WireGuard, MQTT TLS + per-sensor accounts, Telegraf, InfluxDB, Grafana, Team Dashboard and both city simulators. `DEPLOY_STATUS=0`, 6/6 sensors with fresh readings. Re-run: 47 s; this is not a B2 restore | `redeploy-b0414de.txt`, `post-redeploy-health-b0414de.txt` |
| B2 file-only restore | **PASS 25 Nov:** real snapshot `982aa532`, exit 0, **9 seconds**, 514 files/dirs (51.523 MiB), 400 regular files verified on disk. No restored services activated; functional application recovery remains open | `b2-file-restore-2026-11-25.log`, `b2-file-restore-result-2026-11-25.txt`, [restore record](../../tests/restore/restore-log.md) |
| Standalone hardening | SSH key-only, UFW: only 22/tcp and 51820/udp public. Project services on VPN/loopback only. Scoped InfluxDB tokens. Updated per-peer policy including qwerty `.12`: 31/31 isolated checks; not enabled live | `post-redeploy-health-b0414de.txt`, `firewall-netns-qwerty-2026-11-25.txt` |
| Repo tests | 56/56 offline tests, 28/28 firewall network-namespace checks (commit `b0414de`); updated qwerty policy separately passed 31/31 on 25 Nov | `offline-tests-linux-b0414de.txt`, `firewall-netns-b0414de.txt`, `firewall-netns-qwerty-2026-11-25.txt` |
| Alert 2 (sensor silent) | Szczecin simulator stopped → all 3 SZCZ alerts Firing after 106 s. Restart → all 6 Normal after 16 s. Mati stayed Normal as the control | `alert2-recorded/`, `browser/` |
| Local `delay_ms` baseline | 444 samples, p95 Mati 2.345 ms, Szczecin 1.944 ms. **Single-host baseline only**, not system or VPN latency | `delay-normal.md`, `delay-normal-chart-en.png`, raw CSVs |
| Production MQTT hardening | Jeslito reported Mosquitto 2.1.2 with both new options deployed on 24 Nov; ACL negative test passed. Direct client-ID takeover and 1 MB production tests remain recommended | [audit remediation](../../documents/security-audit-2026-11-19.md#remediation-status--24-nov-2026), Discord report; screenshots not yet copied here |
| Mati real-path delay | Jeslito reported 66 readings (22 per sensor), mean 127.5–131.8 ms and p95 138.7–147.7 ms over Mati laptop → WireGuard → Contabo MQTT TLS. Reception delay includes clock offset | Discord report; `mati_normal_2026-11-24.csv` still to be added |
| PR #3 | Merged into `origin/main` as `a30a9d4` | [merge commit](https://github.com/Jeslito30/coil-projectD/commit/a30a9d48c1477ee3a1b2281dd87c00eb0c1b1eac) |
| Security fix and audit | Published on the fork's `szczecin-wol-vpn` branch through `6d6bcd8`; these later commits are not yet in `origin/main` | commits `0064e93`, `36bb841`, `27d2eb0`, `6d6bcd8` |

SMTP is disabled on the standalone server, so email delivery is **not** covered by its Alert 2 test.

## Still open before the final (2 Dec)

| # | Task | Owner |
| --- | --- | --- |
| 1 | Team accounts are provisioned and Darek reports all three Grafana logins completed; password files were deleted 25 Nov. Confirm the remaining Jeslito/Mykyta VPN handshakes | Darek + team members |
| 2 | File-only B2 restore is complete. Start the restored production stack in an isolated configuration and run functional InfluxDB, Grafana, ingestion and full-readiness checks | Jeslito + Darek |
| 3 | Physical VPN-drop tests with Alert 2 and reconnection; Szczecin and Mati are separate evidence items | Darek + Jeslito |
| 4 | Add the Mati raw CSV and production screenshots; run direct production client-ID and 1 MB negative tests | Jeslito |
| 5 | Real-path Szczecin delay result | Darek |
| 6 | Final narration, deck updates and group video edit | qwerty_l3y + Jeslito |
| 7 | Real faculty VPN handshakes and read-only sessions; email evidence if required | Jeslito / faculty |
| 8 | Final presentation, evidence links and peer evaluation | all |

No merge, account creation, B2 restore, VPN interruption or production test is claimed here without its observed result.
