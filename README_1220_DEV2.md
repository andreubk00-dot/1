# OSTATOK 1.22.0-dev2 — Trading Economy

This development build continues from 1.22-dev1 Faction Foundation. The high-risk visual redesign remains intentionally deferred.

## Implemented in dev2

- Eight named physical traders, two in each major settlement.
- Shared currency: `currency_tickets` / «расчётные талоны».
- Finite trader stock and finite trader ticket reserves.
- Buy/sell pricing driven by faction specialization, settlement supply and market saturation.
- Reputation-gated assortment: access to valuable goods is the primary reputation reward.
- Barter with ticket top-up or change where the trader can cover it.
- Timed restocking tied to settlement resource condition.
- Goods sold by the player feed faction settlement resources.
- Market saturation reduces repeated-sale value and recovers over time.
- Trader state persists through the existing save system (`save_version` 122).
- 16 named faction NPC placements across the four 3×3 settlements; 8 are active traders in dev2.
- Safe settlement cells spawn no ambient infected and no free authored settlement containers/ground loot, preventing economy bypasses.
- Daily faction economy and restocking are wired into actual world-day rollover (including dev time advance).
- New trader UI uses the existing visual language; no high-risk global visual redesign.

## Market identity

- **Перрон** — food, water, household supplies and general survival goods.
- **Рубеж** — ammunition, weapons, armor and garrison supply.
- **Артель «Механики»** — parts, tools, technical and expedition equipment.
- **Лазарет** — medicine and field treatment supplies.

## QA

Primary automated checks:

- `tests/test_factions_122.gd`
- `tests/test_trading_economy_122.gd`
- `tests/test_trader_ui_runtime_122.gd`

The build is intended for Godot 4.7.2 Stable.
