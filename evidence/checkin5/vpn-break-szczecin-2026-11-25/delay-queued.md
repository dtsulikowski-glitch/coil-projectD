# Project D — delay analysis

- Generated UTC: `20261125T201100Z`
- Window: `2026-11-25T20:00:07.0582495Z` to `2026-11-25T20:03:07.3575189Z`
- Scenario: **interruption** (separate normal and recovery runs)
- Metric: Telegraf processing time minus payload timestamp; not pure network latency
- p95 method: nearest-rank; negative values retained as clock diagnostics

| Scope | City / sensor | Count | Mean ms | Median ms | p95 ms | Min ms | Max ms | Negative |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| city | Szczecin | 18 | 100522.038 | 100523.722 | 175537.040 | 25511.332 | 175537.040 | 0 |
| sensor | SZCZ-AIR-01 | 6 | 100525.318 | 100527.135 | 175537.040 | 25518.278 | 175537.040 | 0 |
| sensor | SZCZ-HUM-01 | 6 | 100522.836 | 100524.756 | 175534.164 | 25516.704 | 175534.164 | 0 |
| sensor | SZCZ-TEMP-01 | 6 | 100517.961 | 100520.312 | 175529.238 | 25511.332 | 175529.238 | 0 |

Attach chrony offsets, simulator restart times and the exact query window to this report.
