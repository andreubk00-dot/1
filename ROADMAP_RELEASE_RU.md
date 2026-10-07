# OSTATOK — Release Roadmap (живой документ)

Обновлено для 1.21.0 Stable после финального encounter-balance прохода. План можно корректировать, если реальная разработка
показывает лучшую последовательность, но изменения не должны ломать базовые принципы.

## Постоянные правила до релиза

1. **Каждый новый предмет автоматически входит в `ТЕСТ: ВСЕ ПРЕДМЕТЫ`.** Каталог
   строится из `item_defs`. Если он перестаёт помещаться — расширяется только QA-ящик,
   не обычные контейнеры.
2. **Каждый крупный POI проходит layout QA:** здания, дороги, машины, деревья, декор,
   контейнеры, коллизии и пути заражённых. Формализуемые ошибки получают regression-test.
3. **Сильная вещь должна менять возможности, а не быть очередным `+15%`.** Цена силы:
   вес, шум, патроны, мобильность, обслуживание, редкость или сложность получения.
4. **После 1.33 Feature Lock — никаких крупных новых механик.** Только завершение,
   исправления, QA, баланс и релизная подготовка.
5. **Discovery-first: знания не выдаются готовыми.** UI не раскрывает, где лежит
   конкретный предмет, его spawn chance, loot profile, target-farm cooldown или
   «правильный» маршрут добычи. Игрок учится пробами, ошибками и наблюдением и может
   записывать собственные выводы ручными метками. Игра может показывать факты о
   собственном состоянии и уже обнаруженном месте, но не решает исследование за игрока.

## Фактическое состояние и дальнейшие этапы

### 1.17.0–1.17.2 — Long-Term Gear Progression — **ЗАВЕРШЁН / ENGINE VERIFIED В СОСТАВЕ 1.19**

Уже есть: шесть огнестрельных образцов, melee, броня/шлемы/рюкзаки/погодная одежда,
медицина, rarity, zoned armor, mobility tradeoffs, high-risk POI, target farming,
домашнее снабжение, карта/экспедиции, ручные заметки, индивидуальное состояние оружия.
В 1.17.2 удалена старая XP/skill progression и суммарный readiness score; оставлена
только физическая, предметная и world-driven прогрессия. Discovery-first доведён до
системного правила. Полный regression-набор позднее подтверждён на Godot 4.7.2 в составе стабильной 1.19.

### 1.18.0 — Arsenal Expansion II — **ЗАВЕРШЁН / ENGINE VERIFIED В СОСТАВЕ 1.19**

К исходным шести огнестрельным образцам добавлены четыре роли без клонирования:
ППС-43 (компактный автоматический ПП), ИЖ-81 (помповый дробовик с более собранной
осыпью), АКС-74У (лёгкий автоматический карабин 5.45×39) и винтовка Мосина
(тяжёлая дальнобойная болтовая винтовка 7.62×54R). Добавлены два новых калибра.

Для всех четырёх уже есть отдельные world/inventory/HUD модели, собственные animation
prefix-файлы, посадка в руках, магазин/reload, индивидуальное состояние по instance_id,
внутренние loot sources, rarity/risk, gameplay sound signature для AI hearing и разные
muzzle/tracer FX. QA-каталог автоматически расширился; его единственный контейнер
увеличен с 14×8 до 16×8, обычные контейнеры остались 8×8. Позднее 1.19 расширяет только QA-каталог до 20×8.

В dev2 добавлен настоящий audible weapon layer: отдельный shot WAV для всех 10 стволов,
reload-профили pistol/SMG/rifle/shell/bolt, audio voice pool для автоматического огня и
dry-fire click. Финальный художественный sound pass всё равно остаётся 1.29.

В dev3 quickbar превращён из жёстко прошитых ПМ/дробовик/АКМ + melee в сохраняемый
6-слотовый combat loadout: любой firearm/melee можно назначить прямо из инвентаря клавишами
1–6. Новые стволы 1.18 теперь полностью участвуют в обычном боевом цикле без отдельного UI.
Save schema: 101; старые сейвы получают безопасные default bindings.

В dev4 исправлена скрытая визуальная клонизация: четыре новых ствола получили собственную
in-hands геометрию в survivor baker, перебиты все 84 baked animation sheets и добавлена
автопроверка clone-art/clipping. Combat roles дополнительно зафиксированы regression-тестом
по breakpoints normal/runner/brute, sustained DPS, дальности, разбросу, шуму и весу боеприпасов.

В dev5 ручное оружейное действие перестало быть молчаливым cooldown: базовый помповик и
ИЖ-81 получили отдельный цикл помпы, Мосин — цикл затвора, с `Attack2`-анимацией и отдельными
механическими WAV. Reload не накладывается на незавершённый цикл, а QA-runner умеет снимать
mid-cycle кадры. Engine runner теперь одним запуском проверяет SELFTEST и все 37 suite с корректным exit code. Это закрывает обязательный пункт «рабочие анимации/звук» для ручных систем.

В dev6 исправлен runtime SELFTEST, который в пользовательском запуске показывал
`ОШИБКИ ТЕСТА: 3`: один устаревший count inventory-art и два реальных несоответствия
точного арта footprint (АКС-74У и Мосин). Exact art уменьшен без расширения предметов,
добавлен общий inventory-art fit contract и отдельная 38-я regression-suite. SELFTEST HUD
теперь показывает сами причины ошибок, а не только их количество.

Арсенальный слой подтверждён общим engine-regression стабильной 1.19; дальнейшая художественная
полировка звука и анимаций остаётся в соответствующих поздних этапах roadmap.

### 1.19.0 — Equipment & Survival Gear II — **STABLE / ENGINE VERIFIED**

В dev1 добавлена слоистая экипировка: `body` остаётся бронёй корпуса, а куртки получили
отдельный `outerwear`. Старые сейвы с курткой в body мигрируют автоматически. Добавлены
утеплённая парка (тепло) и штормовое пончо (дождь) с разными mobility tradeoff. Слабая
защита внешней одежды складывается с бронёй через diminishing returns, а не линейно.

В dev2 добавлен **переносимый спальник**: persistent world-object, короткий полевой отдых
в сухую погоду, прерывание открытым дождём и полный сон только под крышей. Спальник можно
свернуть обратно без превращения предмета в материалы.

В dev3 добавлены **многоразовые ёмкости для воды**: полевая фляга 1.0 л и канистра 3.0 л.
Объём хранится per-instance, вода пьётся частично, `R` переливает по 0.5 л, масса зависит
от фактического наполнения, а fill-state переживает контейнеры, drop/pickup и save/load.
Expedition readiness показывает фактический объём питья.

В dev4 добавлен отдельный слой **`rig`** и две разгрузки. Полевая разгрузка даёт один
быстрый карман, штурмовая — два. В открытом инвентаре `7/8` назначают компактные
расходники, а с закрытым инвентарём используют назначенный предмет без открытия рюкзака.
Разгрузка не создаёт дополнительный скрытый инвентарь и не увеличивает carry capacity;
она меняет доступ к вещам. Реально надетая разгрузка также уменьшает время перезарядки,
при этом более эффективная штурмовая версия тяжелее и сильнее влияет на мобильность.
Save schema: 105. QA-каталог расширен только до 20×8; обычные контейнеры остаются 8×8.

В dev5 выполнен **закрывающий интеграционный проход**: исправлен реальный конфликт `R` между
reload и refill reusable-water, введён modal guard для loadout-клавиш 1–8 и синхронизирована
версия SELFTEST. Добавлен combined regression `test_survival_gear_integration.gd`; всего 43 suite.

1.19 зафиксирован после полного engine-QA на официальном Godot 4.7.2: **SELFTEST OK, 43/43 suite,
6773 checks, 0 failures**. Во время runtime-QA исправлены loot-risk, миграция старого QA-каталога,
quickbar/rig assignment guards и action-cycle harness. Следующий этап — 1.20 High-Risk Locations II.

### 1.20.0 — High-Risk Locations II / Endgame Dungeons — **STABLE / ENGINE VERIFIED**

Карантинный центр №12 и арсенал «Бастион» остаются первым поколением данжей.
`1.20.0-dev1` зафиксировал каркас двух объектов второго поколения. `1.20.0-dev2` полностью
реализовал **областной клинический комплекс №4** (`regional_clinical_complex_4`) как открытый
медицинский кампус с runner-heavy давлением и хирургическим `clinical_core` loot identity.

В `1.20.0-dev3` отдельно завершён **подземный объект «Вектор»**
(`underground_object_vector`). Это вертикальный 2×3 технический узел из шести секторов:
шахта доступа/гермошлюз, сектор охраны, энергоблок, командный коридор, сервисный выход и
глубокое инженерное ядро. Пространственный сценарий намеренно противоположен госпиталю:
тесные коридоры и choke-points, нулевой outdoor traffic/tree population, отдельный вход и
сервисный выход. Encounter-профили используют только существующих normal/runner/brute, но
`vector_core` делает давление brute-heavy; новые разновидности заражённых по-прежнему ждут 1.21.

Loot identity «Вектора» — автономность и техническое снабжение: ремонт, фильтрация воды,
освещение, аварийные запасы и экспедиционное снаряжение. Это не второй арсенал: firearms в
`vector_core` не добавлены. `hard_requirements` пуст, поэтому no-self-key сохраняется.
Persistence использует прежние стабильные container/defeated keys и save schema 105.
Target farming для обоих tier-2 объектов намеренно не включён до операции 5.

Финальный QA dev3: **Godot 4.7.2 SELFTEST OK; 46/46 suites; 8295 checks; 0 failures**.
Профильный Vector suite: **399/399**; общий layout: **1250/1250**; spawn safety:
**879/879, 0/439 overlaps**; клинический regression после интеграции Vector: **332/332**.
`HIGH_RISK_DEV_SKELETONS` теперь пуст: обе локации реализованы отдельно.

В `1.20.0-dev4` добавлен **dev-only режим разработчика** для ускорения ручного QA: отдельная
панель `F10`/кнопка `DEV`, неуязвимость, полный no-aggro заражённых и телепорты ко всем
активным основным POI из `RegionCatalog.POIS`. Эти флаги runtime-only и не записываются в
save. Важный release guard: инструменты создаются только если `application/config/version`
содержит `-dev`; после перехода на стабильную версию панель и hotkey автоматически отсутствуют.
Это QA-инфраструктура, а не новая survival-механика, и она не меняет операцию 5.

В `1.20.0-dev5` выполнена **операция 5 — интеграция**. Обе tier-2 локации включены в общую
site-level target-farming систему, но обновляется только глубокое ядро: Clinical — 12 игровых
дней, Vector — 14. Промежуточные secure-контейнеры остаются конечными, пользовательские вещи
никогда не перезаписываются, а готовый refresh восстанавливает defeated-state всей соответствующей
локации. Два cooldown независимы и сохраняются через существующий `loot_refresh_sites`; save schema
остаётся 105.

Discovery-first проверен отдельно: карта показывает обнаруженное место и risk 5/5, но не выдаёт
loot profile, содержимое core, cooldown или маршрут. Итоговый infected pressure зафиксирован как
54 заражённых для Clinical и 58 для Vector с сохранением runner-heavy / brute-heavy различия.
Core loot остаётся risk 5 и не превращает новые объекты в дополнительные арсеналы.

QA dev5: **Godot 4.7.2 SELFTEST OK; 48/48 suites; 8634 checks; 0 failures**. Новый cross-location
integration suite — **170/170**, target farming / layout — **1324/1324**. Packaged QA также завершён:
clean import **1342 files / 0 errors / 0 warnings**, packaged headless и X11 — **SELFTEST OK / 0 ERROR**,
а повторный прогон всех 48 внешних suite на packaged staging — **0 Godot ERROR / 0 Godot WARNING**.
Cold copy без `.godot` корректно останавливается на import guard с **0 ERROR / 0 SELFTEST failures**.
Свежий `.godot/imported` cache Godot 4.7.2 включён в пакет. После ручного принятия dev5 эта же
интеграция зафиксирована как **1.20.0 Stable** без добавления нового gameplay-контента. Stable-версия
не содержит `-dev`, поэтому F10 developer tools автоматически недоступны в обычной игре.

**1.20.0 Stable** зафиксирован из принятого dev5 без изменений gameplay-контента: Godot 4.7.2
SELFTEST OK; **48/48 suites, 8635 checks, 0 failures, 0 Godot ERROR/WARNING**. Save schema остаётся 105.
Stable release guard отдельно проверен: F10 developer tools недоступны без `-dev`.

### 1.21.0 — Infected Variety & Encounter Balance — **STABLE / ЗАФИКСИРОВАНО**

База 1.20 содержала обычного, рывкового и тяжёлого заражённых. `1.21.0-dev1` добавил
**Крикуна** (`screamer`) — хрупкого caller-врага с телеграфированным прерываемым alarm-call, который
поднимает ближайших заражённых через hearing-систему, не выдавая им позицию игрока напрямую.

`1.21.0-dev2` добавил **Плевуна** (`spitter`): слабого в ближнем бою ranged-control врага с ~0.72 с
windup и фиксируемой в начале подготовки точкой попадания. Игрок может уйти с отмеченной точки;
урон/stagger срывают атаку, попадание даёт небольшой урон и короткое снижение мобильности.

`1.21.0-dev3` добавляет третью и **последнюю новую роль до balance pass** — **Носителя** (`carrier`).
Он также слабее обычного заражённого и легче отталкивается/стаггерится. После смерти есть ~0.35 с
предупреждения, затем на ~3.4 с остаётся небольшая заражённая зона вокруг тела. Она даёт низкий
урон, заметно расходует stamina и загрязняет уже открытую кровоточащую рану. Основной counterplay —
добивать Носителя с дистанции либо сначала вытолкнуть его из прохода. Повторный lethal hit не создаёт
дубликаты облака; transient hazard не сохраняется в save.

Все три специальные роли остаются редким authored-контентом только внутренних/core-профилей
high-risk зон: их нет в `standard`, внешних периметрах, Clinical perimeter и Vector access. Clinical
остаётся runner-heavy, Vector — brute-heavy. Общая численность встреч на dev3 не увеличивается —
новые роли заменяют долю прежнего mix.

**Variety на этом заморожена.** После dev3 этап 1.21 перешёл к encounter-balance без добавления
новых архетипов: плотность, комбинации normal/runner/brute/screamer/spitter/carrier, шум,
stopping power, расход патронов и сложность high-risk зон. Этот проход завершён в dev5 и
зафиксирован в Stable 1.21.0.

QA dev3: Godot 4.7.2 SELFTEST OK; **51/51 suites, 8828 checks, 0 failures, 0 Godot ERROR/WARNING**;
Screamer **48/48**, Spitter **71/71**, Carrier **73/73**. Save schema остаётся 105.

`1.21.0-dev4` добавил **функциональный multi-floor foundation** для high-risk объектов. Экспериментальный
visual pass этого dev-этапа **не принят как финальное художественное качество** и по решению разработки заморожен.
Stable 1.21 сохраняет рабочую многоэтажность, но не продолжает визуальную переработку. Полный rebuild внешнего вида
официально перенесён на поздний Visual & World Geometry pass: high-risk объекты должны стать цельными уникальными
комплексами, а не перестановкой повторяющихся модульных коробок.

Все четыре high-risk объекта теперь имеют настоящие игровые вертикальные слои: **1 → 2 → 3 этаж** (для «Вектора» —
последовательные глубинные ярусы). Лестницы являются interactable-переходами между отдельными слоями; на этажах есть
собственная геометрия комнат, проходы, props, контейнеры, encounters и стабильные persistence keys. Сохранение внутри
верхнего/глубинного этажа восстанавливает POI, номер слоя и локальную позицию. Это не декоративный `storeys` фасада.

Площади этажей намеренно крупные: floor 2 примерно **1320–1480 × 880–960**, floor 3 примерно **1200–1340 × 820–880**.
«Бастион» визуально опирается на большой ангар и галереи, Clinical — на госпитальные корпуса, Quarantine — на
изоляционно-лабораторную структуру, Vector — на шахту доступа и инженерные глубинные уровни. Stable container IDs,
loot identity, target farming и save schema 105 не меняются.

В `1.21.0-dev5` выполнен Encounter Balance Pass: новые типы заражённых и крупные POI не добавлялись; отрегулированы
density/role mix, special pressure, stopping power tradeoffs и upper-floor enemy budgets. После отдельного Stable-regression
этап зафиксирован как **1.21.0 Stable: 53/53 suites, 9040 checks, 0 failures, 0 Godot ERROR/WARNING**. Save schema остаётся 105.

### 1.22.0 — NPC / Traders / Factions Foundation + Loot Economy Final Balance — **НЕ НАЧАТ**

NPC вставляются именно здесь, **перед финальной экономикой**, потому что торговцы и
награды заданий сами меняют источники и стоки предметов.

Сначала: первые NPC, торговцы, базовые диалоги, небольшие группы выживших, отношения,
фракции и простые задания без MMO-структуры. Никаких глобальных quest-arrow к добыче:
персонаж может дать естественную информацию в диалоге, но интерфейс не превращается
в каталог точных spawn-точек.

После появления этих источников/стоков финализируются rarity, spawn chances,
профильные источники, target-farming cooldown, ассортимент/цены торговцев и награды.
Цель — редкая экипировка требует усилий, но не 40 одинаковых забегов ради 1%.

### 1.23.0 — Map Structure & Exploration Goals — **ГОТОВО**

Уже есть районы, обнаружение секторов/POI, опасность обнаруженных мест, ручные метки и
экспедиционные цели. Финальный проход идентичности районов/маршрутов завершён в 1.23-dev17–dev18.
Карта не показывает «в этом здании лежит X» и не рисует стрелку к предмету; игрок сам
решает, куда идти.

### 1.24.0 — World Content Final Pass — **ГОТОВО**

Финальный world-content проход завершён в dev1–dev3. Dev1 добавил deterministic cosmetic
вариативность обычных procedural-зданий, dev2 — три cosmetic-варианта пяти конечных
encounter-сцен, dev3 закрыл audit authored minor POI: 25 cells проверены, пять полностью
пустых по локальным props и одна near-bare ячейка получили небольшой non-colliding dressing
без изменения loot/enemy/container/save семантики. Обычный world-content после этого почти
замораживается; дальнейшие добавления должны относиться к narrative/environmental storytelling.

### 1.25.0 — Narrative & Environmental Storytelling — **ГОТОВО**

Dev1 начал отдельный environmental-storytelling слой поверх уже существующих finite
world events: внутри текущей карты размещены редкие уникальные читаемые traces, которые
сохраняются в полевой хронике без квестовых наград, стрелок и новой глобальной цели.
Dev2 добавил по одной уникальной служебной записи в восемь обычных authored compound-POI
(ГСК, комбинат, депо, «Заря», больница, полиция, кордон, КПП), переиспользуя тот же reader
и schema-122 chronicle state. Dev3 перенёс тот же редкий слой в четыре High Risk комплекса:
по одной записи на наземном authored-секторе и по одной на существующем глубоком 3-м ярусе,
без подсказок к cache/strategic items, без изменения floor access и без новых save-полей.
Dev4 связал часть уже найденных документов в пять одноразовых полевых сводок: вывод появляется
только после чтения трёх связанных traces и не даёт наград, целей, маршрутов или unlocks.
Всего 1.25 добавляет 24 authored traces + 5 narrative summaries, сохраняя их в существующей
полевой хронике. Этап закрыт без превращения игры в диалоговую RPG.

### 1.26.0 — Main Goal & Endgame — **ГОТОВО**

Появляется долгосрочный ответ «зачем я всё это делаю?», связывающий исследование,
экипировку и самые опасные зоны. После достижения цели survival продолжается.

Dev1 вводит **Regional Stability Foundation** без «выхода из региона»: готовность вычисляется
из четырёх уже существующих слоёв — 4 starter-route, 4 settlement project, 4 завершённые
фракционные сети и 4 поселения в состоянии STABLE по всем каноническим ресурсам. Активный
аварийный supply-event временно блокирует следующий этап, но не сбрасывает накопленную
готовность. Система derived-only и не добавляет persistent-полей к schema 122. Следующий
срез — управляемый запуск ограниченного Crisis Season поверх этой подтверждённой готовности.

Dev2 добавляет сохраняемый lifecycle **Crisis Season**: ручной запуск из полевой хроники только
при полной готовности и закрытом SOS, длительность 21 игровой день, фазы dormant /
crisis_season / season_complete и защита от повторного запуска. Состояние хранится внутри
существующего `faction_state` и sanitizes под schema 122. Само кризисное давление вынесено в
следующий срез, чтобы lifecycle/save boundary тестировались отдельно.

Dev3 включает само сезонное давление: профильный дополнительный расход по четырём поселениям,
детерминированные пики нагрузки на 7-й и 14-й день, защита от повторного списания в тот же день,
а также persistent `resource_minima` и `hardship_days` для будущего итогового разбора. Давление
идёт после обычной пассивной логистики и до supply-event выбора, поэтому маршруты/projects/endgame
остаются полезны, а прямое восстановление supply/crisis не попадает под скрытый cap.

Dev4 добавляет **Consequence Ending** без «выхода из региона» и без завершения save. После 21-го дня
система один раз фиксирует состояние каждой фракции как УДЕРЖАНО / НАПРЯЖЕНО / ИЗМОТАНО /
КРИТИЧНО по финальным ресурсам, сезонным минимумам, hardship-дням и фактическим supply outcomes.
Из четырёх снимков формируется один из пяти итогов региона: ОБЩИЙ КОНТУР, СЕТЬ УДЕРЖАНА,
ХРУПКОЕ РАВНОВЕСИЕ, РАЗОРВАННЫЙ КОНТУР или ОСТРОВА ВЫЖИВАНИЯ. Итог хранится внутри
существующего `faction_state`, остаётся schema-122 совместимым и после фиксации больше не
пересчитывается. Финальный snapshot на 21-й день делается после same-day supply recovery, чтобы
последний спасённый рейс действительно учитывался.

Dev5 закрывает этап без новой механики: добавлен 21-дневный endgame soak на реальных starter-route,
четырёх settlement projects и четырёх faction endgame effects, сценарии idle / регулярной прямой
поддержки / выборочной поддержки, а также ещё 60 дней post-ending sandbox. Финальный outcome остаётся
замороженным, сезонное давление не возобновляется, повторный старт запрещён. Этап 1.26 закрыт как
**Regional Stability → Crisis Season → Consequence Ending**, без «выхода из региона», credits или
принудительного завершения save.

### 1.27.0 — Character & Animation Final Pass — **ГОТОВО**

Есть большой набор анимаций движения/оружия и weapon-hand art. Нужен финальный проход
ходьбы, бега, sprint/back/strafe/crouch, pistol/long gun/melee, hits/death, рук, ног,
рюкзаков и переходов. После этого animation base замораживается.

Dev1 начинает final pass без перерисовки art: аудит baked survivor sheets подтвердил полное покрытие
всех runtime clips для 10 firearms и 3 melee. Одновременно найден реальный presentation-gap — authored
`Idle2` / `Idle3` существовали для всех 13 weapon-prefix, но runtime никогда их не использовал. Теперь
редкие idle-варианты включаются только после непрерывного бездействия и сбрасываются движением,
выстрелом, reload/cycle, melee, hit, сменой оружия и respawn. Gameplay crouch не добавляется только
ради существующих `Crouch*` sheet: это отдельная механика и не относится к animation final pass.

Dev2 — Locomotion Transition Sync: повторный аудит показал, что gait/direction уже обновляются
в `_process()` до рендера, поэтому ложный однокадровый lag не «чинится» лишними правками.
Исправлены два настоящих presentation-gap: melee idle больше не пропускает доступные
`Idle2/Idle3`, а авторские idle-варианты начинают воспроизводиться с нейтрального frame 0
на собственном 2.25-секундном окне вместо случайного кадра wall-clock. Таблицы walk/run/
back/strafe и приоритеты attack/reload/cycle/hit остаются прежними, без gameplay-эффектов.
Dev3 закрывает этап после реального Godot 4.7.2 runtime/capture: clean import проходит, dev1/dev2 animation tests и weapon-transition regression проходят, а Xvfb/OpenGL captures подтверждают корректные Idle/Idle2/Idle3, melee idle и moving-fire позы без пропажи оружия. Дополнительно исправлен только диагностический SELFTEST label: он теперь берёт текущую версию из `project.godot` вместо устаревшей hardcoded строки. Gameplay, collision, speed, stealth/noise, crouch и death/recovery не менялись. Animation base после этого среза замораживается.

### 1.28.0 — UI/UX Finalization — **ГОТОВО**

Инвентарь, quickbar, tooltip, карта, журнал, снабжение, оборона, контейнеры, верстак и
interaction UI уже существуют. Нужен финальный проход длинных русских строк,
разрешений, скролла, краёв экрана и наложений. Новых больших функций здесь нет.

Dev1 — Region Map Action Strip: реальный 640×360 capture показал, что длинный district survey context
может увести `НАЗНАЧИТЬ ЦЕЛЬ / СБРОСИТЬ ПЛАН` ниже стартовой области scroll-column. Основные
экспедиционные действия вынесены в фиксированную полосу над нижней навигацией, а информационный
контент остаётся скроллируемым. Expedition/save/gameplay логика не меняется.

Dev2 — Inventory Detail Readability: реальный 640×360 stress-capture обнаружил, что полное шестистрочное
описание оружия раздвигает `Label` до 87 px и заходит под нижние кнопки рюкзака, а в контейнере перекрытие
ещё сильнее. В рюкзаке полному описанию выделена фактически свободная зона над action-row; в контейнере
используется отдельная компактная inspection-сводка до трёх строк, потому что подсказка quick-slot там не имеет
смысла. Item stats, loot, grid, transfer/save logic не меняются. Старый inventory-art QA синхронизирован с уже
действующим контрактом: strategic items используют procedural schematic icons, как и встроенный SELFTEST.

Dev3 — UI/UX Final Closure: полный 640×360 audit подтверждает contract/trader/personal/crisis/map/chronicle/
inventory/container/workbench/quickbar/tooltip layouts. Системный tooltip-аудит проходит по всем 66 item defs;
самая высокая панель — 232 px, самый длинный body — 10 строк, title overflow отсутствует. Реальный edge-capture
самого длинного tooltip подтверждает clamp внутри viewport. Новых gameplay/UI функций в closure-срезе нет;
1.28 после этого замораживается.

### 1.29.0 — Audio & Atmosphere — **ГОТОВО**

Dev1 — World Interaction SFX: первый финальный world-audio слой подключает реальные WAV к уже
существующим gameplay-событиям: шаги walk/sprint, открытие/закрытие двери, выброс предмета,
melee swing/hit и громкие операции верстака/строительства. AI hearing, радиусы шума и тайминги
действий не меняются: слышимый звук только зеркалит уже совершённое действие.

Dev2 — Infected & Combat SFX: добавляет дистанционно затухающие audible cues для атаки, боли,
смерти, крика и плевка заражённых, а также player-hit/spit-hit feedback. Эти звуки не участвуют
в AI hearing и не меняют damage, detection, special-role cooldowns или attack intervals.

Dev3 — Atmosphere & Weather: четыре детерминированных loop-слоя (`outdoor day`, `outdoor night`,
`interior roomtone`, `rain`) читают уже существующие world time/weather/shelter state. Базовый
фон плавно переключается day/night/interior, дождь работает отдельным погодным слоем и глушится
под укрытием. Survival/weather/AI расчёты не получают обратной связи от аудио.

Dev4 — UI Feedback & Audio Closure: компактные `open/close/confirm` сигналы подключены только
к центральным UI-переходам и уже успешно совершённым craft/trade/contract действиям. Финальная
регрессия повторно проверяет weapon/world/infected/ambience, High Risk, trading, save recovery и
main selftest на Godot 4.7.2. После этого 1.29 замораживается.

Gameplay-шум для AI уже существует, а в 1.18-dev2 появился первый реальный weapon-audio
слой. Но финальный набор ещё не сделан: нужны итоговые оружейные записи/дизайн, заражённые,
шаги, попадания, двери, окружение, погода, помещения и UI, согласованные с фактической
шумностью действий.

### 1.30.0 — Visual & World Geometry Final QA — **ГОТОВО**

Dev1 — World Geometry Audit: новый production-runtime аудит проходит 106 реальных чанков,
включая 85 authored cells и finite world events. Он проверяет bounds, procedural road separation,
здания/машины/деревья/street furniture, event footprints, door collision-shape и z-order.
На Godot 4.7.2 итог — **6232/6232**. Первичные 21 срабатывание были разобраны отдельно:
authored settlement trees используют собственный door/facade-aware clearance, а увеличенные
High Risk exterior envelopes намеренно стыкуют архитектурные массы. Capture двух спорных
High Risk секторов подтвердил отсутствие визуально сломанных проходов, поэтому dev1 не меняет
геометрию и ассеты без доказанной причины.

Dev2 — High Risk Visual Closure: runtime capture всех четырёх High Risk-комплексов и новый
coverage-test подтверждают уже существующий финальный rebuild: **72/72** authored exterior-модели,
четыре уникальные atlas-family и минимум пять разных ground-composition на каждый объект.
Дневной capture-проход (52 кадра) показывает разные силуэты клиники, карантина, «Бастиона» и
«Вектора» без сломанных магистральных проходов. Поэтому графические ассеты снова не меняются.

Dev3 — General Visual & Clipping Pass: runtime capture обычного мира через Xvfb проверил representative residential, commercial, industrial, rail и dacha buildings на реальном Godot 4.7.2. Фасады, крыши, interiors, doors, roadside geometry и roof-fade читаются без подтверждённого clipping. Вместе с dev1 geometry audit и dev2 High Risk visual closure это закрывает 1.30 без art-rebuild ради номера версии.

### 1.31.0 — Performance & Long Session Stability — **ГОТОВО**

Dev1 — Long Session Baseline: runtime QA на Godot 4.7.2 подтверждает стабильный chunk churn, cleanup infected/events и большой production-save без накопления нод. 96 переходов возвращают node-count/roof-records к исходному уровню; 24 повторных encounter load/unload не оставляют infected/event nodes; 20 больших save-записей остаются 251539 байт и читаются обратно. Дополнительно проходят 365-дневная multi-route economy, 180-дневные High Risk farming/personal-contract soak и post-endgame soak.

Dev2 — Mixed Long-Session Closure: один долгоживущий runtime одновременно держит крупную базу/хранилища, 48 переходов по миру, повторные finite-event cold-load, daily economy и production saves. Первый проход закономерно материализует container/door/window persistence, но повторный обход тех же чанков оставляет save строго стабильным (252012 -> 252012 байт); node-count и roof-records также возвращаются к исходному уровню. Это подтверждает bounded first-visit growth, а не утечку. 1.31 закрыт без рискованной переделки persistence.

### 1.32.0 — Save Compatibility & Recovery — **ГОТОВО**

Dev1 — Save Compatibility Matrix: финальный runtime matrix на Godot 4.7.2 проверяет старые migration-boundaries, `.bak` recovery после повреждения, malformed nested state, expedition/weapon-instance persistence и совместный current-schema roundtrip современных систем 1.23–1.31. Production writer по-прежнему пишет schema 122; новые top-level save blobs не вводились. Старые sparse schema-122 сейвы получают только безопасные defaults без бесплатного прогресса, malformed вложенные подсистемы санитизируются, а валидные современные route/project/endgame/chronicle/NPC/High Risk состояния переживают повторный save/load без дублирования.

### 1.33.0 — Content Complete / Feature Lock — **ГОТОВО**

Dev1 — Feature Lock Audit: новых систем не добавлено. Финальный release-surface audit подтвердил version guard developer UI/F10 и закрыл последний прямой QA leak: `ТЕСТ: ВСЕ ПРЕДМЕТЫ` и его world-label теперь создаются только в `-dev` сборках. Обычные showcase-контейнеры/верстак/тайники не менялись. Stable/RC без `-dev` не получают full-catalogue crate, dev/QA сборки сохраняют его для item coverage. После этой точки новые крупные механики запрещены; разрешены только доказательные bugfix, playthrough/balance/release QA.

### 1.34.0 — Full Playthrough Beta — **ГОТОВО**

Dev1 — Full Playthrough Beta Baseline: три независимых production-state прохождения на Godot 4.7.2 идут от свежего старта через vertical slice, четыре starter routes, четыре settlement project и четыре faction endgame chain до 100% Regional Stability, 21-дневного Crisis Season, consequence ending и post-ending schema-122 save/reload. Supported-run входит в сезон с резервом и поддерживает все поселения, получая `cohesive`; strained-run стартует ровно с порога 55 и поддерживает только Перрон/Лазарет, получая не-cohesive итог; unsupported-run не даёт прямой поддержки и подтверждает широкий региональный strain без softlock. QA ускоряет только повторяющийся reputation/resource grind, но использует реальные contract/project/endgame/start/daily/save APIs и реальные progression gates. Во время beta также исправлен release-surface дефект: заголовок окна больше не захардкожен на `1.26.0-dev4`, а берёт текущую версию проекта динамически.

### 1.35.0 — Balance Lock — **ГОТОВО**

Последняя доказательная корректировка урона, брони, survival, веса, drop rates,
cooldown, заражённых и цены ошибок. После — числа меняются только при доказанном
серьёзном дисбалансе.

Dev1 — Balance Lock: существующие balance/reference/soak проверки на Godot 4.7.2 не выявили
доказанного дисбаланса, поэтому gameplay-числа намеренно не менялись. Проверены trading,
Crisis Season/endgame, multi-route scarcity, High Risk farming и combat/gear; исторические
version gates оставлены историческими. После этого среза числовые gameplay-правки допускаются
только при воспроизводимом серьёзном дефекте. Save schema остаётся 122.

### 1.36.0 — Release Candidate — **ГОТОВО**

Чистый Godot 4.7.2 import, полный regression/save/load/visual QA/playthrough, без
случайного debug/test мусора. `ТЕСТ: ВСЕ ПРЕДМЕТЫ` остаётся только в QA/dev режиме
или исключается из обычной релизной игры.

Dev1 — Release Candidate: clean import и три full-playthrough сценария подтверждены; save migration/recovery/current-schema, trading, High Risk visual closure, long-session, geometry и audio regression проходят без failures. 52 High Risk runtime-capture (4 комплекса × 13 кадров) просмотрены без нового clipping regression. Gameplay/content не менялись; save schema остаётся 122, Balance Lock сохранён. После этого среза допускаются только критические исправления перед 1.37.0 Final Release.

### 1.37.0 — Final Release — **ГОТОВО**

Финальный Stable promotion принят из 1.36.0-dev1 Release Candidate без новых gameplay/content систем и без числового ребаланса. Перед promotion clean Godot 4.7.2 import дал 651/651 `.ctex`; supported full playthrough прошёл 196/196, current-schema roundtrip 42/42. После смены версии на `1.37.0` актуальные release gates и main selftest прошли без failures. Save schema остаётся 122, 16 authored named NPC и 651 PNG сохранены; исходные art assets не менялись. Дальше — только `1.37.x` критические hotfix/maintenance без feature creep.

### 1.37.1 — Ambience Shutdown Hotfix — **ГОТОВО**

Первый post-release maintenance hotfix исправляет подтверждённый lifecycle-дефект: четыре
зацикленных ambience `AudioStreamPlayer` оставляли `AudioStreamPlaybackWAV` и WAV resources
удержанными до завершения Godot. Gameplay, mix levels, weather/shelter selection, save schema,
AI hearing, баланс и art не меняются. При `_exit_tree()` ambience loops теперь явно останавливаются,
отвязывают stream и очищают presentation cache. Обычный main-scene shutdown после исправления
завершается без ObjectDB/resource leak warnings. Дальше по-прежнему только критические `1.37.x`
maintenance/hotfix без feature creep.
