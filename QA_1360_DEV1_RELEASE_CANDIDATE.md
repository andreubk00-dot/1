# QA — 1.36.0-dev1 Release Candidate

Godot: 4.7.2 stable official `ed1daf0bf`.
Engine ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

## Clean import / playthrough
- clean import: exit 0; imported PNG `.ctex`: 651;
- supported full playthrough: 196/196;
- strained full playthrough: 197/197;
- unsupported full playthrough: 197/197.

## Save / recovery
- release-candidate save migration: 15/15;
- save recovery: 18/18;
- migration boundaries: 42/42;
- malformed save matrix: 39/39;
- current-schema composite matrix: 42/42;
- expedition save integration: 54/54.

## Gameplay / long-session
- trading economy: 512/512;
- High Risk visual closure: 494/494;
- long-session chunk churn: 201/201, loaded max 9, pending max 0, nodes 7616 -> 7616;
- entity cleanup: 170/170, nodes 4 -> 4;
- production save stress: 50/50, stable 251539-byte payload across rewrites;
- mixed long-session closure: 82/82, fully materialized/revisit save 252012/252012 bytes.

## Geometry / visual QA
- world geometry final audit: 6232/6232;
- High Risk runtime captures: 52 total, 13 each for Clinical Complex #4, Quarantine Center 12,
  Reserve Arsenal Bastion and Underground Object Vector;
- captures reviewed with no new clipping/geometry regression requiring asset changes.

## Audio regression
- UI feedback: 35/35;
- weapon audio: 113/113;
- weapon action cycles: 48/48;
- world interaction SFX: 68/68;
- infected combat SFX: 44/44;
- ambience: 41/41;
- audio closure save-boundary: 6/6.

Headless/Xvfb runs may report known immediate-shutdown ObjectDB/resource warnings; Xvfb also falls
back to dummy audio in this container. Functional test exit codes and assertions above are clean.

## Release invariants
- save schema: 122;
- no new gameplay mechanics;
- no balance changes after 1.35 Balance Lock;
- historical `1.22.0 Stable` gates remain historical and untouched;
- current version metadata: 1.36.0-dev1;
- PNG art is not modified by this slice.

Final post-version-bump gates, package integrity and SHA-256 are recorded after packaging.

## Final post-version-bump gates
- High Risk current-version visual/multifloor: 130/130;
- main selftest: `OSTATOK 1.36.0-dev1 SELFTEST: OK`;
- `QA_SELFTEST_EXIT: failures=0`, process exit 0;
- feature-lock release surface: 7/7;
- named NPC state: 105/105; default roster assertion confirms 16 authored NPC records.
