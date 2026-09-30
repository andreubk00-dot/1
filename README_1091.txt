OSTATOK 1.09.1 — Arsenal Test Crate

QA hotfix for the existing showcase garage crate.

- Normal gameplay containers remain 8x8.
- The existing "ТЕСТ: ВСЕ ПРЕДМЕТЫ" crate is now 14x8 (112 cells).
- It physically fits the full current 41-item catalogue, including all six firearms and their ammunition.
- Existing saves containing the old truncated test crate are expanded/repacked when the showcase chunk is spawned.
- Custom crate dimensions persist through production disk save/load.
- Added --qa-test-crate for visual QA of the real showcase crate.

Validation on development source:
- Arsenal Expansion: 326 checks, 0 failures
- Expedition Save Integration: 41 checks, 0 failures
- HOME SUPPLIES: 42 checks, 0 failures
- WORLD PERSISTENCE: 16 checks, 0 failures
- WORLD SURVIVAL POLISH: 110 checks, 0 failures
- Runtime SELFTEST: OK

save_version remains 97. Normal loot tables and normal container capacity are unchanged.
