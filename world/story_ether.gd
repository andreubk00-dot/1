extends RefCounted
# dev68: «ЭФИР» - the narrative thread (docs/STORY_ETHER.md). Six traces of why
# the region fell apart: an evacuation broadcast from the underground node
# «Вектор» has looped «stay where you are, wait for transport» for three weeks.
# Narrative only - no trace unlocks items, routes or access. Read traces live in
# the chronicle's story_seen list (WorldChronicle); this module keeps the
# catalogue, the soft hint and the choice at the console.

const TAG = "4-117"

# readable traces placed in the world: chunk coord -> clue (pos in chunk space)
const NOTES = {
    "0,0": {
        "id":"ether_1_tag","title":"Талон эвакуации","prompt":"ТАЛОН",
        "text":"«Пункт сбора №4 (поликлиника). Талон 4-117. Ожидайте транспорт на месте, пункт не покидать. — Штаб ГО». На обороте карандашом: «Ждём девятый день. Колонна не пришла.»",
        "prop_kind":"paper_stack","scale":0.40,"pos":Vector2(352,452)
    },
    "-2,-1": {
        "id":"ether_3_relay","title":"Паспорт ретранслятора","prompt":"ПАСПОРТ",
        "text":"«Ретранслятор оповещения ГО. Приём — с узла «Вектор», передача — автоматически. Отключение — только с пульта узла.» Ниже: «Выдернули питание — через минуту включился сам.»",
        "prop_kind":"newspapers","scale":0.38,"pos":Vector2(300,452)
    },
    "13,2": {
        "id":"ether_5_raiders","title":"Записка радиста","prompt":"ЗАПИСКА",
        "text":"«Седой велел частоту ГО не глушить. Пока крутят „оставайтесь на местах“, люди по квартирам сидят — заходи и бери. Нам эта запись дороже патронов.»",
        "prop_kind":"paper_stack","scale":0.38,"pos":Vector2(600,724)
    }
}

# the column on the western road: placed beside the convoy wreck (world event)
const COLUMN_NOTE = {
    "coord":Vector2i(-5,1),"event_id":"looted_convoy",
    "id":"ether_4_column","title":"Путевой лист «Запад-3»","prompt":"ПУТЕВОЙ",
    "text":"«Колонна „Запад-3“. Приказ по эфиру: вернуться к пунктам сбора и ждать. Пункт №4 — 31 талон, в т. ч. 4-117. Стоим вторые сутки, связи нет — только эта запись.»",
    "prop_kind":"paper_stack","scale":0.40,"offset":Vector2(-34,-46)
}

# heard, not read: the first talk with Лёнька on the Perron
const VOICE = {
    "id":"ether_2_voice","title":"Голос в эфире",
    "text":"Лёнька поймал ведомственную частоту: «Эвакуация продолжается. Оставайтесь на местах». Запись крутится по кругу третью неделю. Кто-то же её включил."
}

const SOURCE = {
    "id":"ether_6_source","title":"Пульт оповещения",
    "text":"На «Векторе» живо одно оповещение: цикл 47 секунд, последняя правка — в ночь, когда смена не спустилась. Эту запись и слышит весь регион."
}

const CONSOLE_POS = Vector2(-250,-70)     # deep core, beside the engineers' log
const CONSOLE_FLOOR = 3
const CONSOLE_POI = "underground_object_vector"

const CONSOLE_TEXT = "Резервный контур держит одну систему — оповещение. На экране цикл 47 секунд:\n«Эвакуация продолжается. Оставайтесь на местах. Ожидайте транспорт.»\nПоследняя правка — за подписью дежурного, в ночь, когда смена не спустилась.\nЗаписать поверх — или выключить?"

const CHOICES = {
    "truth":{
        "label":"ЗАПИСАТЬ ПРАВДУ",
        "broadcast":"Говорит выживший с пункта сбора №4. Эвакуации не будет. Не ждите. Идите к людям: Перрон у железной дороги, Рубеж на северо-востоке, Механики на востоке, Лазарет на западе. Там открыто.",
        "title":"Новый голос",
        "text":"В эфире ГО теперь другая запись: эвакуации не будет, не ждите — идите к людям. Голос твой.",
        "resources":{"security":6.0,"food":3.0},
        "roaming":0.85,
        "epilogue":"Над регионом звучит новый голос: не ждите, идите к людям. Люди с окраин приходят в поселения — кто сам, кто с этим голосом в приёмнике."
    },
    "silence":{
        "label":"ВЫКЛЮЧИТЬ",
        "broadcast":"",
        "title":"Тишина",
        "text":"Оповещение ГО замолчало. Три недели одна и та же фраза — и вдруг ничего. Кто ждал, теперь решает сам.",
        "resources":{"security":2.0},
        "roaming":1.0,
        "epilogue":"Эфир ГО молчит. Больше никто не просит ждать — и никто не говорит, куда идти."
    }
}
const UNCHANGED_EPILOGUE = "А в эфире всё так же крутится: «Оставайтесь на местах. Ожидайте транспорт»."

# Лёнька's line as the thread goes on
const LENKA = {
    "start":"Слышишь? Опять крутят: «Оставайтесь на местах». Третью неделю одно и то же. Кто-то же это включил.",
    "voice":"Сигнал не наш, ведомственный. Похоже, идёт через старую полицейскую сеть — отдел на западе.",
    "relay":"Так это «Вектор»... Выходит, под землёй что-то ещё работает. И кто-то должен был это выключить.",
    "truth":"Слышал? В эфире новый голос — «не ждите, идите к людям». С окраин уже потянулись. Это же ты, да?",
    "silence":"Тишина в эфире. Странно — я по этой записи почти скучаю."
}

# the soft hint: shown only when the survivor has no other goal at all
const HINTS = [
    ["ether_2_voice", "Радист Перрона ловит странный эфир"],
    ["ether_3_relay", "Откуда сигнал? Лёнька грешит на отдел полиции на западе"],
    ["ether_6_source", "Источник эфира — объект «Вектор», глубина −3"],
]


static func default_state() -> Dictionary:
    return {"choice":"", "choice_day":0}


static func sanitize(raw) -> Dictionary:
    var clean = default_state()
    if typeof(raw) != TYPE_DICTIONARY:
        return clean
    var c = str(raw.get("choice",""))
    clean["choice"] = c if c in ["", "truth", "silence"] else ""
    clean["choice_day"] = max(0, int(raw.get("choice_day", 0)))
    return clean


static func note_for_chunk(coord:Vector2i) -> Dictionary:
    return NOTES.get("%d,%d" % [coord.x, coord.y], {}).duplicate(true)


static func trace_ids() -> Array:
    var out = []
    for n in NOTES.values():
        out.append(str(n["id"]))
    out.append(str(COLUMN_NOTE["id"]))
    out.append(str(VOICE["id"]))
    out.append(str(SOURCE["id"]))
    return out


static func is_trace(story_id:String) -> bool:
    return story_id.begins_with("ether_")


static func hint(seen:Callable, choice:String) -> String:
    # the next step of the thread, or "" when it is done
    if choice != "":
        return ""
    for row in HINTS:
        if not bool(seen.call(str(row[0]))):
            return str(row[1])
    return "Пульт оповещения ждёт на «Векторе», глубина −3"


static func lenka_line(seen:Callable, choice:String) -> String:
    if choice == "truth" or choice == "silence":
        return LENKA[choice]
    if bool(seen.call("ether_3_relay")):
        return LENKA["relay"]
    if bool(seen.call(VOICE["id"])):
        return LENKA["voice"]
    return LENKA["start"]


static func epilogue(choice:String) -> String:
    if CHOICES.has(choice):
        return str(CHOICES[choice]["epilogue"])
    return UNCHANGED_EPILOGUE
