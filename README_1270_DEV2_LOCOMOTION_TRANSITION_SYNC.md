# OSTATOK 1.27.0-dev2 — Locomotion Transition Sync

Продолжение 1.27 Character & Animation Final Pass от подтверждённого dev1 ZIP. Узкая правка в `main_script_mod.gd`, без новых графических ассетов, геймплейных правил и save-полей.

## Аудит и исправления

1. **Melee idle**: `combat_knife`, `steel_pipe`, `fire_axe` при неподвижности всегда возвращали `Idle`, хотя для соответствующих baked-prefix (`knife/pipe/axe`) уже существуют `Idle2` и `Idle3`. Теперь используется тот же `_modern_survivor_idle_sheet()` и тот же transient idle timer, что у firearms. Swing `Attack3/Attack4`, walk/run/back/strafe и hit по-прежнему имеют приоритет.
2. **Start frame of idle variants**: dev1 выбор `Idle2/Idle3` был детерминирован, но их frame index брался из глобального `Time.get_ticks_msec()`. При входе в новый вариант анимация могла перескочить прямо в середину веса/позы. Теперь variant frame вычисляется по времени внутри собственного 2.25-секундного окна, вход всегда на frame 0; обычный `Idle` использует прежнюю схему. Предварительная atlas-проверка подтвердила близость первых кадров вариантов к нейтральной позе для всех 13 оружейных вариантов.

Проверенный при аудите ложный кандидат **не менялся**: направление и фаза ходьбы уже обновляются в `_process()` до `_update_player_visuals()`, поэтому устранять там «однокадровое запаздывание» было бы неверно.

## Не изменено

- скорость/ускорение, направление движения и коллизия;
- выстрелы, recoil, reload, weapon cycle, melee swing и hit timings;
- crouch, sprint rules, stealth/noise и death/recovery;
- weapon assets, props и весь art (651 PNG);
- save schema **122**, persistent NPC (16), economy, contracts, High Risk, regional endgame.

`Idle2/Idle3` не несут механического влияния и не пишутся в save. Главная мировая цель и выход из региона не добавляются.

## Проверки

```bash
python3 tools/qa_127_dev2_reference.py
```

Для финального runtime gate нужен Godot **4.7.2 stable**:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script tests/test_locomotion_transition_sync_127.gd
XDG_DATA_HOME=/tmp/ostatok127d2_user OSTATOK_QA_SAVE_ROOT=/tmp/ostatok127d2_user \
  godot --headless --path . --script tests/test_locomotion_save_boundary_127.gd
godot --path . --script tests/qa_locomotion_transition_capture.gd -- --qa-output=/tmp/ostatok127d2_captures
```

Запуск production selftest: `godot --headless --path . --scene res://main.tscn -- --selftest` — аргументы адаптировать к действующему selftest-runner проекта. Для сохранений — исключительно изолированный `XDG_DATA_HOME`.

**Runtime/capture/selftest: PENDING** в этой среде, где Godot 4.7.2 недоступен. Статический PASS не заменяет Godot-парсер и игровой прогон.
