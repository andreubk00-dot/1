OSTATOK 0.55.0 — CHARACTER / INFECTED / INTERIOR POLISH

Visual/animation stage focused on silhouette quality, aiming rig, infected motion and clinic readability.

CHANGES
- New player upper-body atlas v19 with slimmer proportions, smaller helmet/head silhouette and a less box-shaped backpack.
- Firearm arms are no longer baked into the body atlas. Both arms are solved at runtime from shoulder -> elbow -> actual weapon grip points.
- Rear/front arm Z-order changes with aim direction, so aiming up/down no longer draws both arms on the wrong side of the torso.
- Firearm presentation rescaled: PM is visibly a sidearm rather than a rifle-sized slab; AKM/shotgun remain readable without covering the face.
- Reload pose moves the support hand to the actual reload point and bends the weapon inward.
- New infected_v11: four original infected identities, eight facing directions and eight gait frames per direction with more human proportions, smaller heads and asymmetrical damaged limbs.
- Infected gait phase now advances from actual travelled distance. Blocked infected no longer moonwalk while standing still.
- New medical/interior art pass: world_props_v16 and interior_floor_tiles_v2 add/redraw hospital bed, IV stand, wheelchair, cabinets, oxygen cylinder, med cart, privacy curtain, monitor, sink/counter, defibrillator, surgery lamp, linen, notice board, cable clutter and supply stacks.
- Clinic layout uses the new props and local warm detail lighting while preserving the existing building/collision logic.

BUG FIXES / QA
- Player visual QA now removes ambient infected before capture; they no longer overlap the character and invalidate silhouette review.
- Infected gallery clears procedural enemies before spawning deterministic QA variants.
- QA aim can now be locked to right/down/left/up; system mouse position no longer silently overwrites the requested direction.
- Added deterministic QA movement/sprint and moving-infected modes for animation testing.
- Reload QA now holds the mid-reload pose long enough for delayed engine screenshots.
- All active runtime PNG references were checked for missing files.

ENGINE VERIFICATION
- Godot 4.7.2 clean import and runtime SELFTEST.
- inventory / clinic / player / infected / facade / exterior QA modes.
- Extra strafe, sprint and moving-infected runtime modes.
- X11 engine-side screenshots used for four aim directions, reload, walking, sprinting, infected motion and clinic review.

ART / LICENSING
- User references were used only as art direction.
- No pixels or cut-out fragments from the supplied reference images are embedded in this build.
- No third-party art was added in this stage; the new assets were created specifically for OSTATOK.
- Existing project/application name is intentionally preserved for user:// save compatibility.
