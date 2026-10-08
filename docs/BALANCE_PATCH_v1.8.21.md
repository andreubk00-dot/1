# Balance v1.8.21 — experimental build (2026-10-08)

## Scope
Based on public v1.8.20. Isolated branch `endless-defenders-balance-v1821`; unchanged persistent save schema (21).

1. **Wave HP curve:** waves 1–30 unchanged. Waves 31–60 use 1.032/wave; waves 61+ use 1.022/wave rather than 1.115/wave indefinitely. Boss variants and first-run modifiers remain intact.
2. **Full-simulation speed:** PC RMB ×3, HUD ×0.5/×1/×2/×3/×4 apply to whole combat tick (projectiles, tower reloads, player cooldowns, boss mechanics, movement, spawn, status effects). Up to 33ms substeps reduce skipped collisions. Pause still freezes updates. Module selection timing accounts for speed.
3. **Late-run resources:** from completed wave 31 onward, shards awarded for the run receive an additional 1.2% per cleared wave over 30, capped at ×1.90. Other earners (daily, achievement, contracts, purchases, login) are untouched. Prices unchanged.
4. **Long runs:** after all nine unique anomaly relics have been selected, every fifth wave offers repeatable *weaker* upgrades: +8% damage, +6% rate, or +12% wave-clear energy; reroll is disabled for these three-choice screens; invalid off-screen relic choices are rejected.

## Expected HP checkpoints
| Wave | New boss HP |
|---:|---:|
| 10 | 667 |
| 20 | 2,784 |
| 30 | 11,049 |
| 40 | 14,567 |
| 50 | 23,573 |
| 60 | 45,619 |
| 80 | 64,406 |
| 100 | 107,303 |
| 120 | 257,466 |

Base scenario, no Rift modifiers or run-wide combat buffs; values computed by calling actual `Game.waveHp` and `Game.bossSpec` methods.

## Verification to date
- All four inline scripts compile syntactically in both builds.
- Six direct model tests passed: first-30-wave identity, monotonic late HP, wave-100 reduction, x3 time scaling, x0.5 time scaling, pause.
- Veteran mechanic tests passed: offering 3 choices after nine, disabling rerolls, rejecting unoffered choice, applying ×1.08 damage exactly once.
- Regression test source: `tests/balance-v1821.test.cjs` (Node).
- Updated phone service-worker cache key `ed-mobile-v1.8.21`.

## Release gate (not yet completed)
Full browser test in desktop Chromium and mobile viewport, true Safari/WebKit testing, long-run automated simulation at 30/40/60/100/120, controller usability, import/export recovery, and explicit user confirmation of balance feel. These checks have not been represented as passed. **Do not deploy this experimental branch over the currently-live 1.8.20 until gates pass.**

## Later design tasks
Measure actual success rates and average playtimes for first boss and each contract; verify resource sinks after stabilizing battle pacing; decide whether to shorten sequential late defender unlocks. No contract prices were modified in this experiment.
