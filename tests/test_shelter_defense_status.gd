extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var failures = 0
var checks = 0

func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    game.expedition_journal["home"] = {
        "key":"0:0:building_2","name":"Тестовый дом","chunk":[0,0],
        "position":[0.0,0.0],"bounds":[-50.0,-50.0,100.0,100.0]
    }
    game.roof_records = []
    game.shelter_breach_states = {
        "0:0:door:building_2":{"kind":"door","condition":50.0,"reinforced":false},
        "0:0:window:building_2:0":{"kind":"window","condition":70.0,"reinforced":false},
        "0:0:window:building_2:1":{"kind":"window","condition":110.0,"reinforced":true},
        "0:0:door:building_3":{"kind":"door","condition":0.0,"reinforced":false}
    }
    game.base_objects = [
        {"id":7,"kind":"barricade","x":0.0,"y":-45.0,"rot":0.0,"condition":0.0},
        {"id":8,"kind":"barricade","x":200.0,"y":200.0,"rot":0.0,"condition":0.0}
    ]

    var records = game._home_defense_records()
    check(records.size() == 4,"home defense must list only this home's door, windows and in-bounds barricades")
    check(str(records[0].get("kind","")) == "door","door must be the first defense row")
    check(abs(float(records[0].get("percent",0.0)) - 50.0) < 0.01,"door row must expose normalized HP")
    check(str(records[1].get("name","")) == "Окно 1 • южный фасад","window slot must have a stable human-readable name")
    check(int(round(float(records[2].get("maximum",0.0)))) == 110,"reinforced window must show 110 max HP")
    check(bool(records[2].get("reinforced",false)),"reinforced state must survive into the defense row")
    check(str(records[2].get("state","")) == "УКРЕПЛЕНО","full reinforced window must be labeled reinforced")
    check(str(records[3].get("kind","")) == "barricade","in-home barricade must be listed")
    check(str(records[3].get("state","")) == "ПРОЛОМ","zero-HP barricade must be labeled as a breach")
    check(str(records[3].get("name","")) == "Баррикада 1 • север","barricade must include a location hint")
    check(game._home_defense_state(records) == "КРИТИЧЕСКОЕ • ЕСТЬ ПРОЛОМ","overall shelter state must be verbal and breach-aware")
    check(game._home_defense_state(records).find("%") < 0,"overall shelter state must not expose an aggregate HP percentage")

    game.base_objects[0]["condition"] = 100.0
    game.shelter_breach_states["0:0:door:building_2"]["condition"] = 100.0
    var stable = game._home_defense_records()
    check(game._home_defense_state(stable) == "СТАБИЛЬНО","fully intact defense must report stable")

    game.shelter_breach_states["0:0:door:building_2"]["condition"] = 30.0
    var critical = game._home_defense_records()
    check(game._home_defense_state(critical) == "КРИТИЧЕСКОЕ","weak point below 35 percent must report critical without inventing a breach")

    game.home_defense_rows = VBoxContainer.new()
    game.add_child(game.home_defense_rows)
    game._home_defense_add_row(records[0])
    await process_frame
    var row = game.home_defense_rows.get_child(0)
    for child in row.get_children():
        if child is Label:
            check(abs(child.position.y + child.size.y * 0.5 - 10.0) < 0.1,"defense label must align with HP bar center")
            check(child.position.y >= 0.0 and child.position.y + child.size.y <= 20.0,"defense label must stay inside its row")

    game.free()
    print("SHELTER DEFENSE STATUS: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
