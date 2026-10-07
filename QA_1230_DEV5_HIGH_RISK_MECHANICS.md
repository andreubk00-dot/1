# OSTATOK 1.23.0-dev5 — QA / Regression Report

Дата: 2026-10-04
Движок: Godot 4.7.2 Stable (предоставленный пользователем)
Save schema: 122

## Результат

Dev5 закрывает механическую часть High Risk этапа без изменения графических ассетов и без миграции save schema. Финальный проект импортируется и запускается на Godot 4.7.2 без GDScript parse/resource-loading errors; встроенный self-test сообщает `OSTATOK 1.23.0-dev5 SELFTEST: OK` и `QA_SELFTEST_EXIT: failures=0`.

## Новая функциональность

- Сохраняемое состояние четырёх High Risk объектов.
- Закрытый переход 2 → 3: аварийный override только после зачистки текущего уровня.
- Глубинные target-farm кеши недоступны до разблокировки внутреннего сектора.
- Доступ привязан к циклу и снова закрывается после повторного заселения.
- Уникальный локальный опасный инцидент для каждого объекта.
- Детерминированные spawn ID инцидента и корректное сохранение уничтоженных заражённых.
- Состояния «зачищен / истощён / повторно заселён / доступ вскрыт».
- Статус High Risk объекта на карте без спойлеров внутреннего решения и loot pool.
- Повторный лут переведён в salvage: specialized/unique не восстанавливаются, остальные категории ослаблены.
- Частичное повторное заселение внешнего периметра и полное возвращение глубинной угрозы.

## Исправления, найденные во время dev5

### Ложная новость при миграции старого defeated-состояния

Первая реализация dev5 могла сначала объявить локальный инцидент в мировой хронике, а затем распознать, что все его stable spawn ID уже помечены убитыми в старом schema-122 save. Это давало ложную новую опасность после загрузки.

Исправлено: dev5 сначала проверяет существующие defeated ID и принимает полностью завершённый старый инцидент как resolved; сообщение создаётся только если хотя бы одна угроза действительно существует.

### Production save validation

Новый `high_risk_state` добавлен в строгую проверку `SaveStore`. Если блок повреждён и имеет неверный тип, primary save не принимается как корректный и сохраняется существующая логика recovery через `.bak`.

### Устаревшее ожидание полного respawn в integration-комментарии

High Risk integration-тест приведён к новому инварианту: повторное заселение обязано вернуть глубокую/core угрозу, но внешний периметр теперь намеренно восстанавливается лишь частично. Проверка другого POI и unrelated defeated-состояния сохранена.

## Новые тесты

| Тест | Результат |
|---|---:|
| High Risk mechanics | 92 / 92 |
| High Risk production save/load + schema-122 migration | 17 / 17 |
| High Risk 30/60/180-day anti-farm soak | 440 / 440 |

Soak выполнил **57** реальных циклов восстановления четырёх High Risk объектов. Подтверждено:

- specialized/unique повторно не появляются;
- salvage не исчезает полностью;
- cooldown не сокращается;
- доступ каждый новый цикл снова закрыт;
- локальный инцидент возвращается только с новым циклом;
- счётчик циклов не пропускает и не дублирует значения.

## High Risk regression

| Подсистема | Результат |
|---|---:|
| High Risk locations | 373 / 373 |
| High Risk II integration | 170 / 170 |
| High Risk visual/multifloor | 130 / 130 |
| Target farming / world layout | 1324 / 1324 |
| Clinical complex endgame | 368 / 368 |
| Vector endgame | 435 / 435 |

## Основные механические регрессии

| Подсистема | Результат |
|---|---:|
| General contracts | 52 / 52 |
| Contract runtime UI | 18 / 18 |
| Personal contracts | 123 / 123 |
| Personal contract UI | 23 / 23 |
| Personal contract soak | 31 / 31 |
| Named NPC state | 105 / 105 |
| Named NPC runtime | 14 / 14 |
| Supply events | 35 / 35 |
| Supply event runtime | 15 / 15 |
| Faction relations | 65 / 65 |
| Factions | 244 / 244 |
| Settlement crisis | 31 / 31 |
| Faction settlement runtime | 169 / 169 |
| Settlement layout | 674 / 674 |
| Trading economy | 512 / 512 |
| World chronicle | 14 / 14 |
| Rest / midnight rollover | 38 / 38 |
| World encounters | 1819 / 1819 |

## Production save/load в изолированных XDG-каталогах

| Подсистема | Результат |
|---|---:|
| High Risk dev5 | 17 / 17 |
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

`test_release_candidate_balance_122.gd`: **7890 механических проверок проходят**. Единственный формальный fail — исторический release-gate, который требует буквальную версию `1.22.0 Stable`; текущая сборка намеренно `1.23.0-dev5`. Gate не переписывался, чтобы dev-ветка не могла случайно выдать себя за Stable.

## Графическая регрессия

Побайтовое сравнение dev4 → dev5:

- assets dev4: 651;
- assets dev5: 651;
- changed: 0;
- added: 0;
- removed: 0.

Актуальный High Risk visual/multifloor runtime-тест: 130/130. Новый этап не вносит скрытых изменений PNG/JPG/WebP/SVG.

## Следующий безопасный этап

Следующий пункт механического плана — стратегические предметы и крупные resource sinks. Dev5 специально не вводит новый ключевой предмет для High Risk дверей, чтобы не смешивать этапы: доступ пока реализован как системный аварийный override после зачистки, а редкие предметы прогресса можно связать с более крупными проектами поселений на следующем этапе.
