# Project D — delay analysis

- Generated UTC: `20261125T201100Z`
- Window: `2026-11-25T19:51:52Z` to `2026-11-25T20:00:07.0582495Z`
- Scenario: **normal** (separate normal and recovery runs)
- Metric: Telegraf processing time minus payload timestamp; not pure network latency
- p95 method: nearest-rank; negative values retained as clock diagnostics

| Scope | City / sensor | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| city | Szczecin | 51 | -35.721 | -61.872 | 358.501 | -85.537 | 591.929 | 48 |
| sensor | SZCZ-AIR-01 | 17 | -40.899 | -61.872 | 358.501 | -80.950 | 358.501 | 16 |
| sensor | SZCZ-HUM-01 | 17 | -38.562 | -61.843 | 398.066 | -82.899 | 398.066 | 16 |
| sensor | SZCZ-TEMP-01 | 17 | -27.700 | -63.001 | 591.929 | -85.537 | 591.929 | 16 |

Attach chrony offsets, simulator restart times and the exact query window to this report.
