# QA — OSTATOK 1.23.0-dev14 Sandbox Route Identity

## Среда

- Godot Engine **4.7.2.stable.official.ed1daf0bf**.
- Dev13 release ZIP использован как baseline; dev14 построен поверх чисто распакованной копии.
- Save/integration tests запускаются в изолированных user-data каталогах, когда этого требует тест.

## Route identity

### System

`test_sandbox_route_identity_123.gd`: **54 checks, 0 failures**.

Проверено:

- четыре starter-recon указывают на правильные POI;
- риски: Заря **2**, больница **3**, полиция **3**, депо **4**;
- профили: `rural_secure`, `medical_secure`, `police_secure`, `industrial_secure`;
- интервалы: **4/5/6/7 дней**;
- в каждом starter-POI ровно один renewable authored reserve;
- постоянные route-effects продолжают поддерживать профильный ресурс соответствующей фракции;
- `rural_secure` содержит гражданские припасы и не протекает в ballistic/SKS-style loot;
- больница сохраняет medical identity, полиция security identity, депо technical identity;
- old dev13 container сохраняет существующее содержимое при присоединении target-farm metadata;
- уже пустой legacy reserve не получает бесплатный refill;
- Заря действительно восстанавливается через 4 дня, депо через 7, но не раньше.

### Runtime / board UX

`test_sandbox_route_identity_runtime_123.gd`: **13/13**.

Проверено, что все четыре общие доски показывают authored risk и сохраняют контраст `[ПОСТАВКА]` / `[РАЗВЕДКА • РИСК N]`.

### Contract layout regression found and fixed

Реальный OpenGL-capture выявил старый дефект: контрактная панель была выше internal viewport (404 px при высоте 360), поэтому action buttons уходили ниже экрана.

Исправлена только компоновка. `test_contract_ui_layout_123.gd`: **9/9** проверяет:

- панель целиком внутри viewport;
- status-area не перекрывает action buttons;
- accept/close buttons не выходят за panel bounds;
- длинное выбранное описание Механиков помещается в status-area.

После layout fix:

- contract UI — **18/18**;
- personal contract UI — **23/23**;
- strategic projects runtime — **75/75**;
- dev14 runtime — **13/13**.

## Регрессии механики

- sandbox routes regression: **80/80**;
- target farming/world layout: **1338/1338**;
- loot rarity/risk: **834/834**;
- field map: **24/24**;
- world content POI: **267/267**;
- arsenal regression: **414/414** and **303/303**;
- equipment: **86/86**;
- trading economy: **512/512**;
- settlement layout: **674/674**;
- world events/encounters: **1819/1819**;
- High Risk integration: **170/170**;
- High Risk visual/multifloor: **130/130**;
- strategic projects production save: **23/23**;
- release save migration: **15/15**.

Historical release gates remain untouched:

- RC balance: **7890 mechanics checks pass**; the only formal failure is the intentional requirement that a Stable build be exactly `1.22.0 Stable`.
- Endgame historical gate follows the same policy and is not rewritten to make dev14 pretend to be Stable.

## Visual QA

OpenGL 4.5 / Mesa llvmpipe under Xvfb:

- `dev14_perron_risk2.png`;
- `dev14_lazaret_risk3.png`;
- `dev14_rubezh_risk3.png`;
- `dev14_mechanics_risk4.png`;
- `dev14_mechanics_selected.png` after compact layout fix.

The selected Mechanics capture now shows description, condition, progress, reward and all action buttons inside the 1280×720 output (640×360 logical viewport). No clipping/overlap remains.

ALSA is unavailable in the container; Godot falls back to dummy audio. Rendering/game logic are unaffected.

## Asset integrity

Every source image in dev13 release ZIP was compared with the dev14 working tree by relative path and SHA-256:

- dev13 images: **651**;
- dev14 images: **651**;
- changed: **0**;
- added: **0**;
- removed: **0**.

## Release invariants

- Version: `1.23.0-dev14` in `project.godot`, `BUILD_VERSION.txt`, `BRANCH.txt`.
- Production save schema stays **122**.
- No global escape objective.
- No new graphics.
- Existing save structures are reused.

## Финальный clean-import / post-import gate

Перед упаковкой `.godot` полностью удалён. Первый штатный `Godot --import` был остановлен только внешним 180-секундным лимитом на ~96% без parse/resource/script errors; повторный `--import` продолжил тот же кэш и завершился с **Godot exit code 0**. Финальный import cache содержит **1342 imported resources**. В итоговом import log нет `ERROR`, `SCRIPT ERROR`, `Parse Error` или `Failed loading resource`.

На свежем импортном кэше повторно прошли:

- route identity — **54/54**;
- route identity runtime — **13/13**;
- contract layout — **9/9**;
- sandbox routes regression — **80/80 + runtime 9/9**;
- contract UI — **18/18**;
- personal contract UI — **23/23**;
- strategic projects runtime — **75/75**;
- field map — **24/24**;
- target farming/world layout — **1338/1338**;
- loot rarity/risk — **834/834**;
- High Risk visual/multifloor — **130/130**;
- direct `main.tscn` boot — `OSTATOK 1.23.0-dev14 SELFTEST: OK`.

После gate импортный кэш удаляется из release ZIP.
