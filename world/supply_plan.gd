extends RefCounted

# Data-only advisory templates; inventory authority performs the actual transfers.
const PRESETS = ["КОРОТКИЙ ВЫХОД","ДНЕВНАЯ ВЫЛАЗКА","ДАЛЬНИЙ ВЫХОД"]

static func groups(preset,ammo_id = "",mag_capacity = 0) -> Array:
    var level = clamp(int(preset),0,2)
    var result = [
        {"name":"Питьевая вода","ids":["water","herbal_tea"],"target":level + 1,"loaded":0},
        {"name":"Готовая еда","ids":["canned_meat","hot_meal","emergency_ration"],"target":level + 1,"loaded":0},
        {"name":"Перевязка","ids":["bandage","sterile_bandage"],"target":level + 2,"loaded":0}
    ]
    if ammo_id != "" and mag_capacity > 0:
        result.append({"name":"Боезапас","ids":[ammo_id],"target":int(mag_capacity) * (level + 1),"loaded":0})
    return result

static func count(entries,ids) -> int:
    var total = 0
    for entry in entries:
        if str(entry.get("id","")) in ids:
            total += max(0,int(entry.get("qty",1)))
    return total

static func remaining(entries,group) -> int:
    return max(0,int(group["target"]) - count(entries,group["ids"]) - int(group.get("loaded",0)))
