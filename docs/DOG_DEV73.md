# dev73 — the dog

The region is lonely by design. A dog is the one companion it offers: found,
not given; it senses, it does not fight; it costs food and water; it can be
lost. It adds decisions and a bond, not a cheat.

## Finding it
- **ПЁС НА ЦЕПИ** - a dog chained by a kennel at the edge of town: one yard in
  each sixth of the compass, in rural and residential sectors three to six
  sectors out, never in a sector a scene, a site or an «ЭФИР» note owns (five
  yards on the current map; the north-east is industry and the army). It is
  thin and wary and growls at a stranger.
- To take it: **feed it** (one tin, a ration or a hot meal) and it is untied.
  One dog at a time - the others stay on their chains; a yard that gave its
  dog stays empty.
- Each dog has a name chosen by where it was found (Найда, Шарик, Альма, Джек,
  Граф, Пират).

## What it does
- **Follows** the survivor along the way he actually walked (a trail of his
  steps), so it finds doors and corners; it keeps a few steps behind.
- **Wait / come** - a rebindable key (G by default) or E on the dog: it sits
  where it is and stays quiet; the map marks where it waits with a paw. A call
  carries about 640 px; called, it comes back along the survivor's own steps
  (it keeps them while it waits). Out of sight and far behind, it catches up.
- **Senses** - infected the survivor cannot see (off screen, in fog, in the
  dark, behind walls) within about 380 px: the dog turns to them, stiffens
  and growls low. Nothing is marked on screen; you learn to read it.
- **Barks** when infected come close and in sight, now and then - and a bark
  is a noise the infected hear. While the survivor sneaks it keeps quiet
  unless they are almost on it.
- **Does not fight.** An infected that reaches it bites it; it yelps and
  falls back behind the survivor.

## What it costs
- **Food** (lasts about two days) and **water** (about a day; it drinks when
  you drink at a pump, and from the rain). E on the dog feeds or waters it
  (rain water first); at heel it only asks - the E prompt - when it really
  needs it (below 40), so the prompt does not hang over it all day.
- Hungry or thirsty, it weakens and its nose dulls.
- **Health 60.** Hurt below half, it limps; a bandage heals it (E). At zero it
  dies - for good; the chronicle remembers it.
- If the survivor dies, the dog stays where he fell; the next survivor is a
  stranger to it and must feed it to be trusted.

## Built from
- Art: `tools/dog3d.py` on the same small 3D rig renderer as the survivor
  and the infected (8 directions; trot, run, idle, sit, alert, lie).
- Voice: real recordings, CC0 (OpenGameArt; authors in `audio/CREDITS_CC0.md`),
  cut and levelled by `tools/import_dog_audio.py`.
- Code: `world/dog.gd` (the animal), `world/dog_catalog.gd` (the yards, names,
  needs), the yard in `main_script_mod.gd` (`_build_dog_yard`), save key
  `dog`. Test: `tests/test_dog_dev73.gd`.
