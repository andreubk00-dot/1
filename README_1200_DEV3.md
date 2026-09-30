# OSTATOK 1.20.0-dev3 — High-Risk Locations II / Underground Object Vector

Это **операция 4** из плана 1.20. Stable 1.19, dev1 и dev2 остаются отдельными контрольными сборками.

## Что сделано

- активирован только второй объект второго поколения: `underground_object_vector` — подземный объект «Вектор»;
- сохранён зарезервированный footprint 2×3: шесть отдельных authored-секторов;
- вход: шахта доступа/гермошлюз; выход: отдельный сервисный тоннель; глубокое ядро находится в другом секторе;
- архитектура намеренно отличается от открытого госпитального кампуса: тёмные технические поверхности, узкие corridor/choke-point схемы, нулевые деревья/машины внутри объекта;
- отдельные encounter-профили `vector_access`, `vector_tunnels`, `vector_core` используют только normal/runner/brute и не забегают вперёд в 1.21;
- `vector_core` — brute-heavy давление тесного подземного пространства, тогда как `clinical_core` остаётся runner-heavy;
- новый loot profile `vector_core` сфокусирован на ремонте, фильтрации воды, освещении, аварийном снабжении и экспедиционном снаряжении; firearms в него не входят;
- persistence использует существующие deterministic container/defeated keys и прежний SaveStore; save schema не менялась;
- `hard_requirements = []`: предмет, добываемый внутри «Вектора», не нужен для первого входа;
- госпиталь из dev2 не переработан и проходит свой regression после активации «Вектора».

## Что намеренно НЕ сделано

- нет новых разновидностей заражённых — это 1.21;
- нет `farm_profile` и `refresh_days` у госпиталя и «Вектора» — общий target farming относится к операции 5;
- нет финальной перекалибровки rarity/drop chances между двумя новыми объектами — это операция 5;
- нет новых квестовых стрелок/подсказок с точным расположением core-награды: discovery-first сохранён.

## QA

Godot **4.7.2 stable official `ed1daf0bf`**: clean import завершён, runtime SELFTEST **OK** (`QA_SELFTEST_EXIT: failures=0`). Полный regression: **46/46 suites, 8295 checks, 0 failures**.

Профильные ворота: Vector **399/399**, High-Risk II boundary **25/25**, world-layout/target-farming **1250/1250**, spawn safety **879/879** с runtime overlap **0/439**, Clinical Complex regression **332/332**.

## Дальше

**Операция 5 — интеграция 1.20.** Обе endgame-локации уже существуют. Следующий этап не добавляет третью локацию: он сводит loot-risk, заражённых, target farming/cooldown, save/load и discovery-first в единый баланс и выполняет полный Godot regression перед решением о готовности 1.20.
