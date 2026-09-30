# OSTATOK 1.20.0-dev4-hotfix1 — Developer Mode / Import-Safe Hotfix

Этот архив заменяет предыдущий `1.20.0-dev4`.

Исправлена критическая проблема первого запуска: прежняя упаковка исключала Godot import cache,
из-за чего до завершения импорта SELFTEST мог показывать сотни ошибок, а Debugger Godot — тысячи
повторных ошибок загрузки `.ctex`.

Hotfix не добавляет игровой контент и не начинает Operation 5. Developer Mode остаётся прежним:
F10 / DEV-панель, неуязвимость, no-aggro и телепорты по основным POI.

## Первый запуск

Архив уже содержит import cache от официального Godot 4.7.2. Если Godot всё же начинает reimport,
дождитесь 100% Importing Assets. При попытке запуска до завершения импорта игра теперь безопасно
останавливается на экране импорта вместо запуска мира с отсутствующими ресурсами.

QA: 47/47 suites, 8389 checks, 0 test failures; warm SELFTEST OK; cold-start resource errors 0.
