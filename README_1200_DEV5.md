# OSTATOK 1.20.0-dev5 — High-Risk Locations II / Operation 5 Integration Candidate

`1.20.0-dev5` завершает пятую операцию этапа 1.20 как **интеграционный кандидат**, но ещё не
объявляется Stable автоматически. База — проверенный `1.20.0-dev4-hotfix1`; import-safe startup
guard и dev-only F10 tools сохранены.

## Что интегрировано

Обе tier-2 endgame-локации теперь работают в общей системе мира:

- **Областной клинический комплекс №4** — открытый медицинский кампус, risk 5, runner-heavy
  pressure, `clinical_core` как хирургический/медицинский резерв.
- **Подземный объект «Вектор»** — тесный технический узел, risk 5, brute-heavy pressure,
  `vector_core` как ремонт/автономность/экспедиционное снабжение.

Для обоих объектов сохраняется `hard_requirements = []`: первое прохождение не требует предмета,
который можно получить только внутри того же объекта.

## Target farming / cooldown

Обновляется **только глубокое ядро**, а не весь объект и не промежуточные secure-контейнеры.
Обычный лут по пути остаётся конечным.

- Clinical core: скрытый site-level cooldown **12 игровых дней**.
- Vector core: скрытый site-level cooldown **14 игровых дней**.
- Cooldown запускается только после полной выборки всех target-cache ядра.
- Если игрок положил что-либо обратно в target-cache, запланированное обновление отменяется:
  пользовательское хранилище никогда не перезаписывается.
- После готового refresh восстанавливается не только core loot, но и defeated-state всей локации,
  поэтому повторный рейд снова требует пройти угрозу.
- Состояния двух объектов независимы и сохраняются через существующий `loot_refresh_sites`.

Save schema остаётся **105** — новый формат сохранения не нужен.

## Discovery-first

Карта после обнаружения показывает название и опасность, но не раскрывает:

- `clinical_core` / `vector_core`;
- содержимое внутренних резервов;
- точный cooldown;
- факт target farming;
- «правильный» маршрут к ядру.

Игрок по-прежнему изучает объект сам и может использовать ручные заметки.

## Infected / loot-risk integration

Итоговый pressure 1.20 зафиксирован как отдельный контракт:

- Clinical Complex — 54 заражённых по шести секторам; core остаётся runner-heavy.
- Vector — 58 заражённых; core остаётся brute-heavy.
- Это выше generation-one Quarantine/Bastion, но новые типы заражённых не добавляются раньше 1.21.

Core loot-профили остаются risk 5 и не превращаются во второй арсенал: ни Clinical, ни Vector core
не содержат firearms. Clinical специализируется на лечении/травме, Vector — на ремонте,
фильтрации, освещении и экспедиционной автономности.

## QA

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: OK.
- Full regression: **48/48 suites, 8634 checks, 0 failures**.
- Packaged-staging external regression: **0 Godot ERROR, 0 Godot WARNING** across all 48 suites.
- Operation-5 integration suite: **170/170**.
- Target farming / world layout: **1324/1324**.
- Clinical: **332/332**.
- Vector: **399/399**.
- Developer Mode: **94/94**.
- Spawn safety: **879/879**.

Packaged/import QA завершён:

- полный clean editor-import: **1342 imported files, 0 ERROR, 0 WARNING**;
- packaged headless startup: **SELFTEST OK, 0 ERROR**;
- packaged graphical X11 startup: **SELFTEST OK, 0 ERROR** (только системное V-Sync warning виртуального драйвера);
- cold copy без `.godot`: import guard срабатывает до загрузки мира, **0 ERROR, 0 SELFTEST failures**;
- `.godot/imported` из чистого Godot 4.7.2 import включён в dev5-пакет.

Таким образом прежний дефект упаковки dev4 воспроизведённого типа закрыт. `dev5` остаётся
интеграционным кандидатом до ручного принятия, а не переименовывается в Stable автоматически.
