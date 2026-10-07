extends "res://main_script_mod.gd"
func _ready():
    set_process(false)
    _load_data()
    player=CharacterBody2D.new()
    add_child(player)
    player.global_position=Vector2(384,384)
    faction_state=FactionEconomy.default_state()
    expedition_journal=ExpeditionJournal.empty_state()
    equipment={}
    _ensure_equipment_slots()
