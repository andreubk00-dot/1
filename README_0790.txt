OSTATOK 0.79.0 — EXTERIOR WORLD PASS

Следующий этап общего art-integration плана: фасады, крыши, улица и наружная визуальная связность.

ФАСАДЫ
- новый facade_wall_tiles_v3: 8 нативных 32x28 вариантов штукатурки/бетона с цоколем, трещинами, сервисными следами и разной типологией зданий;
- новый facade_detail_v1: отдельные архитектурные силуэты для аптеки, торговли, промышленных и жилых зданий;
- навесы/козырьки являются частью фасада, а не случайным world clutter;
- сохранены старые collision/doorway размеры.

КРЫШИ
- новый roof_tile_v2 с нативной повторяемой кровельной поверхностью, швами, tar-patch и износом;
- новый roof_props_v3: HVAC, вентиляция, сервисный блок, антенна;
- усилена глубина парапета/дренажного края без изменения footprint.

УЛИЦА
- ground_chunk_v11 сохраняет прежнюю геометрию дорог/тротуаров, но добавляет изношенные бордюры, выцветшую разметку, ремонты асфальта и выбоины;
- street_detail_v1: лужи/масло, pothole, выцветшая дорожная разметка, drain grate, asphalt patch и мелкий мусор;
- street decals добавляются по zone-aware правилам и всегда лежат ниже персонажей/лута.

PIPELINE
- tools/exterior_art.py — воспроизводимая генерация наружного art;
- tools/build_art.py теперь пересобирает interior + exterior вместе с персонажами и infected.

QA
- Godot 4.7.2 import;
- SELFTEST;
- facade day/night; exterior day/night; clinic/player/infected/inventory/workbench regression.
