# QA — OSTATOK 1.30.0-dev2 High Risk Visual Closure

## Engine

Godot `4.7.2.stable.official.ed1daf0bf`.
Engine ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

## Visual model coverage

`test_high_risk_visual_closure_130.gd` baseline:

- **494/494**;
- authored exterior models: **72/72**;
- High Risk atlas families: **4/4 unique**;
- every complex: six authored sectors and at least five distinct architecture signatures.

## Runtime capture

`qa_high_risk_capture.gd`:

- clinic: 13 daytime captures;
- quarantine: 13 daytime captures;
- Bastion: 13 daytime captures;
- Vector: 13 daytime captures;
- total: **52**.

The capture review found no evidence that warrants an asset rebuild. Connected High Risk masses are intentional architecture, not procedural building overlap.

## Boundary

Final post-version-bump results are recorded before packaging. No PNG or gameplay geometry changes are allowed in this slice.

## Final Godot 4.7.2 gates

- `test_high_risk_visual_closure_130.gd`: **494/494**.
- `test_high_risk_visual_multifloor.gd`: **130/130**.
- `test_world_geometry_final_audit_130.gd`: **6232/6232**.
- `main.tscn --qa-selftest-exit`: `OSTATOK 1.30.0-dev2 SELFTEST: OK`.
  The outer tool timeout occurred after the OK marker had already been written; the Godot process was no longer running when inspected.
- save schema: **122**.
- PNG assets: **651/651 byte-identical** to 1.30-dev1.
- gameplay GDScript changes vs dev1: **0**.
