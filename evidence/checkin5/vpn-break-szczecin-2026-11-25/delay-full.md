# Project D — delay analysis

- Generated UTC: `20261125T201100Z`
- Window: `2026-11-25T19:51:52Z` to `2026-11-25T20:06:24Z`
- Scenario: **interruption** (separate normal and recovery runs)
- Metric: Telegraf processing time minus payload timestamp; not pure network latency
- p95 method: nearest-rank; negative values retained as clock diagnostics

| Scope | City / sensor | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| city | Szczecin | 90 | 20097.696 | -62.436 | 145522.229 | -90.103 | 175537.040 | 68 |
| sensor | SZCZ-AIR-01 | 30 | 20157.377 | -61.360 | 145525.046 | -86.462 | 175537.040 | 22 |
| sensor | SZCZ-HUM-01 | 30 | 20065.363 | -63.776 | 145522.229 | -88.685 | 175534.164 | 23 |
| sensor | SZCZ-TEMP-01 | 30 | 20070.347 | -64.371 | 145517.250 | -90.103 | 175529.238 | 23 |

Attach chrony offsets, simulator restart times and the exact query window to this report.
