# Project D — Minimum Requirements and Evidence Matrix

**Status as of 25 November 2026**

**Standalone server:** `<standalone-server>`

**Baseline deployment commit:** [`b0414de`](https://github.com/dtsulikowski-glitch/coil-projectD/commit/b0414de7ea38f8ab7dea5da778ff7f7e03b45188)

Unless a row explicitly says production, its status applies only to the standalone server, not Contabo. “Ready” means the linked result exists; a script or template alone is not proof of execution.

## Minimum requirements and proof

| Requirement | Evidence | Status and limitation |
| --- | --- | --- |
| Repeatable standalone deployment | [Deployment log](redeploy-b0414de.txt): `DEPLOY_STATUS=0`, 47 seconds, 6/6 sensors; [post-deployment health check](post-redeploy-health-b0414de.txt) | **Complete as a redeployment.** Not a from-scratch installation measurement or a B2 restore. |
| Restore on a clean machine from B2, with timing | [Observed restore log](b2-file-restore-2026-11-25.log), [timing/result](b2-file-restore-result-2026-11-25.txt), [restore record and remaining functional checklist](../../tests/restore/restore-log.md) | **File-only restore passed 25 Nov:** snapshot `982aa532`, exit 0, 514 files/dirs (51.523 MiB), 9 seconds, 400 regular files verified on disk. **Full clean-machine application restore remains open:** services were not started and data/ingestion were not functionally validated. |
| Server hardening and firewall | [Updated per-peer network-namespace test](firewall-netns-qwerty-2026-11-25.txt): 31/31; [listener and health check](post-redeploy-health-b0414de.txt): publicly only SSH and WireGuard | **Host UFW hardening verified; updated per-peer policy passed isolated tests 25 Nov.** qwerty `.12` is included for MQTT/Grafana/dashboard. The revised `PROJECTD-WG` rules were **not enabled** on the live host. Contabo exposure is separate. |
| Repository validation | `audit-2026-11-24/ubuntu-regression-cacdbcb.log`: 58 unit + 18 restore-layout + 28 firewall-netns checks; Python compilation, shell syntax, JSON/YAML and Compose validation | **Complete on Ubuntu for current `cacdbcb`, without skips.** Earlier baseline evidence: 56/56 in `offline-tests-linux-b0414de.txt`. |
| WireGuard server configuration | [Post-deployment health check](post-redeploy-health-b0414de.txt); [deployment/runbook status](setup-runbook.md#current-standalone-status); `audit-2026-11-24/darek-vpn-renewal.log` | **Server configured; qwerty handshake observed.** Darek's compromised peer was revoked and a replacement public key enrolled. Laptop activation, handshake and ping remain **unconfirmed** pending Windows administrator approval. |
| Alert 2 when sensor data stops | [Recorded-test summary](alert2-recorded/summary.json), [test log](alert2-recorded/run.log), [Grafana firing](browser/grafana-alert2-firing.png), [Grafana recovered](browser/grafana-alert2-recovered.png), [Team Dashboard silent](browser/team-dashboard-firing.png) | **Complete for a stopped simulator.** Alert after 106 seconds; full recovery 16 seconds after restart; Mati remained Normal. Not a physical VPN-drop test. |
| Alert 2 after a physical VPN interruption | [VPN test requirements](setup-runbook.md#physical-vpn-interruption--still-to-be-performed) | **Open.** Required: tunnel interruption, Alert 2, recovery, fresh handshake, and connectivity. Szczecin and Mati sides are separate evidence items. |
| Delay analysis | [Normal-operation report](delay-normal.md), [raw export](delay-normal.raw.csv), [analysis CSV](delay-normal.csv), [English chart](delay-normal-chart-en.png), [recovery report](delay-recovery.md) | **Local standalone baseline complete:** 444 normal and 30 recovery samples. `delay_ms` is not pure network latency; both simulators were local. |
| Production/inter-host delay through VPN | Jeslito, Discord #group-10, 24 Nov 2026 (CSV `mati_normal_2026-11-24.csv`, to be added here) | **Started — Mati only.** 66 readings (22 per sensor) over the real Mati laptop → WireGuard → Contabo MQTT TLS path, measured by a separate read-only subscriber: mean 127.5–131.8 ms, p95 138.7–147.7 ms per sensor. MQTT reception delay including clock offset, not pure network latency. Szczecin real-path figures still open. |
| Team Dashboard and Grafana | [Dashboard before test](browser/team-dashboard-before.png), [Dashboard Silent](browser/team-dashboard-firing.png), [Grafana Firing](browser/grafana-alert2-firing.png) | **Standalone works.** Production deployment and the optional public B2 mirror remain with Jeslito. |
| MQTT with TLS | [Post-deployment health check](post-redeploy-health-b0414de.txt) | **TLS verified on standalone.** This row does not prove production client-ID and packet-limit hardening. |
| Production MQTT hardening: client-ID takeover and packet-size limit | Jeslito, Discord #group-10, 24 Nov 2026 (screenshots); [audit remediation status](../../documents/security-audit-2026-11-19.md#remediation-status--24-nov-2026) | **Deployed on production 24 Nov, reported by Jeslito:** Mosquitto 2.1.2 with `use_username_as_clientid true` and `max_packet_size 16384`, ACL `1883:1883`/`640`, negative ACL test passed. A direct client-ID takeover / 1 MB test against production is still recommended. |
| Email alert notification | [Standalone SMTP limitation](setup-runbook.md#completed-sensor-silence-tests--23-november-2026) | **Not demonstrated on standalone; SMTP is disabled.** If email is a minimum requirement, Jeslito must supply production send/receive evidence. Earlier check-in claims do not replace final evidence. |
| Faculty VPN profiles and read-only access | [Access evidence requirements](setup-runbook.md#11-dependencies-and-follow-up) | **Open.** Generated QR profiles are not proof of use. Required: real handshakes and successful read-only sessions for both faculty, without exposing private keys. |
| Setup guide and runbook | [English setup and restore runbook](setup-runbook.md) | **Complete as a draft with observed results and explicit open items.** Updated 25 Nov with the successful timed file-only B2 restore; functional application recovery remains open. |
| Demo scenario | [English demo recording script](demo-script.md) | **Complete as a script with a 24 Nov addendum.** Final group footage still needs production, Mati, and faculty-access sections. |
| Alert 2 demo recordings | [Grafana 8×](browser/grafana-alert2-8x.webm), [Team Dashboard 8×](browser/team-dashboard-alert2-8x.webm), [capture log](browser-capture.log) | **Recordings ready.** The final group video requires editing and must not imply completion of B2 or physical VPN tests. |
| Evidence-based peer evaluation | [Documentation rule](setup-runbook.md#11-dependencies-and-follow-up) | **Process defined.** Retain dated Discord assignments, reminders, responses, and artefact/commit links; describe observable contributions only. |

## Code, production, and security follow-up

| Item | Evidence / action required | Current status |
| --- | --- | --- |
| PR #3 | [Merged `origin/main` commit](https://github.com/Jeslito30/coil-projectD/commit/a30a9d48c1477ee3a1b2281dd87c00eb0c1b1eac) | **Merged 24 Nov as `a30a9d4`.** Later security commits are on the fork's `szczecin-wol-vpn` branch and are not in `origin/main` at this check. |
| GitGuardian red check | Repository maintainer must inspect and classify reported template/example values in GitGuardian | **Open maintainer action.** The audit classifies all five as placeholders/test values; no claim is made here that the GitGuardian check has turned green. |
| Security fix and audit publication | Commits `0064e93`, `36bb841`, `27d2eb0`; matrix update `6d6bcd8` | **Published on the fork's `szczecin-wol-vpn` branch 24 Nov.** No separate `held-security` branch was visible on either inspected remote at this check. |
| Standalone security update | [Live audit addendum](../../documents/full-audit-2026-11-24.md#live-remediation-addendum--24-november-2026-2137-cet); `audit-2026-11-24/post-update-status.log`, `mosquitto-permissions-fix.log` and `broker-live-security-cacdbcb.log` | **Verified on standalone at `cacdbcb`:** Grafana 12.1.10 healthy, Mosquitto 2.0.23, Telegraf and 6/6 simulators reconnected. Mosquitto passwd/ACL ownership and modes corrected. Direct live client-ID spoof and 1 MB packet tests both passed; affected simulators reconnected. Production remains a separate Jeslito action. |
| Production Team Dashboard | Live production URL through VPN and evidence of the optional B2 mirror if delivered | **Jeslito's task; open in this package.** |
| Contabo firewall and public Coolify/Supabase ports | Owner-controlled configuration review, external port evidence, and remediation record | **Reported risk, not independently verified in this session.** Keep separate from verified standalone firewall results. |
| Full reboot ordering | Reboot → WireGuard → Docker → application health and ingestion | **Open.** The Docker ordering override exists, but the complete reboot test has not been recorded. |
| Team accounts on standalone | Provisioning script reached its final hand-over message on 24 Nov; all three non-secret WireGuard settings files were subsequently read from `/root/projectd-profiles/`; password-file removal check 25 Nov | **Provisioned.** Jeslito: VPN `.10`, Grafana Admin, SSH/sudo. qwerty_l3y: VPN `.12`, Grafana Editor, **real handshake observed**. Mykyta: VPN `.21`, Grafana Editor. Darek reported all three Grafana logins completed; all three password files were then deleted and zero remained on verification. Jeslito/Mykyta VPN handshakes remain unconfirmed. Darek's laptop activation is pending Windows administrator approval. |
| B2 restore log | [Completed file-only record and full functional protocol](../../tests/restore/restore-log.md) | **File-only PASS from observed output:** exit 0, snapshot `982aa532`, 9 seconds, 514 files/dirs and disk inventory. The full application acceptance section remains open. |

## Evidence handling rules

- Do not mark readiness from the existence of a script alone.
- Do not expose passwords, tokens, private keys, complete WireGuard profiles, or `backup.env` in evidence.
- Keep standalone and production results distinct.
- A stopped-simulator alert is not a physical VPN interruption.
- A redeployment is not a clean-machine restore.
- Local processing delay is not production network latency.
- A generated VPN profile is not evidence that faculty accessed the system.
