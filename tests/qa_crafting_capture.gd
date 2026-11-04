extends SceneTree
# Visual QA (1.40): crafting by hand, at a workbench (a ready recipe, one from
# an unread schematic), the build panel with the workbench, a schematic's tooltip.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_crafting_capture.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var game = null
var shot = 0

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    shot += 1
    root.get_texture().get_image().save_png("%s/%02d_%s.png" % [output, shot, name])
    print("SHOT ", name, " status=", game.craft_status.text if game.craft_status != null else "")

func run():
    game = Main.new()
    root.add_child(game)
    await frames(20)
    game.developer_invulnerable = true
    game.world_minutes = 12.0 * 60.0
    for it in [["cloth", 5], ["tape", 3], ["scrap", 6], ["nails", 3], ["alcohol", 1], ["firewood", 2], ["gunpowder", 1], ["sch_tailor", 1]]:
        game._grid_add(game.inventory_entries, it[0], it[1], game.INV_W, game.INV_H)
    for g in ["field_backpack"]:
        game._equip_item(g)
    game._refresh_inventory_ui()
    game._open_hand_crafting()
    await frames(10)
    await snap("hand")
    game._select_recipe("field_bandage")
    await frames(5)
    await snap("hand_bandage")
    game._close_crafting()
    game.crafting_station = "bench"
    game._open_crafting()
    await frames(10)
    game._select_recipe("suppressor")
    await frames(5)
    await snap("bench_locked")
    game._select_recipe("field_rig")
    await frames(5)
    await snap("bench_tailor_locked")
    game._close_crafting()
    game._open_base_build()
    await frames(10)
    await snap("base_build")
    game._close_base_build()
    game._toggle_inventory()
    await frames(5)
    for i in range(game.inventory_entries.size()):
        if str(game.inventory_entries[i].get("id", "")) == "sch_tailor":
            game._hover_show_item("sch_tailor", 1, "storage")
    await frames(5)
    await snap("schematic_tooltip")
    quit(0)
