# OSTATOK 1.37.1 — Ambience Shutdown Hotfix

`1.37.1` — минимальный Stable maintenance hotfix поверх `1.37.0`.

Исправлено только освобождение presentation-only ambience audio при завершении main scene:
- четыре looped ambience players явно останавливаются;
- их `stream` references отвязываются;
- ambience player/cache dictionaries очищаются.

До исправления обычный Godot shutdown воспроизводимо сообщал о 8 leaked ObjectDB instances и
4 resources still in use (`outdoor_day`, `outdoor_night`, `interior_roomtone`, `rain`). После
исправления тот же main-scene shutdown завершается без этих warnings.

Gameplay, save schema 122, AI hearing, weather/shelter logic, громкости, баланс, content и art не менялись.
