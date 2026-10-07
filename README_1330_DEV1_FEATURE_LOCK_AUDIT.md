# OSTATOK 1.33.0-dev1 — Feature Lock Audit

Content Complete / Feature Lock pass. Новых игровых систем нет.

## Исправление release surface

До dev1 `ТЕСТ: ВСЕ ПРЕДМЕТЫ` создавался в стартовом showcase-секторе независимо от версии. F10 developer UI уже был защищён Stable guard, но будущая Stable/RC сборка всё равно могла физически получить full-catalogue QA crate.

Теперь контейнер `garage_all_items_0163` и подпись `ТЕСТ-ЯЩИК: ВСЕ ПРЕДМЕТЫ` создаются только при `_developer_tools_available()`, то есть только когда `application/config/version` содержит `-dev`.

- `1.33.0` / RC / Stable: QA crate отсутствует;
- `1.33.0-dev1`: QA crate остаётся для item-coverage тестов;
- обычные контейнеры, скрытый тайник, верстак и геометрия showcase-сектора не менялись;
- save schema остаётся 122.

После 1.33 новые крупные механики запрещены. Далее — full playthrough beta, balance lock и release hardening.
