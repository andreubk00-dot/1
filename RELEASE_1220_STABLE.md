# OSTATOK 1.22.0 Stable — Release Record

## Release scope

Faction Economy / Living Settlements. Stable promotes the accepted `1.22.0-dev9` release candidate without adding another large gameplay system or changing the visual pass.

## Stable gates

- project version: `1.22.0`;
- Godot: **4.7.2 stable official `ed1daf0bf`**;
- runtime SELFTEST: **OK**;
- standard regression: **72/72 scripts**;
- checks: **19 047**;
- failures: **0**;
- Stable release gate: **23/23**;
- save schema: **122**, unchanged;
- developer tools disabled by release guard because Stable has no `-dev` suffix;
- source visual assets: **644**, SHA-256-identical to the unpacked dev9 RC;
- no project/runtime ERROR lines in import, smoke, or regression logs.

## 1.22 gameplay systems fixed for Stable

- four factions and settlement identities;
- tickets, reputation, finite trader stocks and restock;
- settlement resources and daily economy;
- persistent contracts and world routes;
- faction-to-faction relations and irreversible world decisions;
- random static supply incidents with world-map markers and real settlement consequences;
- settlement crisis stages affecting prices, restock, contract priorities and availability;
- faction endgame chains with permanent economic/diplomatic effects;
- long-run emergency self-supply floor that prevents hard-locking while preserving shortages;
- transaction validation and buy/sell anti-inflation rules;
- production save/load and old faction-state migration.

## Deferred / known QA boundary

`tests/test_infected_navigation.gd` remains a separate legacy long-running navigation soak and is not counted in the standard Stable batch. The 1.22 faction/economy stabilization did not modify navigation code.

## Visual freeze

No PNG/JPG/JPEG/WebP/SVG source asset was changed while promoting dev9 to Stable. This preserves the user-approved DEV4 visual base used by dev5–dev9.
