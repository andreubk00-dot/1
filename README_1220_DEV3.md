# OSTATOK 1.22.0-dev3 — Contracts / World Influence

This development build continues from 1.22-dev2 Trading Economy. The high-risk visual redesign remains intentionally deferred.

## Implemented in dev3

- Four physical contract givers, one in each major faction settlement:
  - «Перрон» — Вера Андреевна;
  - «Рубеж» — Ирина, диспетчер патрулей;
  - Артель «Механики» — Гена, электрик;
  - «Лазарет» — Доктор Миронова.
- Authored faction contract catalog with three contract lines per faction.
- Contract offers are prioritized by the settlement's current resource shortage.
- Reputation-gated advanced contracts (Known / Reliable tiers).
- Delivery contracts with alternative solutions rather than one exact fetch path.
- Discovery-first reconnaissance contracts: the player receives a verbal location hint, not an exact quest marker.
- Persistent active contracts, offer rotation, completion/abandon history and save/load support inside `faction_state`.
- Rewards combine calculation tickets, faction reputation and settlement resource recovery.
- Route contracts permanently open named supply routes in `world_routes`.
- Open supply routes provide small ongoing daily logistics bonuses to their beneficiary settlements.
- Completing a contract immediately refreshes the relevant faction's trader supply against the improved settlement state.
- Contract UI follows the existing restrained interface language; no global/high-risk visual redesign.

## Design rules retained

- Contracts originate from faction activity and settlement needs rather than generic "kill 10" tasks.
- One active contract per faction keeps the system readable and prevents contract stacking.
- Abandoning a contract has no hidden reputation penalty.
- Reconnaissance tasks use discovery-first navigation and existing POIs.
- World effects are persistent and flow back into the economy rather than ending at a "Quest Complete" banner.

## QA

Primary automated checks added/expanded:

- `tests/test_contracts_122.gd`
- `tests/test_contract_ui_runtime_122.gd`
- `tests/test_faction_settlement_runtime_122.gd`
- existing faction/trading/save/world regressions

Target engine: Godot 4.7.2 Stable.
