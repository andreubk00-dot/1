extends SceneTree
# Visual QA (1.42): every window and the HUD, screen by screen - a picture
# of each and a scan of every label and button for text that is cut off: by
# its own box (clip / ellipsis / hidden lines) or by a clipping parent.
# xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#   --script tests/qa_ui_text_scan.gd -- --qa-output=<dir>
const Main = preload("res://main_script_mod.gd")
var output = ""
var game = null
var shot = 0
var problems = 0

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await process_frame

static func text_problems(node: Control) -> Array:
    var out = []
    var text = ""
    if node is Label or node is Button:
        text = str(node.text)
    if text.strip_edges() == "":
        return out
    var font = node.get_theme_font("font")
    var fs = node.get_theme_font_size("font_size")
    if font == null:
        return out
    var lh = font.get_height(fs)
    var box = Rect2(Vector2.ZERO, node.size)
    var block = Rect2()
    if node is Label:
        lh += node.get_theme_constant("line_spacing")
        var lines = node.get_line_count()
        var vis = node.get_visible_line_count()
        if vis < lines:
            out.append("hidden lines %d/%d" % [vis, lines])
        var widest = 0.0
        if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
            for line in text.split("\n"):
                widest = max(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
        else:
            widest = min(node.size.x, font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, node.size.x, fs).x)
        var h = vis * lh - node.get_theme_constant("line_spacing")
        var y = 0.0
        if node.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
            y = floor((node.size.y - h) * 0.5)
        elif node.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
            y = node.size.y - h
        var x = 0.0
        if node.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
            x = (node.size.x - widest) * 0.5
        elif node.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
            x = node.size.x - widest
        block = Rect2(x, y, widest, h)
        if (node.clip_text or node.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) and widest > node.size.x + 0.5:
            out.append("trimmed %.0f>%.0f" % [widest, node.size.x])
        if node.clip_text and not box.grow(0.5).encloses(block):
            out.append("clipped by itself")
    else:
        var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        var icon_w = 0.0
        if node.icon != null:
            icon_w = node.icon.get_size().x + node.get_theme_constant("h_separation")
        var st = node.get_theme_stylebox("normal")
        var pad = Vector2(st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT), 0) if st != null else Vector2.ZERO
        if tw + icon_w + pad.x > node.size.x + 0.5 and (node.clip_text or node.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
            out.append("button trimmed")
        block = Rect2((node.size.x - tw) * 0.5, (node.size.y - lh) * 0.5, tw, lh)
        if lh > node.size.y + 0.5:
            out.append("button too low %.0f<%.0f" % [node.size.y, lh])
    # clipping parents (scroll lists clip on purpose: skip rows there)
    var xf = node.get_global_transform()
    var g = Rect2(xf * block.position, xf.basis_xform(block.size))
    var p = node.get_parent()
    while p != null and p is Control:
        if p is ScrollContainer:
            break
        if p.clip_contents:
            var pr = p.get_global_rect()
            if not pr.grow(0.5).encloses(g):
                out.append("cut by %s %s in %s" % [p.name, str(g), str(pr)])
                break
        p = p.get_parent()
    return out

func scan(screen: String) -> void:
    for n in root.find_children("*", "Control", true, false):
        if not (n is Label or n is Button):
            continue
        if not n.is_visible_in_tree() or n.modulate.a < 0.05:
            continue
        if n.get_theme_font_size("font_size") >= 16 and str(n.text) != "":
            print("BIG %s | %s | \"%s\" | fs=%d" % [screen, str(n.get_path()).replace("/root/", ""), str(n.text).left(40), n.get_theme_font_size("font_size")])
        var issues = text_problems(n)
        if issues.size() > 0:
            problems += 1
            if false and n.get_parent() is Control: print("DBG pos=%s size=%s min=%s fs=%d scale=%s ls=%d" % [n.position, n.size, n.get_minimum_size(), n.get_theme_font_size("font_size"), n.scale, n.get_theme_constant("line_spacing")] if n is Label else "")
            print("TEXT %s | %s | \"%s\" | %s" % [screen, str(n.get_path()).replace("/root/", ""), str(n.text).replace("\n", " / ").left(60), ", ".join(issues)])

func snap(name: String) -> void:
    await RenderingServer.frame_post_draw
    shot += 1
    if output != "":
        root.get_texture().get_image().save_png("%s/%02d_%s.png" % [output, shot, name])
    scan(name)

func find_npc(npc_id: String):
    for n in get_nodes_in_group("interactable"):
        if is_instance_valid(n) and str(n.get_meta("npc_id", "")) == npc_id:
            return n
    return null

func run():
    Engine.set_meta("ostatok_new_game", true)
    game = Main.new()
    root.add_child(game)
    await frames(10)
    game.developer_invulnerable = true
    game.field_hints.finish_steps()
    game.field_hints._queue.clear()
    game.world_minutes = 11.0 * 60.0
    for id in ["bandage", "cloth", "scrap", "duct_tape", "alcohol", "nails", "wire", "tool_kit", "water", "canned_meat"]:
        game._grid_add(game.inventory_entries, id, 3, game.INV_W, game.INV_H)
    game._ensure_runtime_item_instance_ids()
    game.field_hints.hint("qa_long", "W A S D — идти, Shift — бег, C — красться. Все клавиши: Esc → Настройки → Клавиши. Это длинная подсказка в две строки.")
    await frames(20)
    await snap("hud")
    game.field_hints._panel.visible = false
    game._toggle_inventory()
    await frames(6)
    game.selected_inventory_index = 0
    game._refresh_inventory_ui()
    await frames(3)
    await snap("inventory")
    game._close_inventory()
    await frames(3)
    game._open_hand_crafting()
    await frames(6)
    game.selected_recipe_id = "bandage" if game.recipe_defs.has("bandage") else game.recipe_defs.keys()[0]
    game._refresh_crafting_details()
    game._refresh_recipe_button_states()
    await frames(3)
    await snap("craft_hand")
    game._close_crafting()
    game._close_inventory()
    game.crafting_station = "bench"
    game._open_crafting()
    await frames(6)
    for rid in game.recipe_defs:
        if not game.recipe_defs[rid].get("tools", []).is_empty():
            game.selected_recipe_id = rid
            break
    if game.has_method("_refresh_crafting_details"):
        game._refresh_crafting_details()
    await frames(3)
    await snap("craft_bench")
    game._set_workbench_mode("salvage")
    await frames(3)
    for id in ["scrap", "cloth", "wire", "nails", "tool_kit"]:
        if game._is_salvageable(id):
            game._select_salvage_item(id)
            break
    await frames(3)
    await snap("craft_salvage")
    game._close_crafting()
    game._close_inventory()
    await frames(3)
    game._open_base_build()
    await frames(6)
    await snap("base_build")
    game._close_base_build()
    game._close_inventory()
    await frames(3)
    game._open_region_map()
    await frames(8)
    await snap("region_map")
    game._close_region_map()
    await frames(3)
    if game.weapon_defs.has(game.current_weapon_id):
        game._open_weapon_mod_panel(game.current_weapon_id, game.current_weapon_instance_id)
        await frames(6)
        await snap("weapon_mods")
        if game.has_method("_close_weapon_mod_panel"):
            game._close_weapon_mod_panel()
        game._close_inventory()
        await frames(3)
    # the Lazaret: a trader, the contract board, a talk
    var laz = game.RegionCatalog.poi_by_id(game.VerticalSlice.SETTLEMENT_ID).get("coord", Vector2i(-8, -2))
    game._qa_move_to_world_chunk(laz)
    await frames(60)
    game._open_trader("lazaret_supplier")
    await frames(8)
    await snap("trader")
    game._close_trader()
    await frames(3)
    game._open_contract_board("lazaret", "Доктор Миронова", "lazaret_doctor")
    await frames(8)
    await snap("contract_board")
    game._close_contract_board()
    await frames(3)
    game._open_world_chronicle()
    await frames(8)
    await snap("chronicle")
    if game.has_method("_close_world_chronicle"):
        game._close_world_chronicle()
    else:
        game._close_region_map()
    await frames(3)
    # the pause menu and its pages
    game._open_menu("pause")
    await frames(6)
    await snap("pause")
    var pm = game.pause_menu
    pm._open_settings("sound")
    await frames(4)
    await snap("settings_sound")
    for tab in ["display", "game", "keys"]:
        pm._select_tab(tab)
        await frames(4)
        await snap("settings_" + tab)
    pm._back_from_settings()
    await frames(2)
    pm._open_tips()
    await frames(4)
    await snap("tips")
    pm.close()
    await frames(3)
    print("UI TEXT SCAN: %d problems over %d screens" % [problems, shot])
    quit(0)
