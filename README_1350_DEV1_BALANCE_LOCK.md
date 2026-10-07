# OSTATOK 1.35.0-dev1 — Balance Lock

Balance Lock завершён без произвольного rebalance. Числа gameplay не менялись: все целевые
balance/reference/soak проверки остались в принятых границах на Godot 4.7.2.

Проверено отдельными небольшими пакетами:
- historical release-candidate balance: 7891 checks / 1 expected historical version-gate fail;
- trading economy: 512/512;
- Regional Endgame soak: 42/42;
- multi-route economy guardrail: 23/23;
- 365-day multi-route economy soak: 29419/29419;
- High Risk farming soak 30/60/180: 440/440, 57 cycles;
- combat & gear balance: 96/96.

Дополнительный старый encounter-balance suite дал 82 checks / 1 historical current-build-version
mismatch; все его механические проверки проходят. Исторические version gates не переписывались.

Production gameplay delta относительно 1.34.0-dev1: отсутствует. Изменены только release metadata,
current-version High Risk QA gate, roadmap и документация Balance Lock.

Current release gates after version bump:
- High Risk current-version suite: 130/130;
- main.tscn: `OSTATOK 1.35.0-dev1 SELFTEST: OK`, failures=0.

Save schema: 122.
После этого среза числовой баланс считается замороженным и меняется только при воспроизводимом
серьёзном дисбалансе. Следующий roadmap-этап: 1.36.0 Release Candidate.
