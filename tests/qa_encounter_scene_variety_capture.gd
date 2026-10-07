extends SceneTree
# Visual QA entry point for 1.24-dev2. Intended for Godot 4.7.2 capture runs.
# The runtime gate remains separate from static release packaging.
const EncounterSceneVariety = preload("res://world/encounter_scene_variety.gd")
func _initialize() -> void:
    for event_id in EncounterSceneVariety.SUPPORTED_EVENTS:
        for variant in range(EncounterSceneVariety.VARIANT_COUNT):
            print("CAPTURE REQUIRED: ",event_id," variant ",variant)
    quit(0)
