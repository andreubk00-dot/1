# QA — OSTATOK 1.32.0-dev1 Save Compatibility Matrix

Engine: Godot 4.7.2 stable (`ed1daf0bf`).
Save schema: **122**.

## Runtime matrix before version bump

- Release Candidate save migration 1.22-dev9: **15/15**
- Save recovery: **18/18**
- Save migration boundaries 1.32: **42/42**
- Save malformed matrix 1.32: **39/39**
- Expedition save integration: **54/54**
- Current schema composite matrix 1.32: **42/42**
- Contract save runtime: **10/10**
- Supply event save runtime: **8/8**
- Strategic projects save runtime: **23/23**
- High Risk mechanics save runtime: **17/17**
- Regional consequence production save: **9/9**

Total focused save/recovery assertions: **277/277**.

The composite test performs two production save/load cycles and verifies that valid modern state is not duplicated or silently rewritten.

## Expected cleanup noise

Some short SceneTree save tests report ObjectDB/resource cleanup warnings after forced immediate exit. Their exit code is 0 and their functional assertions pass; these are test-runner shutdown warnings, not save corruption.

## Final release gates

To be filled after the 1.32.0-dev1 version bump:
- current High Risk visual/version gate;
- main selftest;
- schema/art/release boundary;
- unzip and SHA-256.

## Final 1.32.0-dev1 gates

- current High Risk visual/version gate: **130/130**
- main selftest marker: `OSTATOK 1.32.0-dev1 SELFTEST: OK`
- outer selftest runner hit its timeout only after the OK marker; no Godot process remained and no parse/runtime errors were present
- PNG assets: **651/651 byte-identical** to 1.31-dev2
- gameplay GDScript changes vs 1.31-dev2: **0**
- save schema: **122**
- generated import-only `.uid` files removed before packaging
- external `.tmp/.bak` junk: **0**
