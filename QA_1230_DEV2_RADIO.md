# OSTATOK 1.23.0-dev2 — QA note

## Проверено статически в этой сборке

- save schema по-прежнему `122`;
- хроника входит внутрь `faction_state` и проходит через `FactionEconomy.sanitize_state()`;
- все три пути смены дня (обычный ход времени, debug +1 час, сон) используют `_process_world_day_rollovers()`;
- существующие графические исходники не изменены относительно приложенной `1.23.0-dev1`;
- 651 PNG/JPG/WebP/BMP исходник успешно открывается и проходит проверку целостности;
- новый UI «ЭФИР» укладывается в 640×360 canvas и не пересекает соседние кнопки нижней панели карты;
- изменённые GDScript-файлы прошли статическую проверку строк/скобок и проверку на дубли имён функций;
- ссылка теста на удалённый `medical_entry_v03` намеренно отрицательная: тест проверяет отсутствие старого render skin после dev1 rework.

## Добавленные regression tests

- `tests/test_world_chronicle_123.gd`;
- `tests/test_world_chronicle_save_runtime_123.gd`;
- расширен `tests/test_rest.gd` для сна через полночь;
- version gate в `tests/test_high_risk_visual_multifloor.gd` обновлён на dev2.

## Что обязательно прогнать в Godot 4.7.2 перед Stable

В среде, где готовилась эта сборка, Godot runtime отсутствовал, поэтому движковые тесты и реальный render-capture здесь не запускались. Минимальный прогон:

```bash
godot --headless --path . --script res://tests/test_world_chronicle_123.gd
godot --headless --path . --script res://tests/test_rest.gd
godot --headless --path . --script res://tests/test_high_risk_visual_multifloor.gd
```

Для runtime save/load теста использовать отдельный каталог, как в существующем QA проекта:

```bash
QA_ROOT=/tmp/ostatok_qa_dev2
mkdir -p "$QA_ROOT"
XDG_DATA_HOME="$QA_ROOT" OSTATOK_QA_SAVE_ROOT="$QA_ROOT" \
  godot --headless --path . --script res://tests/test_world_chronicle_save_runtime_123.gd
```

После этого нужен полный regression run существующих `tests/test_*.gd` и визуальный capture High Risk зон. Stable-version tests, которые намеренно требуют `1.22.0`, в dev-ветке могут продолжать падать только на version gate — не переписывать их ради зелёного dev-прогона.
