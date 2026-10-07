# OSTATOK 1.37.0 — Final Release

`1.37.0` — финальный Stable release, продвигающий принятый `1.36.0-dev1` Release Candidate без новых gameplay-систем, контента или ребаланса.

## Release contract
- application/config/version: `1.37.0`;
- save schema: **122**, unchanged;
- developer/QA surface disabled because Stable version has no `-dev` suffix;
- exactly **16** authored named NPC remain in the faction roster;
- PNG source count remains **651** and source art is unchanged from the accepted RC;
- regional endgame remains consequence ending + continuing sandbox, without escape/path-out mechanics.

## Final promotion checks
Before promotion from RC:
- clean Godot 4.7.2 import: 651/651 `.ctex`, exit 0;
- supported full playthrough: 196/196;
- current-schema roundtrip: 42/42.

After version promotion, release gates pass: High Risk 130/130, Feature Lock 7/7, main SELFTEST OK with failures=0, named NPC state 105/105 and production save/load 8/8. No gameplay values are changed.

Further development is restricted to `1.37.x` critical hotfix/maintenance work.
