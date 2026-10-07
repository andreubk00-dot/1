extends SceneTree
const WorldChronicle = preload("res://world/world_chronicle.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")

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
    var state = FactionEconomy.default_state()
    check(state.has("world_chronicle"),"default faction state must contain world chronicle")
    check(WorldChronicle.entries(state).is_empty(),"new chronicle must start empty")

    var first = WorldChronicle.append(state,3,75,"supply","perron","Перрон: рейс не вышел\nна связь.")
    check(not first.is_empty(),"chronicle append failed")
    check(str(first.get("text","")).find("\n") < 0,"chronicle text must be single-line sanitized")
    check(WorldChronicle.unread_count(state) == 1,"new chronicle entry must be unread")

    var duplicate = WorldChronicle.append(state,3,75,"supply","perron","Перрон: рейс не вышел на связь.")
    check(int(duplicate.get("serial",0)) == int(first.get("serial",0)),"identical same-day message must deduplicate")
    check(WorldChronicle.entries(state).size() == 1,"deduplicated message must not grow history")

    for i in range(70):
        WorldChronicle.append(state,4 + i,0,"world","","Сообщение %d" % i)
    check(WorldChronicle.entries(state,100).size() == WorldChronicle.HISTORY_LIMIT,"chronicle history limit broken")
    check(WorldChronicle.unread_count(state) > 0,"unread count disappeared after history rotation")
    WorldChronicle.mark_read(state)
    check(WorldChronicle.unread_count(state) == 0,"mark_read must clear unread count")

    var roundtrip = FactionEconomy.sanitize_state(state)
    check(roundtrip.has("world_chronicle"),"faction sanitize dropped world chronicle")
    check(WorldChronicle.entries(roundtrip,100).size() == WorldChronicle.HISTORY_LIMIT,"faction sanitize changed chronicle history")
    check(WorldChronicle.unread_count(roundtrip) == 0,"faction sanitize changed read position")
    var text = WorldChronicle.entry_text(WorldChronicle.entries(roundtrip,1)[0])
    check(text.begins_with("ДЕНЬ ") and text.find("•") >= 0,"chronicle display text malformed")

    print("WORLD CHRONICLE 1.23-dev2: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
