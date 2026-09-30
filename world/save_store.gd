extends RefCounted

# Write a complete temporary file before replacing the live save. A valid previous
# generation is retained separately; failed writes never truncate the live file.
static func _read_file(path:String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file = FileAccess.open(path,FileAccess.READ)
    if file == null:
        return {}
    var parser = JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {}
    var parsed = parser.data
    if typeof(parsed) != TYPE_DICTIONARY or parsed.is_empty():
        return {}
    if typeof(parsed.get("inventory_entries",null)) != TYPE_ARRAY:
        return {}
    for key in ["inventory_entries","dropped_items","base_objects"]:
        var entries = parsed.get(key,[])
        if typeof(entries) != TYPE_ARRAY:
            return {}
        for entry in entries:
            if typeof(entry) != TYPE_DICTIONARY:
                return {}
    for key in ["container_states","weapon_mags","weapon_mods","weapon_condition","equipment","door_states","picked_world_items","defeated"]:
        if typeof(parsed.get(key,{})) != TYPE_DICTIONARY:
            return {}
    for state in parsed.get("container_states",{}).values():
        if typeof(state) != TYPE_DICTIONARY or typeof(state.get("items",[])) != TYPE_ARRAY:
            return {}
        for entry in state.get("items",[]):
            if typeof(entry) != TYPE_DICTIONARY:
                return {}
    if parsed.has("weapon_instance_states"):
        if typeof(parsed.get("weapon_instance_states",{})) != TYPE_DICTIONARY:
            return {}
        for state in parsed.get("weapon_instance_states",{}).values():
            if typeof(state) != TYPE_DICTIONARY:
                return {}
            if typeof(state.get("mods",{})) != TYPE_DICTIONARY:
                return {}
    if parsed.has("current_weapon_instance_id") and typeof(parsed.get("current_weapon_instance_id","")) != TYPE_STRING:
        return {}
    if parsed.has("faction_state") and typeof(parsed.get("faction_state",{})) != TYPE_DICTIONARY:
        return {}
    return parsed

static func read_save(path:String) -> Dictionary:
    var current = _read_file(path)
    return current if not current.is_empty() else _read_file(path + ".bak")

static func write_save(path:String,data:Dictionary) -> bool:
    var temp_path = path + ".tmp"
    var file = FileAccess.open(temp_path,FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    var result = file.get_error()
    file.close()
    if result != OK:
        return false
    # Do not replace the recovery copy with a truncated/corrupt primary file.
    if not _read_file(path).is_empty():
        if DirAccess.copy_absolute(path,path + ".bak") != OK:
            return false
    return DirAccess.rename_absolute(temp_path,path) == OK
