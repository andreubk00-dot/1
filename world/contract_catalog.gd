extends RefCounted

# OSTATOK 1.22-dev5 — authored faction contracts and explicit inter-faction choices.
# Templates describe intent and rewards; contract_system.gd owns lifecycle/state.
const BOARDS = {
    "perron_steward":{"faction":"perron","name":"Вера Андреевна","label":"ХОЗЯЙСТВЕННЫЕ ПОРУЧЕНИЯ"},
    "rubezh_dispatch":{"faction":"rubezh","name":"Ирина","label":"ДИСПЕТЧЕРСКАЯ РУБЕЖА"},
    "mechanics_electrician":{"faction":"mechanics","name":"Гена","label":"ЗАКАЗЫ АРТЕЛИ"},
    "lazaret_doctor":{"faction":"lazaret","name":"Доктор Миронова","label":"СНАБЖЕНИЕ ЛАЗАРЕТА"},

    # 1.23-dev4: authored personal boards live on non-trader named residents so the
    # settlement gains new reasons to revisit without stealing an existing shop interaction.
    "perron_radio":{"faction":"perron","name":"Лёнька","label":"ЛИЧНЫЙ ЭФИР","personal":true},
    "rubezh_commander":{"faction":"rubezh","name":"Капитан Орлов","label":"ПОРУЧЕНИЯ ОРЛОВА","personal":true},
    "mechanics_storekeeper":{"faction":"mechanics","name":"Клык","label":"ПОРУЧЕНИЯ КЛЫКА","personal":true},
    "lazaret_researcher":{"faction":"lazaret","name":"Аркадий","label":"ПОРУЧЕНИЯ АРКАДИЯ","personal":true}
}

# requirements for delivery contracts are alternatives: satisfying any inner array is valid.
# Discovery contracts deliberately provide verbal hints instead of exact map coordinates.
const TEMPLATES = {
    "perron_food_reserve":{
        "faction":"perron","title":"КУХОННЫЙ РЕЗЕРВ","kind":"delivery","need_key":"food","min_rep":0,
        "description":"Кухня Перрона просит пополнить общий запас до следующей поставки.",
        "hint":"Подойдут консервы или зерно — везти можно тем, что удалось найти.",
        "requirements":[[{"id":"canned_meat","qty":6}],[{"id":"grain","qty":10}]],
        "reward":{"tickets":52,"reputation":8,"resources":{"food":14.0}}
    },
    "perron_waterworks":{
        "faction":"perron","title":"ВОДОНАПОРНАЯ","kind":"delivery","need_key":"technical","min_rep":25,
        "description":"Водяной узел работает на изношенных фильтрах и латках. Нужны расходники для ремонта.",
        "hint":"Можно привезти новые фильтры либо собрать ремонтный комплект из доступных материалов.",
        "requirements":[[{"id":"water_filter","qty":2}],[{"id":"scrap","qty":10},{"id":"tape","qty":4}]],
        "reward":{"tickets":78,"reputation":10,"resources":{"technical":12.0,"food":5.0}}
    },
    "perron_zarya_route":{
        "faction":"perron","title":"ДОРОГА К «ЗАРЕ»","kind":"discover_poi","need_key":"security","min_rep":8,"starter_recon":true,
        "description":"Перрон хочет вернуть гражданский путь через дачные массивы: продукты, воду и безопасные ночёвки вне города.",
        "hint":"Проверь СНТ «Заря» западнее города и вернись с наблюдениями. Это сравнительно тихий район, но территория большая. Точная точка не отмечается.",
        "poi_id":"dacha_coop_zarya",
        "reward":{"tickets":86,"reputation":11,"resources":{"security":10.0,"food":5.0},"route":{"id":"route_perron_zarya","beneficiaries":["perron"],"daily_resources":{"food":0.35,"security":0.25}}}
    },

    "rubezh_ammo_reserve":{
        "faction":"rubezh","title":"ПАТРУЛЬНЫЙ РЕЗЕРВ","kind":"delivery","need_key":"security","min_rep":0,
        "description":"Патрули расходуют боезапас быстрее, чем приходит снабжение.",
        "hint":"Нужен массовый пистолетный боезапас либо дробовые патроны для постов.",
        "requirements":[[{"id":"ammo_9x18","qty":30}],[{"id":"ammo_12g","qty":14}]],
        "reward":{"tickets":74,"reputation":9,"resources":{"security":13.0}}
    },
    "rubezh_police_route":{
        "faction":"rubezh","title":"СТАРЫЙ ПОЛИЦЕЙСКИЙ МАРШРУТ","kind":"discover_poi","need_key":"security","min_rep":9,"starter_recon":true,
        "description":"Диспетчерская хочет восстановить безопасный коридор через старый районный отдел и проверить, остались ли там служебные резервы.",
        "hint":"Найди районный отдел полиции в западной панельной застройке и осмотри подходы. Риск выше дач: двор тесный и подходы хуже просматриваются.",
        "poi_id":"district_police",
        "reward":{"tickets":94,"reputation":12,"resources":{"security":14.0,"technical":3.0},"route":{"id":"route_rubezh_police","beneficiaries":["rubezh","perron"],"daily_resources":{"security":0.45}}}
    },
    "rubezh_east_checkpoint":{
        "faction":"rubezh","title":"КПП «ВОСТОК»","kind":"discover_poi","need_key":"technical","min_rep":75,
        "description":"Рубеж планирует дальние патрули к старому военному КПП, но давно не имеет сведений о секторе.",
        "hint":"Проверь военный КПП «Восток» на северо-восточном направлении. Это опасный маршрут.",
        "poi_id":"military_checkpoint",
        "reward":{"tickets":138,"reputation":15,"resources":{"security":18.0,"technical":8.0},"route":{"id":"route_rubezh_east","beneficiaries":["rubezh","mechanics"],"daily_resources":{"security":0.55,"technical":0.20}}}
    },

    "mechanics_pump_repair":{
        "faction":"mechanics","title":"НАСОС НА ВОДООЧИСТКЕ","kind":"delivery","need_key":"technical","min_rep":0,
        "description":"На старом насосе снова разваливается привод. Артели нужен ремонтный набор или материалы для переборки.",
        "hint":"Можно отдать готовые ремкомплекты либо принести металл и ленту — Артель соберёт узел сама.",
        "requirements":[[{"id":"repair_kit","qty":2}],[{"id":"scrap","qty":12},{"id":"tape","qty":4}]],
        "reward":{"tickets":82,"reputation":9,"resources":{"technical":16.0}}
    },
    "mechanics_rail_depot":{
        "faction":"mechanics","title":"ДЕПО: ПРОВЕРКА ПОДХОДОВ","kind":"discover_poi","need_key":"security","min_rep":9,"starter_recon":true,
        "description":"Артель хочет снова вывозить тяжёлые детали и ремонтные узлы из железнодорожного депо.",
        "hint":"Осмотри железнодорожное депо у промышленной ветки и оцени, можно ли провести грузовую группу. Это самый опасный из первых самостоятельных маршрутов.",
        "poi_id":"rail_depot",
        "reward":{"tickets":98,"reputation":12,"resources":{"technical":12.0,"security":7.0},"route":{"id":"route_mechanics_depot","beneficiaries":["mechanics","perron"],"daily_resources":{"technical":0.50,"security":0.20}}}
    },
    "mechanics_factory":{
        "faction":"mechanics","title":"КОМБИНАТ №7","kind":"discover_poi","need_key":"technical","min_rep":75,
        "description":"Саныч считает, что на Промкомбинате №7 ещё остались пригодные промышленные узлы.",
        "hint":"Найди Промкомбинат №7 в промышленном поясе и вернись после разведки территории.",
        "poi_id":"factory_7",
        "reward":{"tickets":132,"reputation":14,"resources":{"technical":18.0},"route":{"id":"route_mechanics_factory","beneficiaries":["mechanics"],"daily_resources":{"technical":0.65}}}
    },

    "lazaret_dressing_supply":{
        "faction":"lazaret","title":"ПЕРЕВЯЗОЧНАЯ","kind":"delivery","need_key":"medicine","min_rep":0,
        "description":"Лазарету нужны материалы для ежедневной перевязочной работы.",
        "hint":"Примут обычные бинты либо меньший набор стерильных материалов с антисептиком.",
        "requirements":[[{"id":"bandage","qty":8}],[{"id":"sterile_bandage","qty":4},{"id":"antiseptic","qty":2}]],
        "reward":{"tickets":68,"reputation":9,"resources":{"medicine":15.0}}
    },
    "lazaret_hospital_route":{
        # dev12: this is the first natural sandbox reconnaissance after a successful
        # Lazaret vertical slice. The recovered first convoy + emergency delivery
        # reaches this threshold without granting any free reputation.
        "faction":"lazaret","title":"РАЙОННАЯ БОЛЬНИЦА","kind":"discover_poi","need_key":"medicine","min_rep":10,"starter_recon":true,
        "description":"Медики хотят восстановить вылазки к районной больнице за расходниками и резервами для тяжёлых случаев.",
        "hint":"Найди районную больницу на восточной стороне города и проверь пути к хозяйственному двору. Ожидай средний риск и тесные лечебные корпуса.",
        "poi_id":"district_hospital",
        "reward":{"tickets":96,"reputation":12,"resources":{"medicine":14.0,"security":5.0},"route":{"id":"route_lazaret_hospital","beneficiaries":["lazaret"],"daily_resources":{"medicine":0.55,"security":0.15}}}
    },
    "lazaret_quarantine_recon":{
        "faction":"lazaret","title":"КАРАНТИН №12","kind":"discover_poi","need_key":"security","min_rep":75,
        "description":"Лазарету нужны актуальные сведения о карантинном центре №12 перед медицинской экспедицией.",
        "hint":"Найди внешний сектор карантинного центра. Это дальняя и опасная задача; проникать глубже ради отчёта не требуется.",
        "poi_id":"quarantine_center_12",
        "reward":{"tickets":142,"reputation":15,"resources":{"medicine":16.0,"security":9.0},"route":{"id":"route_lazaret_quarantine","beneficiaries":["lazaret","rubezh"],"daily_resources":{"medicine":0.45,"security":0.35}}}
    },

    # 1.23-dev4 — personal, authored 2-step chains. These are deliberately separate
    # from the rotating faction board: one named resident owns the story, offers expire
    # quickly, accepted work has a real deadline, and abandoning/failing has consequences.
    "perron_radio_backup_power":{
        "faction":"perron","owner_npc_id":"perron_radio","chain_id":"perron_radio_net","chain_step":1,
        "title":"ЭФИР: РЕЗЕРВНОЕ ПИТАНИЕ","kind":"delivery","need_key":"technical","min_rep":25,
        "description":"Лёнька пытается держать приёмник включённым ночью, когда общая сеть проседает. Ему нужен отдельный резерв для радиорубки.",
        "hint":"Это личное поручение: оно не висит на общем хозяйственном стенде. После ремонта Лёнька хочет проверить старую ведомственную частоту.",
        "requirements":[[{"id":"repair_kit","qty":1},{"id":"scrap","qty":5}],[{"id":"scrap","qty":9},{"id":"tape","qty":3},{"id":"flashlight","qty":1}]],
        "offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":7,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-3,"attitude":-7,"resources":{"technical":-2.0}},
        "reward":{"tickets":54,"reputation":6,"resources":{"technical":5.0,"security":2.0}}
    },
    "perron_radio_dead_frequency":{
        "faction":"perron","owner_npc_id":"perron_radio","chain_id":"perron_radio_net","chain_step":2,
        "requires_completed":["perron_radio_backup_power"],"once_completed":true,
        "title":"ЭФИР: МЁРТВАЯ ЧАСТОТА","kind":"discover_poi","need_key":"security","min_rep":25,
        "description":"После ремонта Лёнька поймал обрывки ведомственного сигнала. Источник похож на старую полицейскую сеть — нужно понять, осталось ли там что-то рабочее.",
        "hint":"Проверь районный отдел полиции в западной панельной застройке и вернись. Точной метки Лёнька дать не может.",
        "poi_id":"district_police","offer_lifetime_days":2,"active_lifetime_days":5,"npc_attitude_reward":9,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-4,"attitude":-8,"resources":{"security":-2.0}},
        "reward":{"tickets":82,"reputation":8,"resources":{"security":7.0,"technical":4.0},
            "route":{"id":"route_perron_warning_net","kind":"comms","beneficiaries":["perron","rubezh"],"daily_resources":{"security":0.16,"food":0.06}}}
    },

    "rubezh_commander_missing_post":{
        "faction":"rubezh","owner_npc_id":"rubezh_commander","chain_id":"rubezh_forward_watch","chain_step":1,
        "title":"ОРЛОВ: ПРОПАВШИЙ ПОСТ","kind":"discover_poi","need_key":"security","min_rep":25,
        "description":"Один из дальних постов Рубежа перестал выходить на связь. Орлов не просит геройствовать — ему нужна подтверждённая обстановка на старом охотничьем кордоне.",
        "hint":"Найди охотничий кордон и осмотри район. Если место уже известно, достаточно вернуться с актуальным докладом.",
        "poi_id":"hunting_cordon","offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":7,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-4,"attitude":-7,"resources":{"security":-3.0}},
        "reward":{"tickets":66,"reputation":7,"resources":{"security":6.0}}
    },
    "rubezh_commander_forward_cache":{
        "faction":"rubezh","owner_npc_id":"rubezh_commander","chain_id":"rubezh_forward_watch","chain_step":2,
        "requires_completed":["rubezh_commander_missing_post"],"once_completed":true,
        "title":"ОРЛОВ: ПЕРЕДОВОЙ ЗАПАС","kind":"delivery","need_key":"security","min_rep":25,
        "description":"Кордоном снова можно пользоваться, но без отдельного запаса патруль будет каждый раз возвращаться за мелочами. Орлов просит собрать комплект для скрытого поста.",
        "hint":"Подойдёт лёгкий боезапас с перевязкой либо дробовые патроны с ремонтным комплектом.",
        "requirements":[[{"id":"ammo_9x18","qty":24},{"id":"bandage","qty":3}],[{"id":"ammo_12g","qty":10},{"id":"repair_kit","qty":1}]],
        "offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":9,
        "abandon_penalty":{"reputation":-2,"attitude":-5},
        "failure_penalty":{"reputation":-5,"attitude":-9,"resources":{"security":-3.0}},
        "reward":{"tickets":92,"reputation":9,"resources":{"security":9.0},
            "route":{"id":"route_rubezh_cordon_watch","kind":"patrol","beneficiaries":["rubezh"],"daily_resources":{"security":0.22}}}
    },

    "mechanics_storekeeper_haul_gear":{
        "faction":"mechanics","owner_npc_id":"mechanics_storekeeper","chain_id":"mechanics_heavy_haul","chain_step":1,
        "title":"КЛЫК: ТЯЖЁЛАЯ ТЕЛЕЖКА","kind":"delivery","need_key":"technical","min_rep":25,
        "description":"Клык собрал раму для грузовой тележки, но без нормальных креплений она развалится на первом же разбитом переезде.",
        "hint":"Нужен один хороший ремкомплект и металл — либо больше сырья и ленты, если готового комплекта нет.",
        "requirements":[[{"id":"repair_kit","qty":1},{"id":"scrap","qty":7}],[{"id":"scrap","qty":13},{"id":"tape","qty":4}]],
        "offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":7,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-3,"attitude":-7,"resources":{"technical":-3.0}},
        "reward":{"tickets":62,"reputation":6,"resources":{"technical":7.0}}
    },
    "mechanics_storekeeper_depot_run":{
        "faction":"mechanics","owner_npc_id":"mechanics_storekeeper","chain_id":"mechanics_heavy_haul","chain_step":2,
        "requires_completed":["mechanics_storekeeper_haul_gear"],"once_completed":true,
        "title":"КЛЫК: ПРОБНЫЙ ВЫВОЗ","kind":"discover_poi","need_key":"technical","min_rep":25,
        "description":"Тележка готова. Клык хочет проверить, можно ли протащить её к железнодорожному депо и обратно без потери колёс и груза.",
        "hint":"Осмотри железнодорожное депо и подходы. Если ты уже бывал там раньше, достаточно нового прохода и доклада Клыку.",
        "poi_id":"rail_depot","offer_lifetime_days":2,"active_lifetime_days":5,"npc_attitude_reward":9,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-4,"attitude":-8,"resources":{"technical":-3.0}},
        "reward":{"tickets":88,"reputation":8,"resources":{"technical":10.0,"security":3.0},
            "route":{"id":"route_mechanics_handcart","kind":"salvage","beneficiaries":["mechanics"],"daily_resources":{"technical":0.20}}}
    },

    "lazaret_researcher_old_archive":{
        "faction":"lazaret","owner_npc_id":"lazaret_researcher","chain_id":"lazaret_field_archive","chain_step":1,
        "title":"АРКАДИЙ: СТАРЫЙ АРХИВ","kind":"discover_poi","need_key":"medicine","min_rep":25,
        "description":"Аркадий ищет старые журналы приёмного отделения. Не сами бумаги, а подтверждение, что центральная клиника ещё доступна для коротких вылазок.",
        "hint":"Проверь центральную клинику и вернись. Глубокая зачистка не требуется — важен сам доступ к объекту.",
        "poi_id":"central_clinic","offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":7,
        "abandon_penalty":{"reputation":-1,"attitude":-4},
        "failure_penalty":{"reputation":-3,"attitude":-7,"resources":{"medicine":-2.0}},
        "reward":{"tickets":68,"reputation":7,"resources":{"medicine":6.0,"security":2.0}}
    },
    "lazaret_researcher_field_series":{
        "faction":"lazaret","owner_npc_id":"lazaret_researcher","chain_id":"lazaret_field_archive","chain_step":2,
        "requires_completed":["lazaret_researcher_old_archive"],"once_completed":true,
        "title":"АРКАДИЙ: ПОЛЕВАЯ СЕРИЯ","kind":"delivery","need_key":"medicine","min_rep":25,
        "description":"По старым записям Аркадий собрал упрощённый протокол обработки ран. Для пробной серии нужны расходники, которые Лазарет не может бездумно снять с дежурного резерва.",
        "hint":"Стерильные материалы предпочтительнее; обычная перевязка тоже подойдёт, но потребует больше антисептика.",
        "requirements":[[{"id":"sterile_bandage","qty":4},{"id":"antiseptic","qty":3}],[{"id":"bandage","qty":8},{"id":"antiseptic","qty":4},{"id":"painkillers","qty":2}]],
        "offer_lifetime_days":2,"active_lifetime_days":4,"npc_attitude_reward":9,
        "abandon_penalty":{"reputation":-2,"attitude":-5},
        "failure_penalty":{"reputation":-5,"attitude":-9,"resources":{"medicine":-3.0}},
        "reward":{"tickets":94,"reputation":9,"resources":{"medicine":11.0},
            "route":{"id":"route_lazaret_field_protocol","kind":"medical_protocol","beneficiaries":["lazaret","perron"],"daily_resources":{"medicine":0.18}}}
    },

    # 1.22-dev5: these pairs are mutually exclusive world decisions. The player sees both
    # sides before committing; completion permanently records one outcome and removes the other.
    "perron_rail_allocation":{
        "faction":"perron","title":"ГРУЗОВАЯ ВЕТКА: ПРОВИАНТ","kind":"delivery","need_key":"food","min_rep":75,"priority_bonus":18.0,
        "description":"Перрон просит закрепить ближайшую грузовую ветку за гражданскими поставками: продовольствием и водой.",
        "hint":"Это спор с Артелью. Если Перрон получит приоритет, Механикам придётся искать другую тяжёлую логистику.",
        "requirements":[[{"id":"canned_meat","qty":6},{"id":"water","qty":6}],[{"id":"grain","qty":12},{"id":"water","qty":6}]],
        "reward":{"tickets":105,"reputation":12,"resources":{"food":12.0,"technical":4.0}},
        "conflict":{"id":"rail_allocation","opposes":"mechanics","choice":"civilian_priority","loser_reputation":-8,"relation_delta":-18,
            "resource_effects":{"perron":{"food":6.0},"mechanics":{"technical":-4.0}}}
    },
    "mechanics_rail_allocation":{
        "faction":"mechanics","title":"ГРУЗОВАЯ ВЕТКА: ТЯЖЁЛЫЙ ГРУЗ","kind":"delivery","need_key":"technical","min_rep":75,"priority_bonus":18.0,
        "description":"Артель хочет закрепить грузовую ветку за металлом, станками и тяжёлыми деталями.",
        "hint":"Это спор с Перроном. Приоритет Артели ускорит ремонт и производство, но гражданские поставки уйдут на более длинный путь.",
        "requirements":[[{"id":"repair_kit","qty":2},{"id":"scrap","qty":8}],[{"id":"scrap","qty":18},{"id":"tape","qty":4}]],
        "reward":{"tickets":112,"reputation":12,"resources":{"technical":16.0}},
        "conflict":{"id":"rail_allocation","opposes":"perron","choice":"industrial_priority","loser_reputation":-8,"relation_delta":-18,
            "resource_effects":{"mechanics":{"technical":7.0},"perron":{"food":-4.0}}}
    },
    "rubezh_quarantine_policy":{
        "faction":"rubezh","title":"КАРАНТИН: ЖЁСТКИЙ КОРДОН","kind":"delivery","need_key":"security","min_rep":75,"priority_bonus":18.0,
        "description":"Рубеж требует закрыть подходы к карантинной зоне и отдать приоритет патрулям и инженерным постам.",
        "hint":"Лазарет настаивает на медицинском коридоре. Этот контракт означает поддержку силового варианта.",
        "requirements":[[{"id":"ammo_9x18","qty":40},{"id":"repair_kit","qty":1}],[{"id":"ammo_12g","qty":18},{"id":"scrap","qty":6}]],
        "reward":{"tickets":118,"reputation":12,"resources":{"security":16.0,"technical":3.0}},
        "conflict":{"id":"quarantine_policy","opposes":"lazaret","choice":"hard_cordon","loser_reputation":-9,"relation_delta":-20,
            "resource_effects":{"rubezh":{"security":6.0},"lazaret":{"medicine":-3.0}}}
    },
    "lazaret_quarantine_policy":{
        "faction":"lazaret","title":"КАРАНТИН: МЕДИЦИНСКИЙ КОРИДОР","kind":"delivery","need_key":"medicine","min_rep":75,"priority_bonus":18.0,
        "description":"Лазарет просит закрепить безопасное окно для санитарных групп и эвакуации пациентов из карантинной зоны.",
        "hint":"Рубеж требует полного кордона. Этот контракт означает поддержку медицинского доступа вместо жёсткой блокады.",
        "requirements":[[{"id":"sterile_bandage","qty":5},{"id":"antiseptic","qty":3}],[{"id":"bandage","qty":10},{"id":"antibiotics","qty":2}]],
        "reward":{"tickets":116,"reputation":12,"resources":{"medicine":16.0,"security":3.0}},
        "conflict":{"id":"quarantine_policy","opposes":"rubezh","choice":"medical_corridor","loser_reputation":-9,"relation_delta":-20,
            "resource_effects":{"lazaret":{"medicine":6.0},"rubezh":{"security":-3.0}}}
    }
    ,

    # 1.22-dev8: trusted-faction endgame chains. Each faction gets three irreversible
    # late-game steps. Endgame availability/progression is enforced by faction_endgame.gd.
    "perron_endgame_common_warehouse":{
        "faction":"perron","title":"ОБЩИЙ СКЛАД","kind":"delivery","need_key":"food","min_rep":150,"priority_bonus":52.0,
        "description":"Вера Андреевна предлагает перевести Перрон с разовых поставок на общий резерв для кухни, воды и обмена между семьями.",
        "hint":"Для запуска склада нужен крупный запас продовольствия и воды. При полном кризисе сначала придётся стабилизировать поселение.",
        "requirements":[[{"id":"canned_meat","qty":10},{"id":"water","qty":10}],[{"id":"grain","qty":18},{"id":"water","qty":10}]],
        "reward":{"tickets":140,"reputation":12,"resources":{"food":18.0,"security":4.0}},
        "endgame":{"chain":"perron_network","step":1,"required_resources":{"food":20.0,"security":20.0}}
    },
    "perron_endgame_motor_pool":{
        "faction":"perron","title":"ТРАНСПОРТНЫЙ РЕЗЕРВ","kind":"discover_poi","need_key":"technical","min_rep":150,"priority_bonus":54.0,
        "description":"Перрону нужен резерв старых машин и деталей, чтобы перестать зависеть от одного грузового плеча.",
        "hint":"Проверь гаражный кооператив «Север» и отметь пригодные боксы и подъезды.",
        "poi_id":"garage_coop_sever",
        "reward":{"tickets":165,"reputation":14,"resources":{"technical":12.0,"security":7.0}},
        "endgame":{"chain":"perron_network","step":2,"required_resources":{"technical":25.0,"food":25.0}}
    },
    "perron_endgame_civilian_exchange":{
        "faction":"perron","title":"ГРАЖДАНСКИЙ ОБМЕННЫЙ ФОНД","kind":"delivery","need_key":"food","min_rep":150,"priority_bonus":58.0,
        "description":"Последний этап: сформировать запас, из которого Перрон сможет поддерживать регулярный гражданский обмен с соседями.",
        "hint":"Решение необратимо. Перрон сблизится с Лазаретом, но Рубеж будет недоволен самостоятельной гражданской логистикой.",
        "requirements":[[{"id":"repair_kit","qty":2},{"id":"canned_meat","qty":8},{"id":"bandage","qty":4}],[{"id":"scrap","qty":12},{"id":"grain","qty":14},{"id":"bandage","qty":4}]],
        "reward":{"tickets":220,"reputation":20,"resources":{"food":20.0,"medicine":8.0,"technical":8.0},"route":{"id":"route_perron_civilian_exchange","beneficiaries":["perron","lazaret"],"daily_resources":{"food":0.25,"medicine":0.12}}},
        "endgame":{"chain":"perron_network","step":3,"required_resources":{"food":35.0,"technical":35.0,"security":25.0},"final":true}
    },

    "rubezh_endgame_bastion":{
        "faction":"rubezh","title":"РЕЗЕРВНЫЙ АРСЕНАЛ","kind":"discover_poi","need_key":"security","min_rep":150,"priority_bonus":52.0,
        "description":"Орлов хочет понять, можно ли использовать старый укреплённый арсенал как внешний резерв для гарнизона.",
        "hint":"Разведай резервный арсенал «Бастион». Это поздняя и опасная точка.",
        "poi_id":"reserve_arsenal_bastion",
        "reward":{"tickets":170,"reputation":13,"resources":{"security":16.0,"technical":5.0}},
        "endgame":{"chain":"rubezh_network","step":1,"required_resources":{"security":20.0,"medicine":20.0}}
    },
    "rubezh_endgame_perimeter_supply":{
        "faction":"rubezh","title":"ПЕРИМЕТР: РЕЗЕРВ ПОСТОВ","kind":"delivery","need_key":"security","min_rep":150,"priority_bonus":54.0,
        "description":"Для постоянной сети постов нужен запас боеприпасов и ремонтных материалов, который не будет расходоваться обычными патрулями.",
        "hint":"Если безопасность или технический запас провалены, сначала восстанови снабжение гарнизона.",
        "requirements":[[{"id":"ammo_762","qty":20},{"id":"repair_kit","qty":2}],[{"id":"ammo_545","qty":20},{"id":"scrap","qty":10},{"id":"tape","qty":4}]],
        "reward":{"tickets":178,"reputation":15,"resources":{"security":20.0,"technical":8.0}},
        "endgame":{"chain":"rubezh_network","step":2,"required_resources":{"security":25.0,"technical":25.0}}
    },
    "rubezh_endgame_patrol_grid":{
        "faction":"rubezh","title":"СЕТЬ ПАТРУЛЬНЫХ ПОСТОВ","kind":"delivery","need_key":"security","min_rep":150,"priority_bonus":58.0,
        "description":"Последний этап: развернуть постоянный резерв для дальних постов и связать его с ремонтниками Артели.",
        "hint":"Решение необратимо. Рубеж сблизится с Механиками, а Перрон воспримет усиление контроля на дорогах настороженно.",
        "requirements":[[{"id":"ammo_9x18","qty":50},{"id":"bandage","qty":6},{"id":"tape","qty":4}],[{"id":"ammo_12g","qty":20},{"id":"repair_kit","qty":2},{"id":"bandage","qty":4}]],
        "reward":{"tickets":235,"reputation":20,"resources":{"security":22.0,"technical":9.0},"route":{"id":"route_rubezh_patrol_grid","beneficiaries":["rubezh","mechanics"],"daily_resources":{"security":0.25,"technical":0.10}}},
        "endgame":{"chain":"rubezh_network","step":3,"required_resources":{"security":35.0,"technical":35.0},"final":true}
    },

    "mechanics_endgame_sever":{
        "faction":"mechanics","title":"«СЕВЕР»: РЕЗЕРВ БОКСОВ","kind":"discover_poi","need_key":"technical","min_rep":150,"priority_bonus":52.0,
        "description":"Саныч хочет вернуть в работу часть гаражного кооператива как внешний склад и место разборки техники.",
        "hint":"Осмотри гаражный кооператив «Север» и отметь подходящие боксы.",
        "poi_id":"garage_coop_sever",
        "reward":{"tickets":160,"reputation":13,"resources":{"technical":17.0,"security":5.0}},
        "endgame":{"chain":"mechanics_network","step":1,"required_resources":{"technical":20.0,"security":20.0}}
    },
    "mechanics_endgame_vector":{
        "faction":"mechanics","title":"«ВЕКТОР»: ИНЖЕНЕРНЫЕ ДАННЫЕ","kind":"discover_poi","need_key":"technical","min_rep":150,"priority_bonus":54.0,
        "description":"Артель считает, что подземный объект «Вектор» может дать схемы и узлы для устойчивого ремонтного контура.",
        "hint":"Найди подземный объект «Вектор» и вернись после разведки внешнего доступа.",
        "poi_id":"underground_object_vector",
        "reward":{"tickets":205,"reputation":16,"resources":{"technical":20.0,"security":6.0}},
        "endgame":{"chain":"mechanics_network","step":2,"required_resources":{"technical":25.0,"security":25.0}}
    },
    "mechanics_endgame_repair_network":{
        "faction":"mechanics","title":"РЕМОНТНЫЙ КОНТУР","kind":"delivery","need_key":"technical","min_rep":150,"priority_bonus":58.0,
        "description":"Последний этап: собрать расходный резерв и запустить постоянную сеть ремонта для экспедиций и соседних поселений.",
        "hint":"Решение необратимо. Рубеж оценит устойчивую ремонтную сеть, Перрону не понравится приоритет тяжёлой техники.",
        "requirements":[[{"id":"repair_kit","qty":4},{"id":"scrap","qty":18},{"id":"tape","qty":6}],[{"id":"water_filter","qty":4},{"id":"scrap","qty":20},{"id":"flashlight","qty":2}]],
        "reward":{"tickets":245,"reputation":20,"resources":{"technical":24.0,"security":7.0},"route":{"id":"route_mechanics_repair_network","beneficiaries":["mechanics","rubezh"],"daily_resources":{"technical":0.28,"security":0.08}}},
        "endgame":{"chain":"mechanics_network","step":3,"required_resources":{"technical":35.0,"security":30.0},"final":true}
    },

    "lazaret_endgame_clinical_complex":{
        "faction":"lazaret","title":"КЛИНИЧЕСКИЙ КОМПЛЕКС №4","kind":"discover_poi","need_key":"medicine","min_rep":150,"priority_bonus":52.0,
        "description":"Миронова хочет восстановить связь с крупным клиническим комплексом и понять, что ещё можно вывезти для долгой работы Лазарета.",
        "hint":"Разведай региональный клинический комплекс №4 и оцени хозяйственные входы.",
        "poi_id":"regional_clinical_complex_4",
        "reward":{"tickets":178,"reputation":14,"resources":{"medicine":18.0,"security":5.0}},
        "endgame":{"chain":"lazaret_network","step":1,"required_resources":{"medicine":20.0,"security":20.0}}
    },
    "lazaret_endgame_sterile_reserve":{
        "faction":"lazaret","title":"СТЕРИЛЬНЫЙ РЕЗЕРВ","kind":"delivery","need_key":"medicine","min_rep":150,"priority_bonus":54.0,
        "description":"Перед развёртыванием постоянной медицинской сети Лазарету нужен неприкосновенный запас стерильных материалов и препаратов.",
        "hint":"Если медицина уже в кризисе, сначала подними обычный резерв — этот этап не должен съесть последние расходники.",
        "requirements":[[{"id":"sterile_bandage","qty":8},{"id":"antiseptic","qty":5},{"id":"antibiotics","qty":3}],[{"id":"bandage","qty":14},{"id":"antiseptic","qty":6},{"id":"painkillers","qty":6}]],
        "reward":{"tickets":190,"reputation":15,"resources":{"medicine":22.0,"food":5.0}},
        "endgame":{"chain":"lazaret_network","step":2,"required_resources":{"medicine":25.0,"food":20.0}}
    },
    "lazaret_endgame_medical_network":{
        "faction":"lazaret","title":"МЕДИЦИНСКАЯ СЕТЬ","kind":"delivery","need_key":"medicine","min_rep":150,"priority_bonus":58.0,
        "description":"Последний этап: собрать резерв для регулярной помощи соседним поселениям и санитарных выездов.",
        "hint":"Решение необратимо. Перрон поддержит медицинский обмен, Рубеж будет недоволен расширением самостоятельных санитарных коридоров.",
        "requirements":[[{"id":"trauma_kit","qty":2},{"id":"antibiotics","qty":4},{"id":"water","qty":8}],[{"id":"sterile_bandage","qty":10},{"id":"antiseptic","qty":6},{"id":"water","qty":10}]],
        "reward":{"tickets":240,"reputation":20,"resources":{"medicine":24.0,"food":7.0},"route":{"id":"route_lazaret_medical_network","beneficiaries":["lazaret","perron"],"daily_resources":{"medicine":0.25,"food":0.10}}},
        "endgame":{"chain":"lazaret_network","step":3,"required_resources":{"medicine":35.0,"food":30.0,"security":25.0},"final":true}
    }

}

static func board_for_npc(npc_id:String) -> Dictionary:
    return BOARDS.get(npc_id,{}).duplicate(true)

static func board_faction(npc_id:String) -> String:
    return str(BOARDS.get(npc_id,{}).get("faction",""))

static func is_personal_board(npc_id:String) -> bool:
    return bool(BOARDS.get(npc_id,{}).get("personal",false))

static func personal_board_npcs() -> Array:
    var out = []
    for raw_npc_id in BOARDS.keys():
        var npc_id = str(raw_npc_id)
        if is_personal_board(npc_id):
            out.append(npc_id)
    out.sort()
    return out

static func _crisis_template(faction_id:String,resource_id:String) -> Dictionary:
    var requirements = {
        "food":[[{"id":"canned_meat","qty":5},{"id":"water","qty":4}],[{"id":"grain","qty":10},{"id":"water","qty":4}]],
        "medicine":[[{"id":"bandage","qty":8},{"id":"antiseptic","qty":2}],[{"id":"sterile_bandage","qty":4},{"id":"painkillers","qty":3}]],
        "technical":[[{"id":"scrap","qty":12},{"id":"tape","qty":4}],[{"id":"repair_kit","qty":2},{"id":"water_filter","qty":1}]],
        "security":[[{"id":"ammo_9x18","qty":30},{"id":"bandage","qty":3}],[{"id":"ammo_12g","qty":12},{"id":"repair_kit","qty":1}]]
    }
    var titles = {"food":"АВАРИЙНЫЙ ЗАПАС: ПРОДОВОЛЬСТВИЕ","medicine":"АВАРИЙНЫЙ ЗАПАС: МЕДИЦИНА","technical":"АВАРИЙНЫЙ ЗАПАС: РЕМОНТ","security":"АВАРИЙНЫЙ ЗАПАС: БЕЗОПАСНОСТЬ"}
    var descriptions = {
        "food":"Запасы поселения опустились ниже безопасного уровня. Нужна срочная поставка еды и воды.",
        "medicine":"Медицинский резерв почти исчерпан. Нужны расходники до следующего штатного снабжения.",
        "technical":"Ремонтный запас просел. Без деталей и расходников начнут останавливаться бытовые и защитные системы.",
        "security":"Патрульный резерв истощён. Нужны боеприпасы и полевые расходники для удержания периметра."
    }
    if resource_id not in requirements:
        return {}
    var resource_reward = {}
    resource_reward[resource_id] = 18.0
    return {
        "template_id":"crisis_%s_%s" % [faction_id,resource_id],"faction":faction_id,
        "title":titles[resource_id],"kind":"delivery","need_key":resource_id,"min_rep":0,
        "crisis_only":true,"priority_bonus":0.0,
        "description":descriptions[resource_id],
        "hint":"Это аварийный заказ: он появляется только при реальном дефиците ресурса поселения.",
        "requirements":requirements[resource_id].duplicate(true),
        "reward":{"tickets":82,"reputation":8,"resources":resource_reward}
    }

static func template(template_id:String) -> Dictionary:
    var out = TEMPLATES.get(template_id,{}).duplicate(true)
    if out.is_empty() and template_id.begins_with("crisis_"):
        for faction_id in ["perron","rubezh","mechanics","lazaret"]:
            for resource_id in ["food","medicine","technical","security"]:
                if template_id == "crisis_%s_%s" % [faction_id,resource_id]:
                    return _crisis_template(faction_id,resource_id)
    if not out.is_empty():
        out["template_id"] = template_id
    return out

static func templates_for_faction(faction_id:String) -> Array:
    var out = []
    for template_id in TEMPLATES.keys():
        var raw = TEMPLATES[template_id]
        if str(raw.get("faction","")) != faction_id or str(raw.get("owner_npc_id","")) != "":
            continue
        var entry = raw.duplicate(true)
        entry["template_id"] = str(template_id)
        out.append(entry)
    for resource_id in ["food","medicine","technical","security"]:
        out.append(_crisis_template(faction_id,resource_id))
    return out

static func personal_templates_for_npc(npc_id:String) -> Array:
    var out = []
    for template_id in TEMPLATES.keys():
        var raw = TEMPLATES[template_id]
        if str(raw.get("owner_npc_id","")) != npc_id:
            continue
        var entry = raw.duplicate(true)
        entry["template_id"] = str(template_id)
        out.append(entry)
    out.sort_custom(func(a,b):
        var sa = int(a.get("chain_step",0))
        var sb = int(b.get("chain_step",0))
        if sa != sb:
            return sa < sb
        return str(a.get("template_id","")) < str(b.get("template_id",""))
    )
    return out
