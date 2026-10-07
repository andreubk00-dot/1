# OSTATOK 1.23.0-dev4 — QA / Regression Report

Дата: 2026-10-04
Движок: Godot 4.7.2 Stable (предоставленный пользователем)
Save schema: 122

## Результат

Dev4 проходит runtime, save/load и долгосрочные проверки нового контрактного слоя. Критических ошибок загрузки ресурсов или GDScript на финальном запуске не обнаружено.

## Новая функциональность

- 4 постоянных NPC получили отдельные личные контрактные доски.
- 8 авторских поручений образуют 4 двухэтапные цепочки.
- Ограниченное время появления предложения.
- Дедлайн после принятия.
- Последствия отказа и просрочки.
- Безопасная отмена при недоступности владельца NPC.
- Личная история/attitude интегрированы с состоянием NPC dev3.
- Финалы цепочек дают постоянные мировые маршруты/ресурсные эффекты.
- Радиохроника dev2 получает значимые исходы личных поручений.

## Исправления, найденные во время dev4

### Повторное появление истёкшего предложения

Ранняя реализация могла сразу создать то же личное предложение после его истечения, потому что непринятое истечение не попадало в историю cooldown. Исправлено: органически истёкшее предложение записывается как `offer_expired`, после чего действует стандартный history cooldown.

### Устаревший settlement runtime invariant

Старый тест ожидал ровно одного физического контрактодателя на поселение. После появления личных досок это больше не соответствует дизайну. Тест не ослаблен: он теперь отдельно требует ровно **1 общего + 1 личного** контрактодателя в каждой из четырёх фракций.

## Новые тесты

| Тест | Результат |
|---|---:|
| Personal contract systems | 123 / 123 |
| Personal contract runtime UI | 23 / 23 |
| Personal contract production save/load | 17 / 17 |
| Personal contract 30/60/180-day soak | 31 / 31 |
| Faction settlement runtime (dev4 invariant) | 169 / 169 |

Soak-проверка подтверждает: персональные доски не разрастаются, лимит активных контрактов сохраняется, история ограничена, дедлайн срабатывает один раз и штраф не дублируется.

## Ключевые регрессии

| Подсистема | Результат |
|---|---:|
| General contracts | 52 / 52 |
| Contract runtime UI | 18 / 18 |
| Faction relations | 65 / 65 |
| Factions | 244 / 244 |
| Named NPC state | 105 / 105 |
| Named NPC runtime | 14 / 14 |
| Supply events | 35 / 35 |
| Supply event runtime | 15 / 15 |
| Settlement crisis | 31 / 31 |
| Settlement crisis UI | 8 / 8 |
| Trading economy | 512 / 512 |
| World chronicle | 14 / 14 |
| Rest / midnight rollover | 38 / 38 |
| World encounters | 1819 / 1819 |
| World persistence | 16 / 16 |
| Settlement layout | 674 / 674 |
| High Risk locations | 373 / 373 |
| High Risk visual multifloor | 130 / 130 |
| High Risk reception model | 10 / 10 |
| High Risk II integration | 170 / 170 |
| Clinical complex endgame | 368 / 368 |
| Vector endgame | 435 / 435 |

### 180-day RC balance

`test_release_candidate_balance_122.gd`: **7890 механических проверок проходят**. Единственный формальный fail — исторический release-gate, который намеренно требует `1.22.0 Stable`, тогда как текущая сборка — `1.23.0-dev4`. Gate оставлен неизменным, чтобы dev-ветка не могла случайно выдать себя за Stable.

## Production save/load в изолированных XDG-каталогах

| Подсистема | Результат |
|---|---:|
| General contracts | 10 / 10 |
| Faction relations | 9 / 9 |
| Faction endgame | 9 / 9 |
| Supply events | 8 / 8 |
| World chronicle | 7 / 7 |
| Named NPC state | 8 / 8 |
| Personal contracts | 17 / 17 |
| Schema migration | 15 / 15 |
| Save recovery | 18 / 18 |
| Expedition save | 54 / 54 |
| High Risk integration | 170 / 170 |

## Stable gates

Некоторые старые release-candidate тесты содержат буквальную проверку версии `1.22.0 Stable` и/или требования Stable-конфигурации dev-tools. Эти проверки ожидаемо красные на `1.23.0-dev4`; соответствующие механические части тестов проходят. Stable-gates специально не переписывались под dev4.

## Графика

Dev4 не меняет арт. Побайтовое сравнение с dev3:

- 651 графический asset в dev3;
- 651 в dev4;
- changed: 0;
- added: 0;
- removed: 0.

High Risk visual/regression тесты остаются зелёными.

## Проверка запуска

Реальная `main.tscn` загружена Godot 4.7.2 в headless runtime. Self-test: `OSTATOK 1.23.0-dev4 SELFTEST: OK`. За окно проверки не получено `SCRIPT ERROR`, `Parse Error`, resource-loading errors.

## Следующий безопасный этап

После dev4 этап 3 механически закрыт. Следующий пункт плана — High Risk зоны на уровне механики: собственный уровень опасности, уникальные loot pools, ограниченная ценная добыча, доступ по ключам/пропускам, локальные события, состояния после зачистки и антифарм-респаун. Визуальный слой при этом можно оставить неизменным.
