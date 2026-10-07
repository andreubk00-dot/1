# QA — 1.35.0-dev1 Balance Lock

Godot: 4.7.2 stable official `ed1daf0bf`.

## Balance evidence
- historical release-candidate balance: 7891 checks / 1 expected fail (`project version must be 1.22.0 Stable`);
- trading economy: 512/512;
- Regional Endgame soak: 42/42 (`supported=cohesive`, `idle/selective=holding_network`);
- multi-route economy system: 23/23;
- multi-route economy 365-day soak: 29419/29419;
- High Risk farming soak: 440/440, 57 cycles over 30/60/180 days;
- combat & gear balance: 96/96.

Informational historical encounter-balance suite: 82 checks / 1 fail, where the only failure is its
old `application/config/version == 1.22.0` gate. Its 81 mechanical checks pass. The gate is intentionally
left unchanged.

## Lock decision
No reproducible out-of-bounds balance defect was found, so damage, armor, survival, weight, drop rates,
cooldowns, infected tuning, trading values, Crisis pressure, passive logistics cap, High Risk access/reward
and farming rules were not changed.

## Import boundary
Fresh full Godot import completed with exit 0 and produced 651 imported PNG `.ctex` files.

## Release invariants
- save schema: 122;
- historical 1.22.0 Stable gates: unchanged;
- current High Risk version gate: 1.35.0-dev1;
- no new gameplay systems;
- no graphics changed.

## Current gates
- High Risk current-version suite: 130/130;
- main.tscn: `OSTATOK 1.35.0-dev1 SELFTEST: OK`;
- `QA_SELFTEST_EXIT: failures=0`.

Package integrity and SHA are recorded after packaging.
