# QA — OSTATOK 1.37.1 Stable Hotfix

## Reproduction
На `1.37.0` обычный verbose main-scene shutdown воспроизводил 8 leaked ObjectDB instances и
4 resources still in use — ровно четыре ambience WAV и четыре `AudioStreamPlaybackWAV`.

## Fix verification
- main scene, verbose shutdown after fix: exit 0, no ObjectDB/resource leak warnings;
- ambience runtime: **41/41**;
- ambience save boundary: **6/6**.

Старый standalone ambience QA harness может вывести собственный teardown warning при немедленном
`quit()`; production main shutdown проверен отдельным реальным запуском и clean.

## Invariants
- save schema: **122**;
- no gameplay/balance/content/art change;
- historical `1.22.0 Stable` gates remain untouched;
- only current High Risk version gate follows `1.37.1`.

## Post-version gates
- current High Risk multifloor/version gate: **130/130**;
- main SELFTEST: `OSTATOK 1.37.1 SELFTEST: OK`;
- `QA_SELFTEST_EXIT: failures=0`.

