# Project D — fresh-VM restore protocol

## Completed file-only B2 restore — 25 November 2026

**Result:** **PASS for file extraction; full application restore not performed.**

| Item | Observed result |
| --- | --- |
| Operator | Kimi Work on Darek's standalone server |
| Start / end (UTC) | `2026-11-25T18:28:47Z` / `2026-11-25T18:28:56Z` |
| Measured `restic restore` duration | **9 seconds** (`00:00:09`) |
| Restic snapshot | `982aa532`, created `2026-11-24T21:00:23Z`; selected as `latest` |
| Repository | B2/restic; repository identifier and credentials withheld |
| Target | `/srv/projectd-restore` on the existing standalone server |
| Exit status | `0` |
| Restic inventory | **514 files/dirs, 51.523 MiB** |
| Disk verification | **400 regular files**, `du -sh` = **53M**; InfluxDB archives, `grafana.db`, `mosquitto.db`, project configuration and WireGuard files are present |
| Service impact | None: no production service was stopped, no Compose stack was started and no restored configuration was activated |

Evidence: [complete restore log](../../evidence/checkin5/b2-file-restore-2026-11-25.log) and [machine-readable timing/result](../../evidence/checkin5/b2-file-restore-result-2026-11-25.txt). The remote log is `/root/projectd-evidence/03-restore-20261125T192842.log`.

This proves recovery of the real B2 snapshot to files. It does **not** prove a clean-machine application restore, InfluxDB/Grafana functionality, ingestion, or full RTO. The protocol below remains the acceptance checklist for that separate functional test.

## Isolated functional application restore — 25 November 2026

**Result:** **PASS for the isolated functional checks, with documented manual intervention. This is not a clean-machine, no-intervention pass.**

| Item | Observed result |
| --- | --- |
| Restic extraction | Snapshot `982aa532`; extraction `2026-11-25T19:45:27Z`–`19:45:34Z` (**7 s**) |
| RTO under the requested start-to-final-check definition | **264 s**, from `19:45:27Z` to `19:49:51Z`; includes diagnosis between extraction and the functional phase |
| Active functional phase | **27 s**, from `19:49:24Z` to `19:49:51Z`; recorded separately and not presented as the full RTO |
| Isolation | Compose project `projectd-restore-drill`; **0 published ports**, no WireGuard activation, separate volumes and network |
| InfluxDB | Native full restore completed; `influx ping` passed |
| Historical data | Both cities present. Newest restored observations: Mati `2026-11-24T18:00:48.552Z`, Szczecin `2026-11-24T14:39:23.882Z`. **The snapshot does not establish sensor freshness at the backup boundary `2026-11-24T21:00:23Z`.** |
| Grafana | Isolated Grafana 12.1.1 health endpoint returned `database: ok`; read-only database inventory found **3 dashboards and 2 alert rules**. Login was not claimed as tested. |
| Mosquitto and ingestion | The broker started with the restored configuration, but the restored password hashes did not match the restored `.env` for `SZCZ-TEMP-01` or `telegraf`. Only an isolated copy of the password file was realigned with that `.env`; the source snapshot was not modified. A new reading then passed MQTT TLS → Telegraf → InfluxDB at `2026-11-25T19:49:48.258Z`. |
| Cleanup | `down -v --remove-orphans`; zero isolated containers/volumes; `/srv/projectd-restore` removed. Live Grafana remained healthy and both live simulator services remained active. |

Evidence: [functional result](../../evidence/checkin5/functional-restore-2026-11-25/functional-result.txt), [full drill log](../../evidence/checkin5/functional-restore-2026-11-25/functional-drill.log), [credential consistency](../../evidence/checkin5/functional-restore-2026-11-25/credential-consistency.txt), [historical inventory](../../evidence/checkin5/functional-restore-2026-11-25/historical-latest.csv), [new-reading result](../../evidence/checkin5/functional-restore-2026-11-25/new-reading-result.txt) and [cleanup verification](../../evidence/checkin5/functional-restore-2026-11-25/functional-cleanup-verification-2026-11-25.log).

**Follow-up required:** reconcile the production `.env` and Mosquitto password-file generation/backup process, then repeat without credential realignment. Investigate the historical-data gap against the source server before claiming recovery of readings through 24 November 22:00 local time.

## Full fresh-VM application restore protocol — remaining work

**Restore operator (role TBD):**  
**Start UTC:**  
**End UTC:**  
**Measured duration:**  
**Restic snapshot ID / timestamp:**  
**Repository (redacted identifier only):**  
**Source backup log:**  
**Fresh VM OS / Docker / Compose versions:**  
**Project commit and image digests:**  

## Preconditions

- [ ] Fresh isolated VM; no production data worth preserving.
- [ ] External repository accessible and credentials recovered through the approved secret process.
- [ ] Project configuration and required secrets available outside Git.
- [ ] `backup/restore.sh` first run without `--apply` to inspect the snapshot.
- [ ] Snapshot contains InfluxDB, Grafana and configuration data.

## Commands and timeline

| UTC | Action / command (no secrets) | Exit status | Notes |
| --- | --- | --- | --- |
| | Snapshot extraction | | |
| | `--apply --yes` started | | |
| | InfluxDB ready | | |
| | InfluxDB restore finished | | |
| | Grafana restore finished | | |
| | Compose stack started | | |
| | Validation finished | | |

## Data inventory (before / after)

Right after the source backup, record a fixed window and keep both CSV files with this log:

```bash
python3 tests/restore/inventory.py snapshot --stop <backup-time-UTC> > tests/restore/results/inventory-source.csv   # source server
python3 tests/restore/inventory.py snapshot --stop <backup-time-UTC> > tests/restore/results/inventory-restored.csv # restored VM
python3 tests/restore/inventory.py compare tests/restore/results/inventory-source.csv tests/restore/results/inventory-restored.csv
```

| Item | Value |
| --- | --- |
| Window (`--start` .. `--stop`) | |
| Sensors identical (from `compare`) | __ of 6 |
| Cities present after restore | |

## Acceptance checks

| Check | Expected | Observed / evidence | Pass? |
| --- | --- | --- | --- |
| Container health | All required services healthy/running | | |
| Historical InfluxDB points | Both cities present through backup timestamp | | |
| Grafana | Login works; datasource, dashboard and two alert definitions present | | |
| Access control | No new public binding; VPN-only access restored | | |
| New ingestion | One new valid test reading appears after restore | | |
| Backup schedule | Timer/configuration reviewed; next backup can run | | |

## Data-loss and recovery assessment

- Last successful source backup time:
- Newest historical reading restored:
- Observed data-loss window:
- Measured restore duration:
- RPO/RTO statement based only on these observations:

## Errors, manual intervention and follow-up

Record every error and manual fix; a restore requiring undocumented intervention is not a clean pass.

**Final result:** PASS / FAIL / PARTIAL  
**Evidence links:**  
**Retest required / date:**
