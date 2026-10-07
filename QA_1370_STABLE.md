# QA — OSTATOK 1.37.0 Final Release

Final Stable promotion from `1.36.0-dev1` Release Candidate. No gameplay/content/art rebalance is included.

## Pre-promotion regression
- clean Godot 4.7.2 import: 651 `.ctex`, exit 0;
- supported full playthrough: **196/196**;
- current-schema save matrix: **42/42**;
- save schema remains **122**.

## RC evidence retained
The accepted RC already passed strained/unsupported full playthrough, migration/recovery/malformed save matrices, trading, High Risk visual closure and captures, long-session, geometry, audio, feature-lock and named-NPC gates. These are not mechanically changed by the Stable promotion.

## Post-promotion gates
- current High Risk multifloor/version gate: **130/130**;
- feature-lock release surface: **7/7**;
- main SELFTEST: `OSTATOK 1.37.0 SELFTEST: OK`;
- `QA_SELFTEST_EXIT: failures=0`;
- named NPC state: **105/105**, canonical roster size 16;
- named NPC production save/load: **8/8**, roster size preserved at 16;
- 651 PNG source files byte-identical to accepted RC;
- package invariants and SHA-256 recorded at packaging.
