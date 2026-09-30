# OSTATOK 1.21.0 Stable — Release Record

## Release scope

Infected Variety & Encounter Balance. Stable продвигает принятый `1.21.0-dev5` без новых систем,
новых архетипов, дальнейшей визуальной переработки high-risk или изменения save schema.

## Stable gates

- project version: `1.21.0`;
- Godot: **4.7.2 stable official `ed1daf0bf`**;
- runtime SELFTEST: **OK**;
- external regression: **53/53 suites**;
- checks: **9040**;
- failures: **0**;
- external Godot logs: **0 ERROR / 0 WARNING**;
- save schema: **105**, unchanged;
- developer tools disabled by release guard because Stable has no `-dev` suffix;
- cold copy without `.godot` stops at import guard before world/SELFTEST with **0 ERROR**;
- fresh Godot 4.7.2 import cache contains **1362 imported files**, 0 ERROR / 0 WARNING;
- graphical X11 smoke: SELFTEST OK / 0 ERROR; virtual llvmpipe reports only its V-Sync capability warning.

## Included 1.21 functionality

- Screamer / Spitter / Carrier as qualitative authored high-risk roles on top of normal / runner / brute;
- special roles excluded from standard and perimeter encounters;
- Clinical runner-heavy and Vector brute-heavy encounter identity;
- final 1.21 tuning of movement/HP/stagger, call/spit/death-zone pressure and upper-floor enemy budgets;
- functional multi-floor high-risk layer/persistence foundation;
- no new items, no new major POI, no save migration.

## Deferred

The artistic rebuild of high-risk locations is explicitly deferred to the later Visual & World Geometry Final QA stage.
Stable 1.21 does not claim the current high-risk visual pass as final art quality.

## Package staging verification

The final staging tree was re-run after removing `.godot/editor` while keeping the fresh imported cache:
SELFTEST OK; developer release guard 96/96; encounter balance 82/82; cold import guard 0 ERROR.
