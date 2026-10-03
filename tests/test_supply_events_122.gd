extends SceneTree
const FactionEconomy = preload("res://world/faction_economy.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")

var failures := 0
var checks := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func _force_event(state:Dictionary,day:int = 4) -> Dictionary:
    SupplyEventSystem.ensure_state(state,1)
    state["supply_events"]["active"] = {}
    state["supply_events"]["next_event_day"] = day
    var result = SupplyEventSystem.daily_tick(state,day)
    return result.get("event",{})

func run() -> void:
    var state = FactionEconomy.default_state()
    check(state.has("supply_events"),"supply event state must live inside faction_state")
    var initial_next = int(state["supply_events"].get("next_event_day",0))
    check(initial_next >= 4 and initial_next <= 7,"first supply incident must be scheduled 3-6 days out")

    var created = _force_event(state,4)
    check(not created.is_empty(),"due supply event was not created")
    check(str(created.get("stage","")) == "distress","new event must begin as distress")
    check(int(created.get("expires_day",0)) == 7,"event lifetime must be three days")
    var faction_id = str(created.get("faction",""))
    check(not FactionCatalog.faction(faction_id).is_empty(),"event faction invalid")
    var coord = SupplyEventSystem.active_coord(state,4)
    check(coord.x < 900000,"active event coord missing")
    check(RegionCatalog.poi_for_chunk(coord).is_empty(),"supply event must not overwrite an authored POI")
    var runtime = SupplyEventSystem.runtime_event_for_chunk(state,coord,4)
    check(str(runtime.get("id","")) == "supply_convoy","runtime scene id mismatch")
    check(bool(runtime.get("supply_event",false)),"runtime scene missing supply-event tag")
    check(int(runtime.get("enemy_count",0)) >= 3,"distress scene lacks threat")
    check("SOS" in SupplyEventSystem.marker_label(state,4),"fresh event marker must communicate SOS")

    var day5 = SupplyEventSystem.daily_tick(state,5)
    check(bool(day5.get("stage_changed",false)),"event did not age to overrun state")
    check(str(SupplyEventSystem.active_event(state,5).get("stage","")) == "overrun","day+1 stage mismatch")
    check("НЕТ СВЯЗИ" in SupplyEventSystem.marker_label(state,5),"overrun marker copy mismatch")
    var day6 = SupplyEventSystem.daily_tick(state,6)
    check(bool(day6.get("stage_changed",false)),"event did not age to looted state")
    check(str(SupplyEventSystem.active_event(state,6).get("stage","")) == "looted","day+2 stage mismatch")
    check("РАЗГРОМ" in SupplyEventSystem.marker_label(state,6),"looted marker copy mismatch")

    # Rescue reward decays as the player arrives later.
    var early = FactionEconomy.default_state()
    var early_event = _force_event(early,4)
    var early_result = SupplyEventSystem.resolve_success(early,str(early_event.get("id","")),4)
    check(bool(early_result.get("ok",false)),"fresh convoy could not be recovered")
    check(int(early_result.get("reputation",0)) == 8,"fresh rescue reputation mismatch")
    check(int(early_result.get("tickets",0)) == 28,"fresh rescue ticket reward mismatch")
    check(early["supply_events"]["active"].is_empty(),"resolved event remained active")
    check(str(early["supply_events"]["history"][-1].get("outcome","")) == "recovered","recovery missing from history")

    var late = FactionEconomy.default_state()
    var late_event = _force_event(late,4)
    SupplyEventSystem.daily_tick(late,5)
    SupplyEventSystem.daily_tick(late,6)
    var late_result = SupplyEventSystem.resolve_success(late,str(late_event.get("id","")),6)
    check(bool(late_result.get("ok",false)),"looted-stage recovery failed")
    check(float(late_result.get("resource_gain",0.0)) < float(early_result.get("resource_gain",0.0)),"late arrival must save less cargo")
    check(int(late_result.get("reputation",0)) < int(early_result.get("reputation",0)),"late arrival must grant less reputation")

    # Ignoring a convoy costs both its cargo resource and settlement security.
    var ignored = FactionEconomy.default_state()
    var ignored_event = _force_event(ignored,4)
    var ignored_faction = str(ignored_event.get("faction",""))
    var resource_id = str(ignored_event.get("cargo_resource",""))
    var resource_before = float(ignored["factions"][ignored_faction]["resources"][resource_id])
    var security_before = float(ignored["factions"][ignored_faction]["resources"]["security"])
    SupplyEventSystem.daily_tick(ignored,5)
    SupplyEventSystem.daily_tick(ignored,6)
    var expired = SupplyEventSystem.daily_tick(ignored,7)
    check(bool(expired.get("expired",false)),"ignored convoy did not expire")
    check(ignored["supply_events"]["active"].is_empty(),"expired convoy remained active")
    check(float(ignored["factions"][ignored_faction]["resources"][resource_id]) < resource_before,"lost convoy did not reduce cargo resource")
    check(float(ignored["factions"][ignored_faction]["resources"]["security"]) < security_before,"lost convoy did not reduce security")
    check(str(ignored["supply_events"]["history"][-1].get("outcome","")) == "lost","lost convoy missing from history")
    var next_day = int(ignored["supply_events"].get("next_event_day",0))
    check(next_day >= 10 and next_day <= 13,"next incident must be rescheduled 3-6 days after closure")

    # The state survives the same JSON/sanitize path as normal saves.
    var roundtrip = FactionEconomy.sanitize_state(JSON.parse_string(JSON.stringify(state)))
    check(str(SupplyEventSystem.active_event(roundtrip,6).get("id","")) == str(created.get("id","")),"active incident lost across save roundtrip")
    check(SupplyEventSystem.active_coord(roundtrip,6) == coord,"incident coordinate lost across save roundtrip")

    # Player bases are accepted as blocked sectors when a fresh road incident is placed.
    var blocked_state = FactionEconomy.default_state()
    SupplyEventSystem.ensure_state(blocked_state,1)
    blocked_state["supply_events"]["next_event_day"] = 4
    var unblocked_probe = SupplyEventSystem.daily_tick(blocked_state,4)
    var first_coord = SupplyEventSystem.active_coord(blocked_state,4)
    var retry = FactionEconomy.default_state()
    SupplyEventSystem.ensure_state(retry,1)
    retry["supply_events"]["next_event_day"] = 4
    SupplyEventSystem.daily_tick(retry,4,[first_coord])
    check(SupplyEventSystem.active_coord(retry,4) != first_coord,"incident placement ignored blocked player-base sector")

    print("RANDOM SUPPLY EVENTS 1.22-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
