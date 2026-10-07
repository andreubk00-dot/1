# OSTATOK 1.32.0-dev1 — Save Compatibility Matrix

Финальный save compatibility/recovery pass перед Feature Lock.

## Что проверяется

- historical migration boundaries 0.81/0.82, 0.83/0.84, 0.84/0.85 и weapon-instance 0.98/0.99;
- legacy 1.22-dev9 migration;
- `.bak` recovery после повреждённого primary save;
- malformed top-level и nested subsystem state;
- sparse current schema 122 без новых полей;
- expedition / equipment / firearm-instance roundtrip;
- combined current-schema roundtrip: world routes, settlement project, faction endgame, chronicle/story_seen, named NPC status, regional endgame outcome, High Risk state, discovery;
- отдельные production save/load проверки contracts, supply events, settlement projects, High Risk и regional consequence ending.

## Важные границы

- `save_version` остаётся **122**;
- новых top-level persistent blobs нет;
- transient animation/audio state не сохраняется;
- sparse старый save не получает бесплатные проекты, faction endgame или regional endgame;
- malformed nested state восстанавливается sanitizers, а повреждённый primary save использует валидный `.bak`;
- historical version gate `1.22.0 Stable` не переписывался.

Игровая механика в dev1 не меняется: это QA/recovery closure.
