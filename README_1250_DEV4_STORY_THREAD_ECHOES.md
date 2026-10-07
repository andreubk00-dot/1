# OSTATOK 1.25.0-dev4 — Story Thread Echoes

Финальный coherence-срез этапа **1.25.0 Narrative & Environmental Storytelling**.

База: **1.25.0-dev3 High Risk Environmental Traces** (`SHA-256 06dd6a86356768eae1cc4645d3f568caab3cfcb7ada742032119cd6f6fd31bf9`).

## Что добавлено

Добавлен `world/story_thread_catalog.gd` с пятью narrative-only нитями:

- медицинский контур;
- карантинный контур;
- силовой/радиоконтур;
- промышленно-энергетический контур;
- транспортно-логистический контур.

Каждая сводка появляется **один раз**, только когда игрок уже прочитал три существующих authored traces данной темы. Сводка записывается в ту же полевую хронику как обычная story-запись.

## Что это НЕ делает

Dev4 не создаёт квесты и не меняет прогрессию. Нет:

- reward / items / reputation;
- objective / target / map marker;
- route unlock;
- High Risk access;
- strategic-item подсказок;
- enemy/loot изменений;
- отдельного thread-save state.

Synthetic thread id хранится в уже существующем `faction_state.world_chronicle.story_seen`, поэтому production schema остаётся **122**.

## Почему это финальный срез 1.25

После dev1–dev3 в мире уже существует 24 редких authored traces:

- 8 finite encounter traces;
- 8 ordinary authored POI traces;
- 8 High Risk traces.

Dev4 не увеличивает плотность записок, а связывает часть существующих фрагментов в выводы, которые игрок получает только после самостоятельного исследования. После этого этап **1.25.0 помечен ГОТОВО**.

## QA

Добавлены:

- `tests/test_story_thread_echoes_125.gd`;
- `tests/test_story_thread_echoes_runtime_125.gd`;
- `tests/test_story_thread_echoes_save_runtime_125.gd`;
- `tests/qa_story_thread_chronicle_capture.gd`.

Все пять `title + body` специально проверяются против `WorldChronicle.TEXT_LIMIT=220`, чтобы сводки не обрезались.

Godot 4.7.2 runtime/capture gate остаётся **PENDING** в текущей среде; статическая проверка не выдаётся за engine PASS.
