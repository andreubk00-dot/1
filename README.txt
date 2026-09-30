ОСТАТОК 1.21.0 — INFECTED VARIETY & ENCOUNTER BALANCE / STABLE

Этап 1.21 фиксирует Крикуна, Плевуна и Носителя как редкие качественные high-risk роли и
закрывает общий баланс encounter pressure. Новые архетипы на этом этапе заморожены.
Визуальная переработка high-risk объектов отложена на будущий visual/world pass.

Save schema = 105. Developer tools F10 автоматически отключены в Stable без `-dev`.

Подробности: README_1210.md, RELEASE_1210_STABLE.md, QA_1210/ENGINE_QA_STABLE.md, ROADMAP_RELEASE_RU.md.

--- СТАБИЛЬНАЯ БАЗА 1.20.0 ---

ОСТАТОК 1.20.0 — HIGH-RISK LOCATIONS II / ENDGAME DUNGEONS / STABLE

Этап 1.20 зафиксирован после принятия dev5 и отдельного Stable-regression на Godot 4.7.2.

Подтверждено:
- SELFTEST: OK;
- 48/48 regression-suite;
- 8635 checks;
- 0 failures;
- 0 Godot ERROR / 0 Godot WARNING во внешних suites;
- save_version = 105;
- Clinical Complex №4 + Underground Object «Vector» интегрированы;
- независимый target farming core: 12 / 14 игровых дней;
- Discovery-first сохранён;
- developer tools F10 автоматически отключены в Stable без `-dev`.

Подробности: README_1200.md, RELEASE_1200_STABLE.md, ROADMAP_RELEASE_RU.md, QA_1200/ENGINE_QA_STABLE.md.

--- ПРЕДЫДУЩАЯ СТАБИЛЬНАЯ ВЕРСИЯ ---

OSTATOK 1.17.1 — STABILITY AUDIT
Полный отчёт: AUDIT_1171_RU.md. Базовая проверка: QA_1171.
save_version = 98.

--- ИСТОРИЯ ПРЕДЫДУЩИХ ВЕРСИЙ ---

ОСТАТОК 1.07.0 — ПОЛЕВАЯ КАРТА
Актуальное описание и управление: README_1070.md. Кадры и проверки: QA_107.

ОСТАТОК 1.06.0 — INFECTED NAVIGATION
Актуальное описание: README_1060.md. Кадры и проверки: QA_106.

ОСТАТОК 1.05.0 — WORLD STABILITY
Актуальные изменения: README_1050.md. Аудит и следующие этапы: QA_105/AUDIT_AND_NEXT_STEPS.md.
Ниже сохранена история прежних версий.

ОСТАТОК 0.61.0 — REFERENCE INTERFACE PASS / GODOT 4.7.2

- HUD остаётся видимым под инвентарём и верстаком;
- инвентарь/экипировка/контейнер переведены в компактную нижнюю компоновку;
- верстак интегрирован с инвентарём вместо отдельного полноэкранного модального окна;
- панели унифицированы с индустриальным HUD и стали слегка прозрачными;
- добавлен --qa-workbench; gameplay/save/item-instance логика не менялась.

ОСТАТОК 0.51.0 — ITEM INSTANCE FOUNDATION / GODOT 4.7.2

ЧТО ИЗМЕНЕНО
- нестакуемые предметы в инвентаре, контейнерах и dropped-item persistence получают уникальный instance_id вида itm_00000001;
- старые сохранения автоматически мигрируются: отсутствующие и дублирующиеся instance_id назначаются при загрузке;
- next_item_instance_id сохраняется вместе с миром (save_version 71);
- перенос уникальных предметов между рюкзаком и контейнером сохраняет identity;
- drag-and-drop сохраняет identity;
- сортировка инвентаря больше не уничтожает identity нестакуемых предметов;
- выброшенный уникальный предмет сохраняет instance_id в мире и получает тот же ID после обратного подбора;
- stackable ресурсы (патроны, бинты, материалы и т.п.) остаются агрегированными стаками и instance_id не получают;
- main.tscn больше не содержит встроенную полумегабайтную копию GDScript: сцена ссылается на res://main_script_mod.gd как на единственный активный source;
- добавлены self-tests уникальности и сохранения item identity.

ЗАЧЕМ ЭТО НУЖНО
Это первый совместимый слой для следующего этапа: перенос состояния оружия, магазинов, модулей и экипировки с глобального weapon_id на конкретный instance_id. Текущая боевая модель и старые сохранения пока остаются совместимыми.

ПРОВЕРКИ 0.51.0
- Godot 4.7.2 clean import без .godot cache: exit 0 / ERROR 0 / WARNING 0;
- normal headless runtime: SELFTEST OK / ERROR 0 / WARNING 0;
- QA inventory/clinic/player/infected/facade/exterior: все exit 0 / ERROR 0 / WARNING 0;
- отдельный runtime regression: sort -> drop -> pickup -> save -> reload сохраняет instance_id;
- synthetic migration save_version 70 без instance_id: новые ID создаются автоматически;
- config/name намеренно оставлен прежним, чтобы не менять Godot user:// directory и не прятать существующие сохранения пользователя.

ОСТАТОК 0.50.2 — NATIVE ARCHITECTURE + DEPTH / GODOT 4.7.2

ОСТАТОК 0.49.0 — GRAPHICS OVERHAUL PASS 1 / ПРОВЕРЕНО В GODOT 4.7.2

Капитальный первый проход по новой графике на основе утверждённого арт-направления.
Это уже не концепт: новые ассеты встроены непосредственно в игровой проект и реально используются движком.

ЧТО ПЕРЕРАБОТАНО

ПЕРСОНАЖ
- новый детализированный full-body pixel-art атлас;
- 65-рядная совместимая схема анимаций сохранена;
- ходьба/активное движение собраны из новых кадров;
- старый дополнительный leg-overlay отключён, чтобы не конфликтовать с новым телом;
- пропорции персонажа увеличены и приблизились к референсу;
- оружие перепозиционировано под новые плечи/руки, чтобы не проходить через лицо.

ОРУЖИЕ
- новые модели ПМ, помпового дробовика и АКМ;
- новые модели ножа, трубы/монтировки и пожарного топора;
- новые модели используются в руках, quickbar и карточке оружия;
- обновлены инвентарные версии melee-оружия;
- сохранены существующие боевые механики, отдача, перезарядка и модули.

ИНВЕНТАРЬ И ИКОНКИ
- новый inventory atlas для ключевых предметов;
- переработаны вода, еда, бинты, антибиотики, патроны, фонарь, рюкзак, броня, оружие и часть модулей;
- quickbar и inventory grid используют тот же новый визуальный язык;
- добавлен отдельный атлас новых статусных HUD-иконок.

ОКРУЖАЮЩИЙ МИР
- новый ground pass: старая логическая разметка дорог сохранена, сверху добавлена новая грязь/трещины/микротекстура;
- новые тайлы интерьеров;
- новый world props atlas;
- обновлены больничные кровати, ширмы, стойки, кресла, шкафы, стеллажи, генераторы, костёр, дождесборник, автомобили и другие пропсы;
- процедурные деревья заменены на детализированные sprite-based деревья;
- старые примитивные заборы заменены повторяемыми pixel-art секциями;
- освещение клиники/интерьеров усилено тёплым светом для читаемости новой детализации.

ЗАРАЖЁННЫЕ
- новый 4-вариантный infected atlas в общей палитре и масштабе новой графики;
- AI, коллизии и поведение заражённых не менялись.

QA-РЕЖИМЫ
- --qa-inventory: запуск с открытым инвентарём для проверки новых иконок;
- --qa-clinic: телепорт в клинику для проверки интерьерных пропсов;
- --qa-player: тестовая сцена для проверки персонажа и held-weapon art.
Эти режимы не влияют на обычную игру.

ПРОВЕРКИ
- Godot 4.7.2 asset import: OK;
- OSTATOK 0.50.2 NATIVE ARCHITECTURE DEPTH SELFTEST: OK;
- 600 кадров, текущий профиль: exit 0 / ERROR 0 / WARNING 0;
- 600 кадров, чистый профиль: exit 0 / ERROR 0 / WARNING 0;
- visual Xvfb/OpenGL runtime: OK;
- inventory QA runtime: OK;
- clinic QA runtime: OK;
- player visual QA runtime: OK;
- размеры всех новых атласов проверены;
- анимационный atlas проверен: кадры движения реально различаются;
- weapon/melee rows проверены на уникальность;
- embedded source в main.tscn полностью совпадает с main_script_mod.gd.

СОВМЕСТИМОСТЬ
- survival state, инвентарь, крафт, AI, лут и существующие сохранения не меняются;
- изменён в первую очередь presentation/art layer;
- архитектура старых атласов сохранена там, где это важно для совместимости игрового кода.

ДАЛЬШЕ ПО ГРАФИЧЕСКОМУ ПЛАНУ
Следующие passes должны продолжить тот же арт-уровень: дополнительные анимационные состояния персонажа, отдельные wounded/wet/cold variants, более разнообразные заражённые, больше уникальных уличных/интерьерных props, кровавые/грязевые декали и более глубокая интеграция освещения.


0.49.2: добавлены детализированные текстуры внутренних стен и пола, четыре визуальных варианта заражённых, исправлена потеря варианта заражённого при переключении кадров анимации, а runtime-smoke test заражённого теперь реально получает созданный enemy node.


0.49.2 NATIVE ART INTEGRATION:
- интерьерные стены получили реальные текстурные панели из нового art sheet;
- фасады используют текстурные окна и дверь вместо условных прямоугольников;
- крыши получили textured surface и HVAC/pipe/ladder props;
- заражённые получили 4 независимых визуальных варианта x 4 animation frames;
- исправлен bug: animation frame больше не затирает внешний вид variant заражённого;
- исправлен _spawn_enemy(): теперь возвращает enemy node, поэтому runtime AI/graphics smoke tests реально выполняются;
- interaction prompt поднят выше и больше не перекрывает модель персонажа;
- добавлены floor grime/crack decals и QA launch modes для фасада/заражённых.


0.50.0 INTERIOR REBUILD:
- пересобрана композиция интерьеров по зонам вместо плотного случайного набора пропсов;
- увеличена showcase-клиника, сохранены контейнеры/двери и старые механики;
- исправлен системный баг масштаба персонажа: visual-root больше не сбрасывается с 0.55 до 1.0 каждый кадр;
- directional legs перенесены под общий visual-root и наследуют масштаб тела;
- камера скорректирована под новую плотность сцены;
- создан новый world_props_v15 с перерисованными медицинскими/рабочими пропсами;
- создан floor_detail_v3 и отдельный interior_floor_tiles_v1 с бесшовными 32x32 игровыми тайлами;
- пол интерьера больше не растягивается одним 128x128 спрайтом на всю комнату;
- крупные интерьерные предметы получили собственные игровые footprint/коллизии, центральные проходы остаются свободными;
- добавлены QA-тесты плотности интерьера, центрального прохода, тайлинга пола и сохранения масштаба персонажа.


0.50.1 ARCHITECTURE INTEGRATION:
- added dedicated floor/wall trim atlas and doorway threshold;
- clinic enlarged to 300x216 with a preserved center aisle;
- clinic prop plan reduced/reorganized into treatment, circulation and dispensing zones;
- floor zoning reduced so props and traversal stay visually readable.

0.52.1 VISUAL COHESION PASS
- active runtime art no longer depends on pasted/cropped reference fragments; the new high-impact assets in this pass are original procedural pixel art built specifically for OSTATOK;
- references supplied by the project owner were used only for art direction: muted post-Soviet palette, dirty institutional materials, dense but readable props, warm practical light against cool ambient light;
- rebuilt active player full-body pose atlases (480x3900) with a stronger silhouette, helmet, beard/face breakup, vest, backpack, knee pads, boots, straps and layered arms while preserving the existing 6-column x 65-row animation contract;
- rebuilt infected_v9 as four distinct 32x48 variants with readable clothes, asymmetric wounds, damaged faces, pockets and gait-frame differences; AI/collision are unchanged;
- rebuilt weapon_models_v18 with new Makarov/shotgun/AK-pattern pixel models inside the existing 144x48 row layout;
- clinic received a denser but still walkable composition: monitor, tray, extinguisher, mop bucket, additional rubble/papers, medical cabinetry, wall wiring, ceiling pipes and practical lamps;
- facades received grime, exposed utilities, electrical boxes, wires/posters, pharmacy marking and subtle warm practical lighting without changing door/collision geometry;
- exterior ground received concrete sidewalk bands, curb wear, drains, manholes, faded markings, cracks, patched asphalt, leaf litter and edge weeds;
- car_v3 was redrawn as a more top-down, damaged vehicle with cabin glazing, wheels, rust and broken glass; fence_segment_v2 was rebuilt as a bent/rusted chain-link segment;
- roof rendering uses a native 64x64 repeatable tile instead of stretching a small texture over an entire building;
- nearest filtering and quantized sprite scaling remain in use; player scale is now 0.75 for improved readability at the 640x360 internal resolution;
- daylight was lifted slightly so pixel detail survives the final canvas modulation; night remains dark and local lamps retain warm contrast.

ART / LICENSING
- no third-party art assets were added in 0.52.1;
- no pixels were copied from the supplied reference images;
- all newly generated/repainted graphics in this pass are original project assets generated by the included tools/visual_pass2.py, visual_pass3.py and visual_pass4.py scripts;
- therefore this pass introduces no new external attribution or license dependency.

0.58.0 CHARACTER MOTION POLISH
- cohesive player atlas upgraded to v6 with tapered sleeves, smaller hands, compact proportions and denser gear/face detail;
- player visual root raised to 1.06 for readability;
- walk speed increased from 53 to 64 px/s; sprint is now 64 x 1.32 = 84.48 px/s;
- infected chase speed raised to 60 px/s to preserve pressure;
- gait cycle distances retuned to 54/62 px so faster movement does not create foot skating;
- added planted-step bob, lateral weight transfer, visual acceleration lag, strafe body roll and aim-direction hysteresis;
- all art remains original project art; references are direction only, not source material.

