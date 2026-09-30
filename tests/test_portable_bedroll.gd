extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(game.item_defs.has("bedroll"), "portable bedroll item missing")
    var bedroll = game.item_defs["bedroll"]
    check(str(bedroll.get("use","")) == "bedroll", "bedroll use type is not deployable rest")
    check(int(bedroll.get("w",0)) == 3 and int(bedroll.get("h",0)) == 1, "bedroll footprint changed")
    check(game._make_item_icon("bedroll") != null, "bedroll inventory art missing")
    check(game._make_world_loot_texture("bedroll") != null, "bedroll world-loot art missing")

    check(game._rest_source_rule_block("cot",1,false,"clear") != "", "cot must still require shelter")
    check(game._rest_source_rule_block("bedroll",1,false,"clear") == "", "bedroll must allow short dry field rest")
    check(game._rest_source_rule_block("bedroll",4,false,"cloudy") == "", "bedroll must allow four-hour dry field rest")
    check(game._rest_source_rule_block("bedroll",8,false,"clear") != "", "bedroll must not allow full outdoor sleep")
    check(game._rest_source_rule_block("bedroll",1,false,"rain") != "", "open rain must block bedroll sleep")
    check(game._rest_source_rule_block("bedroll",8,true,"rain") == "", "sheltered bedroll must allow full sleep")
    check(game._rest_source_quality_modifier("bedroll",true) < 0.0, "bedroll must remain worse than a fixed cot")
    check(game._rest_source_quality_modifier("bedroll",false) < game._rest_source_quality_modifier("bedroll",true), "outdoor bedroll rest needs an additional quality cost")

    game.base_objects = [{"id":77,"kind":"bedroll","x":12.0,"y":24.0,"rot":0.4}]
    game.next_base_id = 1
    game._sanitize_base_objects()
    check(game.base_objects.size() == 1 and str(game.base_objects[0].get("kind","")) == "bedroll", "base sanitizer deleted deployed bedroll")
    check(game.next_base_id >= 78, "base id sanitizer can reuse deployed bedroll id")
    check(str(game._base_object_name("bedroll")) == "ПОХОДНЫЙ СПАЛЬНИК", "bedroll world object name missing")
    check(int(game._base_refund_for("bedroll").get("bedroll",0)) == 1, "packing bedroll must return the item intact")

    # Direct REST UI packing path must return the same object, not salvage materials.
    game.inventory_entries = []
    game.rest_source_base_id = 77
    game.rest_open = true
    check(game._pack_current_bedroll(), "rest-panel packing action failed")
    check(game._inventory_count("bedroll") == 1, "packing did not return bedroll to inventory")
    check(game.base_objects.is_empty(), "packed bedroll remained in persistent world state")

    check(game.CONTAINER_W == 8 and game.CONTAINER_H == 8, "normal container grid changed")
    var qa_entries = game._generate_loot("qa:test:bedroll","all_items_test",game.QA_ALL_ITEMS_CONTAINER_W,game.QA_ALL_ITEMS_CONTAINER_H)
    var ids = {}
    for rec in qa_entries:
        ids[str(rec.get("id",""))] = true
    check(ids.has("bedroll"), "QA all-items catalogue missing bedroll")
    check(ids.size() == game.item_defs.size(), "QA all-items catalogue no longer fits full item set")

    game.free()
    print("PORTABLE BEDROLL: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
