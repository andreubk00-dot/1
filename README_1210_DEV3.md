# OSTATOK 1.21.0-dev3 — Infected Variety / Screamer + Spitter + Carrier

Третья development-итерация 1.21 добавляет **последнюю новую качественную роль перед общим encounter balance pass** — заражённого **«Носитель»** (`carrier`). Крикун и Плевун сохранены без смены своих ролей.

## Носитель: тактическая роль

Носитель не является bullet sponge: HP, скорость и melee damage ниже обычного заражённого. Его опасность появляется **в момент добивания**.

- после смерти есть короткое окно предупреждения: **~0.35 с**;
- затем на месте тела возникает заражённая зона радиусом **~62 px**;
- активная зона живёт **~3.4 с**;
- урон низкий (~1.8 HP/с), но зона заметно тратит stamina и заставляет немедленно менять позицию;
- если у игрока уже есть кровоточащая рана, задержка в облаке дополнительно загрязняет её;
- облако не проходит через стены;
- Developer invulnerability полностью блокирует урон/stamina/contamination от облака;
- Носитель специально получает повышенный knockback/stagger, поэтому его выгодно **оттолкнуть из прохода перед добиванием** либо уничтожить с дистанции;
- повторный lethal hit не может создать несколько облаков с одного заражённого.

Это даёт третью отдельную тактическую задачу: Крикун наказывает затяжной контакт шумом, Плевун ломает статичную дальнюю позицию, Носитель заставляет выбирать безопасное место и дистанцию для последнего удара.

## Encounter scope

В dev3 все три специальные разновидности остаются редким authored-контентом high-risk интерьеров/core. Их по-прежнему нет в `standard`, high-risk perimeter, Clinical perimeter и Vector access.

- Clinical сохраняет runner-heavy identity.
- Vector сохраняет brute-heavy identity.
- Carrier немного чаще встречается в глубоком Vector core, где важнее управление узкими проходами, но остаётся редкой долей состава.
- Доли Screamer/Spitter сохранены в прежних authored bands; Carrier добавлен за счёт части normal/brute/runner mix, а не через рост общего числа заражённых.

**На этом новые разновидности заражённых для 1.21 замораживаются.** Следующий dev-этап — общий balance pass: плотность, сочетания ролей, шум, stopping power, расход патронов и сложность high-risk объектов.

## Совместимость

- Save schema: **105**, без изменений.
- Carrier death cloud — transient combat state, в save не сериализуется.
- Новых предметов нет; `ТЕСТ: ВСЕ ПРЕДМЕТЫ` не меняется.
- Loot/target farming 1.20 не менялись.
- Developer Mode F10 доступен только в `-dev` версиях; Stable guard сохранён.

## QA

- Godot 4.7.2 stable official `ed1daf0bf`.
- Runtime SELFTEST: **OK**.
- Screamer suite: **48/48**.
- Spitter suite: **71/71**.
- Carrier suite: **73/73**.
- Clinical: **332/332**.
- Vector: **399/399**.
- Spawn safety: **879/879**, `0/439` overlaps.
- Full external regression: **51/51 suites, 8828 checks, 0 failures**.
- Across external regression: **0 Godot ERROR, 0 Godot WARNING**.

Подробности: `QA_1210_DEV3/ENGINE_QA_DEV3.md`, `ROADMAP_RELEASE_RU.md`.
