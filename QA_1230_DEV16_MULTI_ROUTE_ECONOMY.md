# QA — OSTATOK 1.23.0-dev16 Multi-Route Economy

## Baseline / invariants

- Source baseline: `OSTATOK_1.23.0-dev15_Sandbox_Route_Consequences.zip`.
- Baseline SHA-256: `f70f80a77a6f4c3c4e15f28457071716990fdb69c096b1e85f23a4480176a4f5` — verified before editing.
- Baseline ZIP: `unzip -t` OK.
- Target engine: Godot **4.7.2 stable**.
- Production save schema: **122**, unchanged.
- Expected historical version-gate failure remains `1.22.0 Stable`; it is not rewritten for dev16.

## Dev15 saturation proof before balancing

The reference calculation reproduces the real `FactionEconomy.daily_tick()` order and authored values from dev15: faction resource biases, daily consumption, route `daily_resources`, relation factors, faction endgame effects, completed project effects, clamp `0..100`, and emergency self-supply below `35`. No dev16 cap is applied in this baseline run.

### Days at absolute resource cap in a 365-day passive wait

| Scenario | Perron | Rubezh | Mechanics | Lazaret |
| --- | --- | --- | --- | --- |
| 4 starter routes | security **274** | security **108** | 0 | 0 |
| routes + projects | security **274** | security **280** | technical **273** | medicine **116** |
| routes + endgame | security **284** | security **316** | technical **324** | medicine **316** |
| routes + projects + endgame | security **284** | security **330** | technical **337** | medicine **335** |
| full + authored final endgame routes | security **284** | security **342** | technical **348**, security **190** | medicine **348** |

This establishes the balancing problem before changing values: different route restock multipliers are not multiplying one another, but multiple daily passive resource sources can permanently erase top-end scarcity.

## Dev16 rule

`FactionEconomy.PASSIVE_LOGISTICS_SOFT_CEILING = 92.0` applies only to the aggregate positive daily delta produced by:

- open routes;
- active faction endgame effects;
- completed settlement projects.

The post-consumption resource value is captured as baseline. If direct gameplay previously left the resource above `92`, dev16 preserves that value and only prevents passive logistics from refilling that day's consumption. Emergency self-supply runs after the passive cap.

### Reference 365-day result with dev16 rule

All five passive configurations above produce **0 days at 100** for every faction/resource. In the strongest real-completion scenario (starter routes + projects + endgame effects + authored final routes), the year-end resources are approximately:

| Faction | food | medicine | technical | security |
| --- | ---: | ---: | ---: | ---: |
| Perron | 61.5 | 32.9 | 57.7 | **92.0** |
| Rubezh | 24.7 | 29.9 | 78.9 | **92.0** |
| Mechanics | 25.0 | 29.9 | **92.0** | **92.0** |
| Lazaret | 28.1 | **92.0** | 31.6 | 33.5 |

Deficit pressure therefore still exists after a year of waiting, while authored specializations remain visibly stronger than at least one non-profile reserve.

## Requested horizons

`test_multi_route_economy_soak_123.gd` records resources plus profile trader stock/buy/sell price snapshots at **30 / 60 / 180 / 365 days** for:

1. four starter routes only;
2. routes + settlement projects;
3. routes + faction endgame effects;
4. routes + projects + endgame;
5. the same mature state including all four final endgame routes and their real relation outcomes.

It then separately runs the supply-failure/crisis and active-buying cases.

## Recovery isolation guards

The soak has deterministic checks proving the new passive rule cannot absorb emergency gameplay recovery:

- an explicit severity-3 supply event expires and lowers Mechanics technical resource;
- the next explicit severity-3 supply event succeeds and restores its full direct gain outside the passive cap;
- a real `crisis_mechanics_technical` contract is offered/accepted/completed and restores exactly **+18 technical** outside the passive cap.

## Market / trading coverage

The Godot soak uses real `TradingMarket.restock_all()`, `stock()`, `buy_price()`, `sell_price()`, `buy_quote()` and `apply_purchase()` calls. It tracks:

- profile stock peak and zero-stock days;
- price min/max;
- resource impact of buying profile goods;
- finite stock under 365 days of waiting;
- finite stock under daily active buying.

The authored multipliers remain unchanged: dev15 route `×1.10/×1.12`, project `×1.06`, existing endgame `×1.20/×1.25`.

## Offline source-faithful market reference

Before runtime certification, the same authored values were replayed independently from source using the actual daily consumption, route/project/endgame multipliers and trader restock cadence. In the strongest completed-sandbox state (starter routes + projects + all endgame effects + final routes):

- passive waiting profile stock remains finite: Perron grain peak **26**, Rubezh `ammo_9x18` **64**, Mechanics scrap **41**, Lazaret bandage **27**;
- 365 days of buying two profile units per faction per day completes **2920 purchases** without infinite stock generation; end stocks are approximately **7 / 60 / 39 / 25**;
- the active-buying resource sinks remain visible: Perron food ~**32.4**, Rubezh security ~**91.8**, Mechanics technical ~**91.7**, Lazaret medicine ~**91.6** at year end;
- representative buy prices remain bounded at authored integer pricing rather than collapsing from saturation.

This reference is a source-level cross-check, not a substitute for the Godot runtime suite.

## Save / migration coverage

`test_multi_route_economy_save_runtime_123.gd` uses production save/load and requires isolated `XDG_DATA_HOME` / `OSTATOK_QA_SAVE_ROOT`.

Expected invariants:

- `save_version == 122`;
- a dev15-style saved resource at `100` remains `100` immediately after load — no eager migration rewrite;
- existing open route persists;
- no missing `opening_stock_applied` marker is fabricated;
- the next daily rollover applies dev16 anti-saturation behavior.

## Static change-boundary audit

Current dev15 → dev16 project diff changes only:

- version/branch metadata;
- `main_script_mod.gd` version/title strings;
- High Risk visual test's expected build version;
- `world/faction_economy.gd` aggregate passive guardrail;
- four new dev16 QA tests;
- this README/QA documentation.

No High Risk mechanics file, target-farm implementation, strategic-item implementation, named-NPC catalog, trading implementation, route definitions, project definitions, endgame definitions or graphics are modified.

## Protected-system static verification

Short independent checks against the verified dev15 tree confirm identical SHA-256 content for:

- `world/high_risk_mechanics.gd`;
- `world/settlement_projects.gd`;
- `world/contract_catalog.gd`;
- `world/trading_market.gd`;
- `world/supply_event_system.gd`;
- `world/settlement_crisis.gd`;
- `world/faction_endgame.gd`;
- `world/save_store.gd`;
- `world/poi_catalog.gd`.

Additional invariants: High Risk incident IDs still originate at **5000+**; floor-2 clear still gates the emergency override; target farming remains `loot_refresh_sites`; production writer still emits `save_version: 122`; settlement-project constants remain reserve floor **45**, contribution batch **12**, min reputation **75**; the settlement NPC placement roster is exactly **16 unique IDs, four per faction**. No `.godot` cache, temporary or backup files are included in the dev16 tree.

## Asset integrity

Compared by relative PNG path and SHA-256 against dev15:

- dev15 PNG: **651**;
- dev16 PNG: **651**;
- changed: **0**;
- added: **0**;
- removed: **0**.

## Runtime certification status

The current execution environment does not contain a Godot binary. The official 4.7.2 Linux x86_64 release and SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` were independently identified, but this sandbox cannot currently materialize that external binary. Therefore **do not record new Godot test counts as passed until the 4.7.2 executable is available and the scripts are actually run**.

Required final runtime gate:

- `test_multi_route_economy_123.gd`;
- `test_multi_route_economy_runtime_123.gd`;
- `test_multi_route_economy_save_runtime_123.gd` with isolated save root;
- `test_multi_route_economy_soak_123.gd`;
- dev15 route consequence regression;
- trading/supply/crisis/named-NPC/relations/chronicle/rest/world-events/projects/High-Risk/save-recovery regressions;
- clean Godot 4.7.2 import;
- direct `main.tscn` selftest;
- release ZIP `unzip -t` and SHA-256.
