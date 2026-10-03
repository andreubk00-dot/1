# OSTATOK 1.22.0-dev5 — Faction Relations

This mechanics pass is built directly on the user-provided `1.22.0 DEV4 SETTLEMENTS DETAIL` base.
No settlement art, building sprites, roads, cars, props or other visual assets are modified.

## Implemented

- Persistent inter-faction relation state, separate from player reputation.
- Relation tiers: hostility / tension / neutral / cooperation / alliance.
- Persistent relation history and faction decisions inside `faction_state` save data.
- Four authored strategic contracts forming two mutually exclusive disputes:
  - Перрон vs Артель «Механики»: priority for the railway freight branch.
  - Рубеж vs Лазарет: hard quarantine cordon vs medical corridor.
- Both sides can be visible before commitment; accepting one blocks the opposing contract while active.
- Abandoning before completion leaves the dispute unresolved, allowing the player to reconsider.
- Completing one side permanently resolves the dispute, removes the opposing offer and records the world decision.
- Conflict completion applies explicit, visible consequences:
  - normal reward for the supported faction;
  - controlled reputation loss with the opposed faction;
  - settlement resource redistribution;
  - persistent relation change between the two factions.
- Contract detail UI warns about the opposing faction and reputation consequence before acceptance.
- Shared multi-faction supply routes now scale modestly with current relations, connecting diplomacy to the existing settlement economy.
- Completing a disputed contract refreshes traders for every faction whose state changed.

## Save compatibility

Old 1.22 faction saves load with neutral inter-faction relations and empty decision history. The existing save schema remains 122.

## QA

- `tests/test_faction_relations_122.gd`
- existing faction, trading, contracts, save/load and settlement tests remain applicable.

Target engine: Godot 4.7.2 Stable.
