# Project D — delay analysis

- Generated UTC: `20261125T201100Z`
- Window: `2026-11-25T20:00:07.0582495Z` to `2026-11-25T20:06:24Z`
- Scenario: **recovery** (separate normal and recovery runs)
- Metric: Telegraf processing time minus payload timestamp; not pure network latency
- p95 method: nearest-rank; negative values retained as clock diagnostics

| Scope | City / sensor | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| city | Szczecin | 39 | 46426.010 | -65.921 | 175534.164 | -90.103 | 175537.040 | 20 |
| sensor | SZCZ-AIR-01 | 13 | 46570.508 | 2717.058 | 175537.040 | -86.462 | 175537.040 | 6 |
| sensor | SZCZ-HUM-01 | 13 | 46355.112 | -65.921 | 175534.164 | -88.685 | 175534.164 | 7 |
| sensor | SZCZ-TEMP-01 | 13 | 46352.409 | -66.207 | 175529.238 | -90.103 | 175529.238 | 7 |

Attach chrony offsets, simulator restart times and the exact query window to this report.
