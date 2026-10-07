# OSTATOK 1.23.0-dev6 — QA / Regression Report

Дата: 2026-10-04  
Движок: Godot 4.7.2 Stable (предоставленный пользователем)  
Save schema: 122

## Результат

Dev6 закрывает этап **стратегических предметов и больших resource sinks** без добавления новой графики и без смены save schema. Глобальная цель «путь наружу», проекты финального выхода и финальная операция не реализуются.

Финальная кодовая база импортируется и запускается на Godot 4.7.2; `main.tscn` сообщает `OSTATOK 1.23.0-dev6 SELFTEST: OK`.

## Новая функциональность

- 4 одноразовых стратегических предмета, по одному на каждый High Risk объект.
- Отдельная trade-категория `strategic`; ни один существующий торговец такие предметы не принимает.
- Guaranteed injection в authored `cache_3` глубинного сектора без участия обычного loot RNG.
- Persistent `strategic_spawned`, исключающий дублирование через reload и target-farm cycles.
- Controlled migration старых пустых core-кешей без их внезапного переролла.
- 4 локальных инфраструктурных проекта поселений на общей контрактной доске.
- Репутационный порог 75.
- Bulk contribution из абстрактного faction stock, до 12 resource points за операцию.
- Protected warehouse floor 45, исключающий списание аварийного остатка.
- Одноразовая completion reputation, небольшие daily resource bonuses и профильный restock ×1.06.
- Радио/хроника фиксирует передачу узла и завершение проекта.
- Procedural schematic icon для strategic items в механической no-visual ветке.

## Найденные и исправленные проблемы во время dev6

### 1. QA all-items container перестал вмещать каталог

После появления четырёх новых предметов встроенный SELFTEST обнаружил, что developer-ящик `all_items_test` размером 20×8 больше не может физически упаковать весь каталог.

Исправление: только QA-фикстура расширена до 20×10. Обычные контейнеры не менялись. Старые тесты, жёстко проверявшие размер QA-ящика, обновлены на новую фикстуру.

### 2. Старый пустой High Risk cache получал новый предмет при миграции

Первая реализация dev6 добавляла стратегический предмет прямо в `cache_3` при следующем build чанка. Это нарушало существующий инвариант: пустой core cache из старого сейва не должен внезапно становиться непустым.

Исправление:

- dev5-style empty cache остаётся пустым;
- штатный cooldown сохраняется;
- стратегический предмет вводится только после первого законного reoccupation/refill;
- последующие reoccupation cycles его больше не восстанавливают.

`High Risk II integration` после исправления: **170/170**.

### 3. Старый anti-farm soak не различал dev6 first-run и dev5 migration

Исторический soak создавал «уже завершённый первый проход» вручную, но не мог знать о новом persistent `strategic_spawned`. В результате одноразовый migration-item трактовался как renewable top-tier loot.

QA-фикстура разделена корректно:

- completed dev6 first-run заранее отмечает одноразовый источник как уже существовавший;
- отдельный dev5 migration test подтверждает, что отсутствующий strategic item появляется один раз на первом reoccupation и **не появляется на втором**.

Итог anti-farm soak: **440/440**, 57 циклов.


### 4. Project-status UI перекрывал нижние кнопки

Первый runtime layout-check показал, что длинный служебный текст стратегического проекта увеличивал фактическую высоту `Label` с 96 до **193 px**, из-за чего статус заходил под нижний ряд действий.

Исправлено без изменения общей геометрии панели: прогресс ресурсов оставлен в существующем списке, status-copy сокращён, только в project-mode используется компактный шрифт 6, а при возврате к контрактам восстанавливается шрифт 7. Финальная геометрия: status 96 px, calculated minimum 69 px, 6/6 строк видимы; нижние кнопки остаются ниже области статуса. Новый runtime-тест отдельно проверяет отсутствие vertical clipping и overlap до и после завершения проекта.

## Новые тесты dev6

| Тест | Результат |
|---|---:|
| Strategic projects systems | 153 / 153 |
| Strategic cache + runtime/UI + migration | 75 / 75 |
| Strategic production save/load | 23 / 23 |
| Strategic projects 180-day soak | 178 / 178 |
| High Risk farming soak с dev6 invariant | 440 / 440 |

Проверено дополнительно:

- все 4 strategic items уникально сопоставлены High Risk объектам;
- реальные authored cache keys/profile имеют физическое место для guaranteed item;
- предмет нельзя продать ни одному из существующих trader IDs;
- completion reward не дублируется;
- completed sink не продолжает списывать stock;
- sanitization не принимает forged `completed` без выполненных требований;
- daily effects остаются в диапазоне 0..100;
- emergency self-supply не может сам финансировать незавершённый проект;
- schema-122 load без `settlement_projects` создаёт безопасное пустое состояние.

## High Risk regression

| Подсистема | Результат |
|---|---:|
| High Risk mechanics | 92 / 92 |
| High Risk locations | 373 / 373 |
| High Risk II integration | 170 / 170 |
| High Risk visual/multifloor | 130 / 130 |
| High Risk farming 30/60/180 | 440 / 440 |
| Target farming / world layout | 1324 / 1324 |
| Clinical complex endgame | 368 / 368 |
| Vector endgame | 435 / 435 |

## Основные механические регрессии

| Подсистема | Результат |
|---|---:|
| Trading economy | 512 / 512 |
| World events / encounters | 1819 / 1819 |
| Faction settlement runtime | 169 / 169 |
| Settlement layout | 674 / 674 |
| General contract UI runtime | 18 / 18 |
| Personal contracts | 123 / 123 |
| Personal contract UI runtime | 23 / 23 |
| Named NPC state | 105 / 105 |
| Named NPC runtime | 14 / 14 |
| Supply events | 35 / 35 |
| Supply event runtime | 15 / 15 |
| Faction relations | 65 / 65 |
| Factions | 244 / 244 |
| Settlement crisis | 31 / 31 |
| Settlement crisis UI | 8 / 8 |
| World chronicle | 14 / 14 |
| Rest / midnight rollover | 38 / 38 |
| Arsenal expansion / all-items regression | 414 / 414 |
| Equipment/item expansion / all-items regression | 86 / 86 |

## Production save/load в изолированных XDG-каталогах

| Подсистема | Результат |
|---|---:|
| Strategic projects dev6 | 23 / 23 |
| High Risk dev5/dev6 compatibility | 17 / 17 |
| Personal contracts | 17 / 17 |
| Named NPC state | 8 / 8 |
| World chronicle | 7 / 7 |
| General contracts | 10 / 10 |
| Faction relations | 9 / 9 |
| Faction endgame | 9 / 9 |
| Supply events | 8 / 8 |
| Schema migration | 15 / 15 |
| Save recovery | 18 / 18 |
| Expedition save | 54 / 54 |

## 180-day RC balance

`test_release_candidate_balance_122.gd` выполняет **7891** проверку: **7890 механических проверок проходят**, один формальный fail остаётся историческим release-gate, который требует буквальную версию `1.22.0 Stable`.

Gate намеренно не переписан: dev6 не должна иметь возможность выдать себя за Stable только ради зелёного отчёта.

## Графическая регрессия

Побайтовое сравнение source assets dev5 → dev6:

- dev5: 651;
- dev6: 651;
- changed: 0;
- added: 0;
- removed: 0.

High Risk visual/multifloor runtime: **130/130**. Новый этап не меняет PNG/JPG/JPEG/WebP/SVG. Procedural strategic icons генерируются кодом и не являются новым source-art asset.

## Что остаётся дальше

Этап 5 плана механически закрыт. Следующий пункт плана — **глобальная цель игры**, но сам план прямо требует отдельного утверждения концепции до её внедрения. Поэтому dev6 не создаёт коридор наружу, проекты выхода, финальную операцию или каноническую концовку.

До такого утверждения безопасный следующий шаг — вертикальный срез/баланс и дополнительная полировка уже существующего цикла либо отдельное решение пользователя по глобальной цели.
