# OSTATOK 1.26.0-dev5 — Regional Endgame Closure

Dev5 — QA/closure-срез. Новых endgame-механик здесь нет: функциональная реализация завершена в dev4.

## Закрытая 1.26-цепочка

1. **Regional Stability Foundation** — 4 маршрута + 4 проекта + 4 faction endgame chain + 4 стабильных поселения.
2. **Crisis Season Lifecycle** — ручной запуск и 21 день, schema 122.
3. **Crisis Season Pressure** — дополнительный профильный спрос и пики на 7/14 день.
4. **Consequence Ending** — 4 фракционных статуса и 5 региональных итогов.
5. **Dev5 Closure** — soak/regression, без новых правил.

После ending игра остаётся обычным sandbox: торговля, supply events, settlement crises, contracts, High Risk, exploration и ресурсы продолжаются. Исторический итог сезона больше не пересчитывается и Crisis Season повторно не запускается.

## Новые QA

`tests/test_regional_endgame_soak_126.gd`

Использует реальные authored starter-route records, 4 завершённых settlement project и 4 faction endgame effects. Сценарии:

- idle: игрок не даёт дополнительную поддержку;
- supported: регулярное прямое восстановление всех четырёх поселений;
- selective: поддержка только Перрона и Лазарета;
- затем 60 дополнительных sandbox-дней после outcome.

`tests/test_regional_endgame_closure_126.gd`

Фиксирует основные release-инварианты 1.26: 21 день, 4 faction categories, 5 regional outcomes и отсутствие отдельного escape/game-over state.

## Save compatibility

Save schema остаётся **122**. Endgame state живёт только внутри существующего `faction_state["regional_endgame"]`.

## Не менялось в dev5

- `regional_endgame.gd` относительно dev4;
- экономика;
- supply/crisis;
- contracts;
- High Risk;
- strategic items;
- route/project/endgame effects;
- NPC roster;
- graphical assets.

Следующий roadmap-этап: **1.27 Character & Animation Final Pass**.
