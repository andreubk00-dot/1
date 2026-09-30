OSTATOK 0.53.0 — ANIMATION / VISUAL POLISH

Changes from 0.52.1:
- Rebuilt active player full-body atlas while preserving the 80x60 frame contract.
- 12-frame distance-driven walking is now visually readable: stronger planted stride, knee/boot separation, torso/shoulder counter-motion and restrained body bob.
- Sprint has stronger locomotion amplitude and weapon/shoulder follow-through while keeping the same gameplay movement.
- Fixed a rendering bug where the legacy directional-legs layer was re-enabled under the full-body atlas, causing doubled boots / stray leg pixels.
- Rebuilt infected silhouettes and changed runtime playback to use the complete four-frame gait.
- Kept collisions, inventory data, world generation and save compatibility unchanged.
- Runtime art remains original project pixel art; user reference images are used only as art direction and are not embedded in the game.

Release hygiene:
- .godot cache intentionally excluded.
- stale *.png.import files intentionally excluded. Godot 4.7.2 regenerates them on first import, preventing broken references to another machine's .godot/imported cache.

Validated with Godot 4.7.2 stable.
