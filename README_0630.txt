OSTATOK 0.63.0 — COMBAT CHARACTER PASS

Main change:
- continued the ready-made character integration by turning the free SmallScaleInt survivor into a fuller combat presentation pass instead of a plain replacement
- firearms now use weapon-class-specific stance sets: different idle sheets and different stationary firing sheets for PM / shotgun / AKM
- moving gunfire now switches into directional attack locomotion clips (RunAttack / RunBackwardsAttack / StrafeLeftAttack / StrafeRightAttack)
- restored visible weapon-class differentiation on the character by bringing back the weapon overlay on top of the ready-made survivor sprite
- weapon overlay depth now changes relative to the body: in aim-up it drops behind the survivor, in side/down aiming it stays in front

What stayed the same:
- melee keeps using the previous fallback path
- survival systems, HUD, crafting, tasks, AI and save logic were not changed

QA:
- Godot 4.7.2 import: OK
- runtime selftest: OK
- QA captures: player, clinic, inventory, workbench
