# OSTATOK 1.30.0-dev2 — High Risk Visual Closure

Финальный High Risk visual pass выполнен как доказательный audit, без перерисовки уже корректных ассетов.

## Результат

Четыре комплекса подтверждены как визуально разные семейства:

- Областной клинический комплекс №4 — медицинский кампус и крупные лечебные корпуса;
- Карантинный центр №12 — изоляторы, триаж, палатки и карантинная инфраструктура;
- Резервный арсенал «Бастион» — военные ангары, плацы и складские массы;
- Подземный объект «Вектор» — инженерно-технические корпуса, шахты и служебные узлы.

Новый automated closure-test проверяет все 72 authored exterior model и четыре независимые atlas-family. Runtime capture покрывает 6 ground-cells × 2 gameplay framing + overview для каждого объекта — 52 дневных кадра.

## Почему art не менялся

Финальный rebuild, который roadmap переносил в 1.30, фактически уже сформирован текущими High Risk exterior atlas/model data. Capture и runtime QA не подтвердили повторяющихся generic boxes, сломанных крыш или перекрытых основных проходов. Менять эти ассеты только ради номера версии было бы риском без доказанной пользы.

## Boundary

- save schema: **122**;
- High Risk access/strategic items/target farming: без изменений;
- PNG: byte-identical dev1;
- historical 1.22 gates: untouched;
- gameplay geometry: без изменений.
