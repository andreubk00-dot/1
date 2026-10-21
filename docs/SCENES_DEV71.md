# dev71 — six new world scenes

The world had five encounter scenes (camp, failed evacuation, repair crew,
looted convoy, feeding site); on a big map the third looted convoy makes the
world feel stamped. dev71 adds six, most of them asking for a decision rather
than handing over a loot pile. Built only from what the game already has:
props and vehicles, containers, infected kinds, raider squads, the story
dialog, the chronicle and the «ЭФИР» state.

| scene | where | what happens |
|---|---|---|
| **ВЫЖИВШИЙ В МАШИНЕ** | town, villages; risk 2–3 | someone is shut in a car with three infected round it. Clear them, then: let them go (a small gift, the nearest settlement hears of it), take their bag (more, and the settlement hears that too), or walk on |
| **ЗАСАДА** | town, industry, forest roads; risk 2–4 | a full crate stands in the middle of the road. Fresh cigarette ends nearby are the warning; open it and a raider squad rises from cover. Once per place |
| **БРОШЕННЫЙ БЛОКПОСТ** | forest roads, industry, military; risk 3–5 | booth, barrier, sandbags, a crate; a former soldier among the infected. The field radio still works: once, it names the nearest site you have not found and marks it |
| **АПТЕЧНЫЙ ФУРГОН** | town, villages; risk 2–4 | a crashed «буханка» full of medicine — guarded by a carrier: kill it close and you breathe its cloud |
| **ЖИВОЙ ЛАГЕРЬ** | villages, woods; risk 1–3 | two strangers at a fire: neutral raiders who talk, trade rumours and leave you be — unless you raise a gun. If they die, the camp stays empty |
| **КОСТРИЩЕ** | town, villages; risk 2–4 | where the waiting ended: a burn pit, body bags, and a radio that still plays the air — the old evacuation loop, the new voice, or hiss, as «ЭФИР» stands. A screamer at higher risk |

## Placement — nothing that exists moves
- The five old scenes keep their exact roll (`EncounterCatalog.event_for`
  is untouched; the «ЭФИР» column depends on it).
- New scenes roll only in sectors where no old scene stands, with their own
  hash (`SceneCatalog.scene_for`), never at a site, a settlement, the start
  ring (two sectors round the start) or a sector carrying an «ЭФИР» note.
- A save from before dev71 remembers which sectors were already visited or
  looted (`scene_legacy_chunks`, taken once on the first load); those keep
  their layout. New games have no such sectors.
- A scene does not push out the sector's water pump, trees or street art —
  those already step round a scene's footprint.

## State
`world_scenes` in the save: `{"x,y": state}` - e.g. `freed`, `robbed`,
`sprung`, `radio_used`, `camp_dead`. Infected and containers use the existing
keys (killed stays killed, looted stays looted).
