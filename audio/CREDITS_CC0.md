# Звуки и музыка — источники (все CC0)

Все записи ниже опубликованы авторами под **CC0 1.0 (общественное достояние)**:
их можно свободно использовать, менять и распространять, в том числе в
коммерческой игре, без разрешения и без указания автора. Мы всё равно
перечисляем авторов — из благодарности и чтобы происхождение каждого звука
было проверяемо. Лицензия: https://creativecommons.org/publicdomain/zero/1.0/

Игровые файлы собираются из исходников скриптом `tools/import_cc0_audio.py`
(обрезка, моно 44.1 кГц, выравнивание громкости; музыка — OGG Vorbis).

## Оружие — `audio/weapons/*_shot.wav`
Настоящие записи из **The Free Firearm Sound Library** (Kickstarter-проект,
выложен как CC0) — https://opengameart.org/content/the-free-firearm-sound-library (bart)

| В игре | Запись библиотеки |
|---|---|
| ПМ | Walther PPQ, 9 мм |
| ПМ с глушителем | Walther PPQ, отфильтрованный |
| ТТ-33 | 1911 |
| ППС-43 | ППШ, 7.62x25 Токарев |
| АКМ | АК-47, 7.62x39 |
| АКС-74У | AR-15 |
| СКС | Norinco SKS, 7.62x39 |
| Мосинка | Mosin Nagant, 7.62x54R |
| Дробовик | Benelli Nova, 12 к. |
| ИЖ-81 | Charles Daly, 12 к. |
| ТОЗ-34 | Winchester Model 12, 12 к. |

## Перезарядка и затворы — `audio/weapons/`
- pistol_reload — https://opengameart.org/content/handgun-reload-sound-effect (zer0_sol)
- shell_reload, pump_cycle — https://opengameart.org/content/shotgun-reload-sound-effects (zer0_sol)
- rifle_reload, bolt_reload, bolt_cycle — https://opengameart.org/content/gun-reload-sounds (SpringySpringo)
- smg_reload — https://opengameart.org/content/2-gun-reloads (StarNinjas)
- dry_fire — https://opengameart.org/content/gun-reload-sound-effects (BMacZero)

## Шаги — `audio/world/steps/`, `footstep_*.wav`
- stone_*, grass_*, footstep_* — https://opengameart.org/content/fantozzis-footsteps-grasssand-stone (Fantozzi)
- wood_* — https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud (TinyWorlds)
- gravel_* — https://opengameart.org/content/42-snow-and-gravel-footsteps (Corsica_S)

## Двери — `audio/world/door_*.wav`
- https://opengameart.org/content/door-open-door-close-set (qubodup)

## Заражённые — `audio/infected/`
- infected_call — https://opengameart.org/content/zombie-moans (Darsycho)
- infected_attack, infected_death — https://opengameart.org/content/zombie-noises-and-moans (ianzazz)
- infected_hurt — https://opengameart.org/content/zombie-pain (Vinrax; двойная лицензия CC-BY 3.0 / CC0 — используется вариант CC0)

## Дождь — `audio/ambience/rain.wav`
- https://opengameart.org/content/amb-rain-loop-1 (Kresiek The Furry)

## Музыка — `audio/music/`
| Файл | Трек | Автор |
|---|---|---|
| empty_city.ogg | EmptyCity: Background Music — https://opengameart.org/content/emptycity-background-music | yd |
| contemplation.ogg | Contemplation — https://opengameart.org/content/contemplation-0 | Joth |
| end_of_hope.ogg | At the end of hope — https://opengameart.org/content/at-the-end-of-hope | Emma_MA |
| long_winter.ogg | Long Winter — https://opengameart.org/content/long-winter | Indieteur |
| the_plague.ogg | The Plague — https://opengameart.org/content/the-plague | Indieteur |
| tragic_ambient.ogg | Tragic ambient main menu — https://opengameart.org/content/tragic-ambient-main-menu | HaelDB |
| cold_silence.ogg | Cold Silence — https://opengameart.org/content/cold-silence | Eponasoft |

Остальные звуки (интерфейс, удары, плевок, дневной/ночной фон, тон
помещения) — синтезированы скриптами `tools/build_*_audio.py`. Эти старые
скрипты перезаписали бы звуки выше, поэтому для оружия, шагов, дверей,
заражённых и дождя запускать нужно `tools/import_cc0_audio.py`.
