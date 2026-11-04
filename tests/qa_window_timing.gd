extends SceneTree
# Perf QA (1.42): how long each window takes to open (the frame it opens in).
#   godot --headless --path . --script tests/qa_window_timing.gd
const Main = preload("res://main_script_mod.gd")
var game = null

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

func timed(name: String, open_fn: Callable, close_fn: Callable) -> void:
    var best = 1e9
    var worst = 0.0
    for i in range(4):
        var t = Time.get_ticks_usec()
        open_fn.call()
        var ms = (Time.get_ticks_usec() - t) / 1000.0
        best = min(best, ms)
        worst = max(worst, ms)
        await frames(2)
        close_fn.call()
        await frames(2)
    print("OPEN %-14s best %6.1f ms  worst %6.1f ms" % [name, best, worst])

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.field_hints.finish_steps()
    for id in ["bandage", "cloth", "scrap", "duct_tape", "alcohol", "nails", "wire", "tool_kit", "water", "canned_meat", "akm", "mosin", "field_backpack"]:
        game._grid_add(game.inventory_entries, id, 2, game.INV_W, game.INV_H)
    game._ensure_runtime_item_instance_ids()
    await timed("inventory", func(): game._toggle_inventory(), func(): game._close_inventory())
    await timed("craft_hand", func(): game._open_hand_crafting(), func(): game._close_crafting())
    game.crafting_station = "bench"
    await timed("craft_bench", func(): game._open_crafting(), func(): game._close_crafting())
    await timed("base_build", func(): game._open_base_build(), func(): game._close_base_build())
    await timed("region_map", func(): game._open_region_map(), func(): game._close_region_map())
    await timed("trader", func(): game._open_trader("lazaret_supplier"), func(): game._close_trader())
    await timed("contracts", func(): game._open_contract_board("lazaret", "Доктор Миронова", "lazaret_doctor"), func(): game._close_contract_board())
    # a frame of the HUD itself
    var t = Time.get_ticks_usec()
    for i in range(20):
        game._update_hud()
    print("HUD update      avg %6.2f ms" % ((Time.get_ticks_usec() - t) / 20000.0))
    quit(0)
