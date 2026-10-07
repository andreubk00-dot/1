# OSTATOK 1.31.0-dev1 — Long Session Baseline

QA-only performance/stability slice. Gameplay code is intentionally unchanged.

## Runtime results — Godot 4.7.2

- chunk churn: 96 transitions, 201/201 checks, active chunks never above 9;
- live node count returns exactly to baseline after the tour;
- roof records return exactly to baseline;
- average `_refresh_chunks()` time: 41.6 ms, max: 334.7 ms in the QA container;
- entity cleanup: 24 repeated finite-encounter load/unload cycles, 170/170 checks;
- production save stress: 160 base objects, 240 containers, 1681 discovered chunks, 320 drops, 1600 defeated IDs, 20 rewrites;
- stress save size: 251539 bytes, max write time 45.5 ms;
- multi-route economy: 29419/29419 over 365 days;
- High Risk farming: 440/440 over 180 days;
- personal contracts: 31/31 over 180 days;
- regional endgame/post-ending: 42/42.

No leak/performance defect requiring a gameplay change was confirmed in dev1.
