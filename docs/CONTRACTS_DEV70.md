# dev70 — new contract kinds

Until now the boards offered three kinds: deliver (20), scout a site (16) and
clear the raiders' base (1). After a few hours every errand read the same.
dev70 adds three kinds built only from systems that already exist. Each one
asks for a different way of playing; none hands out a new mechanic.

| kind | in play | what it asks of the player |
|---|---|---|
| **retrieve** — «ДОБЫТЬ» | a sealed parcel waits in a named cache at a known site | go to a dangerous place, find one thing, carry it home (weight, ambush on the way) |
| **hunt** — «ВЫСЛЕДИТЬ» | one named, tougher special infected haunts a site | pick the fight: prepare for a brute, a screamer, a spitter |
| **raiders** — «ОТРЯД» | a hostile raider squad works a road near a site | fight, outflank, or make them run; surrender counts |

A fourth, **defend** («ОБОРОНА» — hold a settlement through a night assault),
needs infected to path through settlement walls; it is designed separately
after these three are played.

## Rules shared by all three
- The target is a **named site** (POI). The hint names it in words, as scouting
  contracts do; once the site is on the map, so is the target. No new markers.
- What waits there exists **only while the contract is active** and only until
  it is done: the parcel is not in the cache before, the hunted infected does
  not respawn after death, the squad does not come back once broken.
- Progress lives in `faction_state.contract_field` (saved with the world):
  `{contract_id: {"done": bool}}`. `ContractSystem.can_complete` reads
  `done:<contract_id>` from the known-facts map, as `clear_poi` reads
  `cleared:<poi>`.
- **Retrieve**: done is carrying the parcel; handing in removes it. If the
  survivor dies, the parcel lies in his body like any item.
- **Hunt**: the named infected has ×2.2 health and a name in the prompt; its
  kill marks the contract done and is told in the feedback line.
- **Raiders**: done when every member is dead, surrendered or fleeing. A squad
  that walks off unbroken is set down again the next time the survivor nears
  the site.

## Who asks what (faction character)
- **Лазарет** — medical parcel from the hospital; the spitter at the hospital.
- **Перрон** — a family's parcel from the dachas; raiders on the Zarya road.
- **Рубеж** — the police station's safe; the screamer at the garages; raiders
  at the police station.
- **Артель** — the depot's tool crate; the armoured one at Factory №7.

Rewards sit between a delivery and a scouting contract of the same risk;
hunts and raider contracts carry security, retrieval carries the faction's
own need.
