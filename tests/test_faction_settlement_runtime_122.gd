extends SceneTree
const Main = preload("res://main_script_mod.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const ContractCatalog = preload("res://world/contract_catalog.gd")

var checks := 0
var failures := 0
func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = Main.new()
    root.add_child(game)
    await process_frame
    var total_npcs := 0
    var total_traders := 0
    var total_contract_boards := 0
    var total_general_boards := 0
    var total_personal_boards := 0
    for faction_id in FactionCatalog.ids():
        var settlement_id = str(FactionCatalog.faction(faction_id).get("settlement_id",""))
        var poi = RegionCatalog.poi_by_id(settlement_id)
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        var faction_npcs := 0
        var faction_traders := 0
        var faction_contract_boards := 0
        var faction_general_boards := 0
        var faction_personal_boards := 0
        for offset in FactionSettlementCatalog.footprint(settlement_id):
            var coord = anchor + offset
            if game.loaded_chunks.has(coord):
                game._unload_chunk(coord)
                await process_frame
            game._load_chunk(coord)
            await process_frame
            var chunk = game.loaded_chunks.get(coord)
            check(is_instance_valid(chunk),settlement_id + " runtime chunk failed to load at " + str(offset))
            if not is_instance_valid(chunk):
                continue
            var enemies := 0
            var containers := 0
            var world_loot := 0
            var npcs := 0
            var traders := 0
            var contract_boards := 0
            for child in chunk.get_children():
                if child.has_meta("is_enemy"):
                    enemies += 1
                if child.has_meta("container_key"):
                    containers += 1
                if child.has_meta("item_id"):
                    world_loot += 1
                if child.is_in_group("faction_npcs"):
                    npcs += 1
                    if str(child.get_meta("trader_id","")) != "":
                        traders += 1
                    if str(child.get_meta("interaction_type","")) == "contract_board":
                        contract_boards += 1
                        var board = ContractCatalog.board_for_npc(str(child.get_meta("npc_id","")))
                        if bool(board.get("personal",false)):
                            faction_personal_boards += 1
                        else:
                            faction_general_boards += 1
            check(enemies == 0,settlement_id + " spawned ambient infected at " + str(offset))
            check(containers == 0,settlement_id + " exposed free authored loot container at " + str(offset))
            check(world_loot == 0,settlement_id + " exposed free ground loot at " + str(offset))
            faction_npcs += npcs
            faction_traders += traders
            faction_contract_boards += contract_boards
            game._unload_chunk(coord)
            await process_frame
        check(faction_npcs == 4,settlement_id + " runtime named NPC count mismatch")
        check(faction_traders == 2,settlement_id + " runtime trader count mismatch")
        check(faction_contract_boards == 2,settlement_id + " must place one general and one personal contract giver")
        check(faction_general_boards == 1,settlement_id + " must keep exactly one general faction contract giver")
        check(faction_personal_boards == 1,settlement_id + " must place exactly one personal contract giver in dev4")
        total_npcs += faction_npcs
        total_traders += faction_traders
        total_contract_boards += faction_contract_boards
        total_general_boards += faction_general_boards
        total_personal_boards += faction_personal_boards
    check(total_npcs == 16,"four settlements must place 16 named NPCs in dev3")
    check(total_traders == 8,"four settlements must place 8 physical traders in dev3")
    check(total_contract_boards == 8,"four settlements must place 8 physical contract givers in dev4")
    check(total_general_boards == 4,"four settlements must retain 4 general contract givers")
    check(total_personal_boards == 4,"four settlements must add 4 personal contract givers in dev4")
    game.queue_free()
    await process_frame
    print("FACTION SETTLEMENT RUNTIME 1.23-dev4: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
