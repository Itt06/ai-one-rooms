# One Room Observer

Godot 4.x observation simulation where one local-LLM resident lives alone in one room. The human watches; the resident is not given a mission, score, or victory condition.

Core rule:

> Godot decides reality. Ornith decides intention.

The world owns time, needs, resources, movement, validation, action effects, and persistence. The LLM only proposes what the resident wants to do next from the currently available actions.

v1.5 extends this into a persistent multi-day room: time periods, gradual need and cleanliness pressure, finite food and water, persistent trash, completed-life-event memory, learned preferences/habits, and observer-visible history. There is still one resident, no assigned mission, and no scripted daily routine.

## Run

Open the folder in Godot and run `Main.tscn`.

Default local LLM endpoint:

```text
http://127.0.0.1:8000/v1
```

Connection settings can be overridden in:

```text
user://one_room_config.json
```

Example:

```json
{
  "base_url": "http://127.0.0.1:8000/v1",
  "model": "Ornith-1.5-9B",
  "temperature": 0.3,
  "timeout_ms": 15000,
  "max_tokens": 256
}
```

If the LLM server is unavailable or produces invalid output, the resident safely falls back to `wait` and the simulation continues.

## Architecture

```text
Room / Needs / Clock
        |
        v
ObservationBuilder
        |
Memory + Goals + Preferences + Habits
        |
        v
ResidentHarness
        |
     LLMClient
        |
        v
ActionValidator
        |
        v
ActionExecutor
moving -> acting -> completed / interrupted / failed
        |
        v
Authoritative world effects
        |
Memory / history / save
```

Important modules:

```text
world/
  WorldClock.gd
  RoomState.gd

resident/
  ResidentNeeds.gd

actions/
  ActionCatalog.gd (legacy compatibility macros)
  ActionExecutor.gd (legacy compatibility)

activities/
  ActivityCatalog.gd
  ActivityExecutor.gd

ai/
  LLMClient.gd
  ResidentHarness.gd
  ActionValidator.gd
  ObservationBuilder.gd
  MemoryStore.gd
  GoalStore.gd
  PreferenceStore.gd
  DiaryComposer.gd
  prompts/resident_system_prompt.txt

persistence/
  SaveManager.gd

logging/
  DecisionLogger.gd
```

## Persistence

Save:

```text
user://one_room_save.json
```

Decision log:

```text
user://decision_log.jsonl
```

The save format is versioned. Legacy MVP saves are migrated on load.

## Tests

A lightweight headless foundation suite is in:

```text
tests/run_tests.gd
```

Run with a Godot executable from the project directory, for example:

```text
godot --headless --path . --script res://tests/run_tests.gd
```

The suite covers needs, candidate generation, invalid actions, action effects, memory retrieval, and goals.

The local Ornith benchmark uses the production prompt and the real decision/tool validators without writing the game save:

```text
godot --headless --path . --script res://tests/live_ornith_regression.gd -- --runs 1
```

It covers eight compact scenarios per run. For a low-cost smoke, select only the scenarios needed for the change, for example `--scenario read_book,skill,no_useful_action`.

## Scope

The simulation is intentionally small. There is currently no town, work, money, other autonomous NPCs, internet access, OS control, combat, or colony management.

The design goal is not to script a productive routine. Needs are pressures rather than commands, `wait` is a valid choice, and habits/preferences are learned from the resident's own life.

## Primitive plan extension

The current branch adds `RoomGrid`, `ResidentState`, `PrimitiveToolCatalog`, `PrimitiveToolValidator`, `PrimitiveToolExecutor`, `PlanExecutor`, and `PlanHistory`. Ornith may return a short plan of up to six tools such as `move_near`, `pick_up`, `sit`, and `read`; each step is validated against the current authoritative world before the next step begins. `move_to` accepts integer grid cells only. Legacy high-level actions remain available as a compatibility path.

Save schema version is now 4 and includes resident cell/posture/held item, object placement/state, item locations, diagnostics, and bounded plan history. The project still intentionally excludes towns, jobs, money, internet, OS control, shell execution, and other autonomous NPCs.

For a production life-loop endurance run (requires Ornith at `127.0.0.1:8000`):

```powershell
godot --headless --path . --script res://tests/live_soak.gd -- --decisions 100
```

For a multi-day validation run from a clean in-memory world (the `--fresh` flag does not delete the user save):

```powershell
godot --headless --path . --script res://tests/live_soak.gd -- --fresh --decisions 200 --days 3 --speed 16 --max-seconds 900
```

The save format is currently version 5. Existing v1.1 saves are migrated conservatively; unavailable history is not fabricated. `--days` and `--speed` only affect the test runner.

V2 observer presentation keeps technical validation in the debug panel while the normal life feed shows completed activities and verified preference, habit, and skill transitions. Diary entries are generated deterministically from completed activity state; no additional LLM request is used.

Activity execution is restored as idle after loading a save; persistent world and resident state are retained safely.
# Japanese-first observer presentation

The v2.1 observer presentation is Japanese-first: the room is presented as a small dollhouse, while the Resident's needs, activities, diary, preferences, and life feed are described in plain Japanese. Technical JSON, validation, and LLM diagnostics remain available in the collapsible debug panel.

Generated presentation source art is kept in `assets/visual_v21/`; runtime room visuals remain derived from authoritative world state, so the art layer cannot mutate simulation truth.
