# OSTATOK 1.22.0-dev1 — Faction Foundation

Foundation pass for the approved 1.22 Factions / Traders / Economy milestone.

Implemented:
- four canonical factions: «Перрон», «Рубеж», Артель «Механики», «Лазарет»;
- four authored large 3×3 settlement compounds (9 chunks each), integrated into world POI lookup;
- named NPC rosters and functional service identities for every faction;
- persistent faction state in saves;
- shared currency: расчётные талоны;
- four reputation tiers: Чужой → Знакомый → Надёжный → Доверенный;
- settlement resource state: food / medicine / technical / security;
- specialist market affinities and anti-farming market saturation;
- settlement supply decay foundation for later caravan/contract effects;
- regression coverage in `tests/test_factions_122.gd`.

Deferred by design:
- high-risk visual redesign;
- full trader UI and inventory transactions (1.22-dev2);
- generated contracts (1.22-dev3);
- caravan/supply world events (1.22-dev4);
- conflicting faction contracts (1.22-dev5);
- final economy balance (1.22-dev6).
