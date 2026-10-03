# OSTATOK 1.22.0 Stable — QA Summary

- Godot: 4.7.2 Stable official `ed1daf0bf`
- Project version: `1.22.0`
- Main-scene smoke: PASS (`OSTATOK 1.22.0 SELFTEST: OK`)
- Stable release gate: 23 / 23
- Standard regression scripts: 72 PASS
- Standard regression checks: 19 047
- Failures: 0
- RC balance soak retained: 7 891 / 7 891
- Legacy faction save migration retained: 15 / 15
- Save schema: 122, unchanged
- Stable developer guard: PASS; F10 developer action/UI absent by default
- Source visual assets checked: 644
- Visual source changes vs unpacked dev9 RC: 0
- Godot/project ERROR lines in import/smoke/regression logs: 0
- Expected environment warning in headless logs: process is running as root/superuser
- `test_infected_navigation.gd`: intentionally outside standard batch; navigation code unchanged in 1.22 stabilization.
