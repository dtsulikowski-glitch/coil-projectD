# Project D — delay analysis

- Generated UTC: `20261125T201100Z`
- Window: `2026-11-25T20:03:07.3575189Z` to `2026-11-25T20:06:24Z`
- Scenario: **normal** (separate normal and recovery runs)
- Metric: Telegraf processing time minus payload timestamp; not pure network latency
- p95 method: nearest-rank; negative values retained as clock diagnostics

| Scope | City / sensor | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| city | Szczecin | 21 | 57.985 | -71.085 | -65.921 | -90.103 | 2717.058 | 20 |
| sensor | SZCZ-AIR-01 | 7 | 323.528 | -70.862 | 2717.058 | -86.462 | 2717.058 | 6 |
| sensor | SZCZ-HUM-01 | 7 | -74.365 | -71.085 | -65.921 | -88.685 | -65.921 | 7 |
| sensor | SZCZ-TEMP-01 | 7 | -75.207 | -71.362 | -66.207 | -90.103 | -66.207 | 7 |

Attach chrony offsets, simulator restart times and the exact query window to this report.
