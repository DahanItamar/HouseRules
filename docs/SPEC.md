# House Rules — Technical Spec

> Status: Draft · 2026-09-18 · Spec version 1.0

## 1. Problem & Users

There is no product being fixed here — this is a game, and the thing that breaks today is that it doesn't exist. The real constraint is the one that kills most solo game projects: a design large enough to be interesting (sixteen gambling machines, a hub, an economy, a boss) and a builder with finite evenings. Every decision below is made to keep the framework small enough that machines four through sixteen are *content* rather than engineering.

A secondary and explicit goal: this repository is a portfolio artifact. It is read by people deciding whether the author can build software, so the git history, the layout, and the test story are part of the deliverable, not overhead.

**Primary user:** a single player on a Windows PC or a ROG Xbox Ally X handheld, playing with a gamepad, offline.
**Secondary user:** a developer — human or agent — opening this repo cold and needing to add cabinet #4 without reading the other three.
**Success looks like:** a player walks the casino floor, sits at three different machines built on one shared contract, wins and loses chips that survive a relaunch, and cannot reach a state where they are unable to place a bet.

---

## 2. Scope

### In scope (v1)

- A top-down casino floor the player walks with a gamepad, with approachable cabinets
- Three playable machines, one per archetype: **Classic 3-Reel Slot** (pure chance), **Blackjack** (chance + decision), **Minefield Vault** (chance + escalating cash-out decision)
- A **Cashier** on the main floor: takes markers, accepts debt repayment. Always reachable.
- **Wing transition points** (staircase and elevator) to the upper tiers, present but locked in v1
- A chip wallet as the single source of truth for currency, with integer arithmetic
- Contracts (objective-based income) and the **marker/debt** anti-ruin system
- Save and load, atomic and versioned, surviving a crash mid-write
- Deterministic, seeded RNG per machine — reproducible for testing and RTP verification
- A headless test harness that measures each machine's real return-to-player from the shipped math
- Controller-first input with glyph swapping, at a readability standard set by the 7" handheld
- Localization-ready string handling (English ships; no hardcoded user-facing text)
- Platform services (saves, achievements) behind an interface with a local implementation

### Explicitly out of scope

- **The other thirteen cabinets** — designed in `docs/design/CABINET-CATALOG.md`, not scheduled. They are content against the v1 framework; if the framework is right they need no spec changes.
- **High-Roller and VIP wing content** — the economy is designed to extend to three tiers (`docs/design/ECONOMY.md`) and the staircase and elevator that lead to them exist in v1 as locked transition points showing their thresholds. The rooms behind them are empty and unreachable.
- **The House boss showdown** — the campaign endgame. Designed, unscheduled.
- **Steam integration** — no Steamworks, no achievements backend, no cloud saves. §3 keeps the seam so this is an additive change, not a refactor.
- **Multiplayer, leaderboards, telemetry, analytics** — the game makes no network calls at all. This is a hard rule (AC-023), partly because it makes the portfolio repo trivially auditable.
- **Real-money anything.** No chip purchases, no cash-out, no store. This keeps the project at a standard simulated-gambling content descriptor and entirely outside gambling regulation. Reversing it later is not a feature change, it is a different legal product.
- **Save encryption.** Saves are plaintext JSON and a determined player can edit them. Accepted: single-player, no leaderboards, nothing to protect. Stated here so nobody "fixes" it later without a reason.
- **Mobile, console, Linux, macOS.** Windows x64 only. Godot can export the others; nothing in v1 is tested against them.

### 2.1 Acceptance Criteria

| ID | Criterion |
| --- | --- |
| AC-001 | The floor controller shall move the player avatar in eight directions at a constant speed. |
| AC-002 | While the player avatar is inside a cabinet's interaction radius, the floor controller shall display that cabinet's interaction prompt. |
| AC-003 | When the player triggers the interact action while a cabinet prompt is displayed, the scene router shall push that cabinet's scene onto the session stack. |
| AC-004 | If the player's chip balance is below a cabinet's minimum bet, then the floor controller shall present that cabinet as unavailable and refuse the interact action. |
| AC-005 | The cabinet session shall pass a `MiniGameContext` carrying the chip balance, the bet limits and a named RNG stream to every cabinet when it begins. |
| AC-006 | A cabinet shall report every round by emitting `round_resolved` with a `RoundResult`, and shall not modify the wallet directly. |
| AC-007 | When a cabinet emits `round_resolved`, the cabinet session shall apply the stake and the payout to the wallet as one transaction. |
| AC-008 | When the player leaves a cabinet, the scene router shall return to the floor with the avatar standing at that cabinet. |
| AC-009 | If the player leaves a cabinet while a round is in progress, then the cabinet session shall resolve that round as `ABANDONED` and forfeit the stake. |
| AC-010 | The wallet shall represent all currency as integer chips and shall never perform floating-point arithmetic on a balance. |
| AC-011 | If a transaction would take the chip balance below zero, then the wallet shall reject it and emit `transaction_rejected`. |
| AC-012 | When the balance changes, the wallet shall emit `balance_changed` carrying the previous and current values. |
| AC-013 | The RNG service shall give each cabinet a named, independently seeded random stream. |
| AC-014 | Given an identical seed and an identical sequence of inputs, a cabinet's domain math shall produce an identical sequence of outcomes. |
| AC-015 | When the player leaves a cabinet or returns to the main menu, the save service shall persist the game state. |
| AC-016 | The save service shall write saves atomically, by writing a temporary file and renaming it over the target. |
| AC-017 | If a save file fails to parse, then the save service shall preserve it alongside as `.corrupt` and start a new game rather than overwrite it. |
| AC-018 | The save service shall record a `schema_version` in every save file it writes. |
| AC-019 | If a loaded save's `schema_version` is below the current version, then the save service shall apply migrations in sequence before loading. |
| AC-020 | If a loaded save's `schema_version` is above the current version, then the save service shall refuse to load and report an incompatible-version message. |
| AC-021 | The game shall reach save storage and achievements only through the `PlatformServices` interface. |
| AC-022 | The `LocalPlatform` implementation shall store saves under `user://` and record achievements inside the save file. |
| AC-023 | The game shall open no outbound network connections. |
| AC-024 | The economy shall grant contract rewards independently of machine outcomes. |
| AC-025 | If the chip balance falls below the configured solvency floor, then the cashier shall make a marker available that grants a stipend and increases recorded debt. |
| AC-026 | The economy shall never leave the player unable to place a bet. |
| AC-027 | Each cabinet's measured return-to-player over one million simulated rounds shall fall within one percentage point of its declared `target_rtp`. |
| AC-028 | The classic slot shall resolve a spin by drawing one symbol per reel from that reel's weighted strip. |
| AC-029 | When three matching symbols land on the payline, the classic slot shall pay the stake multiplied by that symbol's paytable multiplier. |
| AC-030 | Blackjack shall deal from a six-deck shoe and reshuffle it when fewer than fifty-two cards remain. |
| AC-031 | When the player's first two cards total twenty-one, blackjack shall pay three-to-two and end the round. |
| AC-032 | Blackjack shall require the dealer to draw on sixteen and stand on all seventeens. |
| AC-033 | The minefield vault shall place its configured mine count uniformly at random across a five-by-five grid. |
| AC-034 | When the player reveals a safe tile, the minefield vault shall raise the running multiplier by the true odds of that reveal, reduced by the house edge. |
| AC-035 | When the player cashes out, the minefield vault shall pay the stake multiplied by the running multiplier. |
| AC-036 | If the player reveals a mine, then the minefield vault shall end the round with a payout of zero. |
| AC-037 | The game shall allow every interaction to be completed on a gamepad, with no action requiring a mouse or keyboard. |
| AC-038 | When the active input device changes between gamepad and keyboard, the input router shall update every on-screen prompt to that device's glyphs. |
| AC-039 | While a betting interface is shown, the input router shall move a snap cursor between betting regions with the D-pad or the left stick. |
| AC-040 | The game shall render from a base viewport of 960×540 and scale it by integer factors only. |
| AC-041 | The game shall cap the frame rate at sixty frames per second. |
| AC-042 | The game shall render body text at no less than 8 pixels in base-viewport space, and chip balances, bet amounts and multipliers at no less than 16. |
| AC-043 | The game shall resolve every user-facing string through the translation system, with no literal user-facing text in a scene or script. |
| AC-044 | If an input arrives while a cabinet is outside a state that accepts it, then the cabinet shall ignore it. |
| AC-045 | The game shall permit only one running instance. |
| AC-046 | The cashier shall allow the player to repay debt up to the lesser of the chip balance and the outstanding debt. |
| AC-047 | When the player repays debt, the economy shall reduce chips and debt by the repaid amount in one transaction. |
| AC-048 | The cashier shall be reachable from the main floor in every game state. |
| AC-049 | While the chip balance is below the solvency floor, the HUD shall display a persistent waypoint to the cashier. |
| AC-050 | When the player enters a wing transition point they have unlocked, the scene router shall load that wing's room and place the avatar at its entrance. |
| AC-051 | If the player's lifetime wagered is below a wing's unlock threshold, then that wing's transition point shall present as locked and display the threshold. |
| AC-052 | The economy shall initialize a new game with 200 chips and zero debt. |
| AC-053 | The economy shall never reduce debt below zero. |

---

## 3. Architecture

### Overview

A single Godot 4.7 desktop application. No server, no database, no network layer — the player is alone on their own machine and the save file is the entire persistent state.

The shape is dictated by one goal: **make machine #4 content rather than engineering.** Everything a cabinet needs arrives through one context object, and everything it produces leaves through one result object. A cabinet never reaches the wallet, the save system or the scene tree above it. That single boundary is what lets each machine's math live as pure GDScript with no `Node` in sight — which is in turn what makes a million-round RTP measurement possible against the code that actually ships.

```
                    ┌──────────────────────────────────────────┐
                    │              Autoloads                   │
                    │  SceneRouter  Wallet  RNGService         │
                    │  SaveService  InputRouter  Economy       │
                    └───────┬──────────────────────┬───────────┘
                            │ signals              │ calls
                            ▼                      ▼
   ┌──────────────┐   ┌──────────────┐     ┌──────────────────┐
   │ FloorScene   │──▶│CabinetSession│────▶│  PlatformServices│
   │ (hub, avatar)│◀──│  (the seam)  │     │   (interface)    │
   └──────────────┘   └──────┬───────┘     └────────┬─────────┘
                       begin │  ▲ round_resolved    │ implements
                     context │  │  RoundResult      ▼
                             ▼  │             ┌──────────────┐
                        ┌─────────────┐       │LocalPlatform │
                        │  MiniGame   │       │ (user:// FS) │
                        │ (3 scenes)  │       └──────────────┘
                        └──────┬──────┘
                               │ plain function calls, no Node
                               ▼
                        ┌─────────────┐       ┌──────────────┐
                        │ src/domain/ │◀──────│ tests/ (GUT) │
                        │  pure math  │ 1e6×  │   headless   │
                        └─────────────┘       └──────────────┘
```

### Components

| Component | Responsibility | Technology |
| --- | --- | --- |
| `SceneRouter` | Owns the floor↔cabinet scene stack and the transition. Knows nothing about game rules or money. | Godot autoload |
| `Wallet` | The only thing that may change the chip balance. Integer-only, emits on every change. | Godot autoload |
| `RNGService` | Hands out named, independently seeded `RandomNumberGenerator` streams. Makes every outcome reproducible. | Godot autoload |
| `SaveService` | Serializes `SaveGame` to JSON, atomically, with schema versioning and a migration chain. Delegates the actual write to `PlatformServices`. | Godot autoload |
| `InputRouter` | Active-device detection, glyph set selection, the betting snap-cursor. | Godot autoload |
| `Economy` | Contracts, the marker/debt system, tier unlock thresholds. The anti-softlock guarantee lives here. | Godot autoload |
| `PlatformServices` | Interface for save storage and achievements. The Steam seam. | GDScript base class |
| `LocalPlatform` | The only implementation. `user://` filesystem, achievements as save-file flags. | GDScript |
| `CabinetSession` | Instantiates a cabinet, builds its `MiniGameContext`, applies its `RoundResult` to the wallet. **The only place a cabinet's output touches currency.** | Node |
| `MiniGame` | The contract all three cabinets implement. Base class, documented, not a framework. | GDScript base class |
| `src/domain/` | Every machine's math, as pure GDScript. No `Node`, no scene tree, no signals. Testable headless. | GDScript `RefCounted` |
| `FloorController` | Avatar movement, proximity detection, interaction prompts, wing transition points. | Node2D |
| `Cashier` | The floor interactable that takes markers and accepts debt repayment. Holds no state — delegates to `Economy`. | Node2D |

### Decisions

**The cabinet contract** — a cabinet receives a `MiniGameContext` and emits a `RoundResult`; it never touches `Wallet`, `SaveService` or the scene tree above it.
Because: §1 requires machines 4–16 to be content, and sixteen places mutating currency is sixteen places to get it wrong. One seam means one transaction path and one thing to test.
Instead of: letting each cabinet call `Wallet.add()` directly — lost because it makes every machine's math untestable without a live autoload, and makes an economy audit impossible.
Revisit if: a machine genuinely needs to mutate the balance mid-round rather than at resolution. (Progressive jackpots would; none of the three v1 machines do.)

**Machine math as pure GDScript in `src/domain/`** — no `Node`, no scene tree, callable from a headless test.
Because: AC-027 requires measuring real RTP over a million rounds. That is only possible if the math runs without a running game.
Instead of: a separate Python simulator (the earlier plan) — lost because a simulator and the shipped game drift, and the day they disagree you have measured the wrong thing. Here the test measures production code.
Revisit if: never. This one is load-bearing for the whole economy.

**Seeded, named RNG streams per machine** — `RNGService.stream(&"slot_classic")`, not a global `randi()`.
Because: a bug report of "the slot paid wrong" is unfixable without reproduction, and independent streams stop one machine's draws from shifting another's sequence.
Instead of: Godot's global RNG — lost because it is shared mutable state and destroys reproducibility.
Revisit if: a machine needs cryptographic-quality randomness. None does; this is a game.

**JSON save file, plaintext, atomic write** — a file is the database.
Because: single player, single machine, bounded data (one wallet, sixteen cabinet stat rows). A database engine here would be a moving part earning nothing.
Instead of: SQLite — lost on the "could this be deleted and the product still work" test.
Revisit if: save data grows unbounded, e.g. a full per-round history for statistics.

**`PlatformServices` interface with one local implementation** — saves and achievements go through an abstraction that currently has exactly one implementor.
Because: explicitly requested. A future Steam release must not require touching game code.
Instead of: calling `FileAccess` directly and abstracting later — lost because "later" means every call site.
Note: this is the one piece of indirection in the document that isn't earned by present need. It is kept because it is two files and the alternative is a refactor across the codebase.

**Base viewport 960×540, integer scaling only** — locked, and the most expensive decision here to reverse.
Because: ×2 is exactly 1920×1080 on both a desktop monitor and the Ally X, ×4 is 4K. No filtering, no shimmer.
Instead of: 640×360 — lost because casino UI is text-dense. A European roulette board carries 37 numbered betting regions and cannot be drawn legibly in 640 pixels, and roulette is machine #4.
Revisit if: the art direction abandons pixel art entirely.

**GDScript, not C#** — the installed Godot 4.7.2 at `C:\Godot` is the standard build with no .NET support.
Because: switching means a different engine download, and GDScript's engine integration is tighter for a solo project.
Instead of: C# with the Godot .NET build — lost on setup cost against no benefit this project can name.

---

## 4. Project Layout & Conventions

No `docs/CONSTITUTION.md` exists. This section is written inline. **Run `/spec-constitution` after this spec is accepted** to lift these rules into a document the later stages inherit directly.

### Directory layout

```
res://
├── src/
│   ├── domain/         # Pure GDScript. No Node, no scene tree, no signals, no autoload access.
│   │                   # All machine math lives here. Must run under --headless.
│   ├── autoload/       # The six singletons in §3. Nothing else may be an autoload.
│   ├── platform/       # PlatformServices + LocalPlatform. A Steam impl would land here.
│   ├── cabinets/       # One folder per machine: its scene, its controller. Math lives in domain/.
│   ├── floor/          # Hub: avatar, camera, proximity, interaction prompts.
│   └── ui/             # Shared HUD, glyphs, menus, the snap cursor. No game rules.
├── data/
│   ├── cabinets/       # CabinetDefinition .tres — one per machine. Designer-editable.
│   └── paytables/      # Paytable .tres. Never hardcoded in a script.
├── assets/
│   ├── sprites/ audio/ fonts/ shaders/
├── locale/             # en.csv and the generated .translation. Every user-facing string.
├── tests/              # GUT. Headless. The RTP harness lives here.
└── docs/               # This spec and its companions.
```

### Dependency direction

```
ui → cabinets → domain ← autoload
                  ↑
            (imports nothing)
```

`src/domain/` imports no engine node type and reaches no autoload. If a domain file needs the wallet, the design is wrong — it needs a parameter. This single rule is what makes AC-027 achievable.

### Naming

| Kind | Convention | Example |
| --- | --- | --- |
| Script file | snake_case, matching its class | `slot_machine_math.gd` |
| `class_name` | PascalCase noun | `SlotMachineMath`, `RoundResult` |
| Scene file | snake_case, matching its root node | `classic_slot.tscn` |
| Function / variable | snake_case verb phrase | `resolve_spin`, `current_stake` |
| Private member | leading underscore | `_shoe`, `_draw_symbol` |
| Boolean | `is_` / `has_` / `can_` prefix | `is_accepting_input` |
| Constant | SCREAMING_SNAKE | `MAX_BET_MAIN_FLOOR` |
| Signal | past tense, snake_case | `round_resolved`, `balance_changed` |
| Cabinet id | `StringName`, snake_case, never localized | `&"slot_classic"` |
| Translation key | SCREAMING_SNAKE, prefixed by area | `CABINET_SLOT_CLASSIC_NAME` |
| Resource file | snake_case `.tres` | `slot_classic.tres` |
| Test file | `test_` prefix, beside nothing — under `tests/` | `test_slot_machine_math.gd` |
| Branch | `type/short-description` | `feat/minefield-vault` |

Banned as class suffixes: `Manager`, `Helper`, `Utils`, `Data`, `Info`. Each means the author had not yet decided what the thing was.

### Size limits

| Unit | Soft | Hard |
| --- | --- | --- |
| Script file | 300 lines | 500 |
| Function | 40 lines | 80 |
| Parameters | 3 | 4 |
| Nesting depth | 3 | 4 |

### Tooling

| Concern | Tool |
| --- | --- |
| Formatter | `gdformat` (gdtoolkit 4) |
| Linter | `gdlint` |
| Tests | GUT, run headless |
| CI | GitHub Actions: `gdformat --check`, `gdlint`, `gut --headless`. All blocking. |
| Verify command | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit` |

**Git hygiene is a deliverable** (§1). `.gitignore` excludes `.godot/`, `export/`, `*.translation`. `.gitattributes` marks `*.tres`/`*.tscn` as text so diffs are readable. Commits follow Conventional Commits. The lockfile equivalent — the pinned Godot version — is recorded in `README.md`.

---

## 5. Data Models

```gdscript
# src/domain/cabinet_definition.gd — one .tres per machine, designer-editable
class_name CabinetDefinition
extends Resource

enum Tier { MAIN_FLOOR, HIGH_ROLLER, VIP }
enum Volatility { LOW, MEDIUM, HIGH }

@export var id: StringName = &""              # registry key; never shown, never localized
@export var name_key: String = ""             # translation key, e.g. "CABINET_SLOT_CLASSIC_NAME"
@export var tier: Tier = Tier.MAIN_FLOOR
@export var scene: PackedScene                # the MiniGame this definition instantiates
@export var min_bet: int = 1                  # chips; integer always
@export var max_bet: int = 50
@export var target_rtp: float = 0.96          # verified by the headless harness, AC-027
@export var volatility: Volatility = Volatility.MEDIUM
@export var unlock_chips: int = 0             # lifetime chips required before it appears
```

```gdscript
# src/domain/mini_game_context.gd — everything a cabinet is allowed to know
class_name MiniGameContext
extends RefCounted

var definition: CabinetDefinition
var balance: int                              # read-only snapshot; the cabinet never writes it
var rng: RandomNumberGenerator                # this cabinet's named stream (AC-013)
```

```gdscript
# src/domain/round_result.gd — everything a cabinet is allowed to produce
class_name RoundResult
extends RefCounted

enum Outcome { WIN, LOSS, PUSH, CASHED_OUT, ABANDONED }

var stake: int = 0                            # chips risked; deducted by CabinetSession
var payout: int = 0                           # gross chips returned. 0 on a loss; == stake on a push
var outcome: Outcome = Outcome.LOSS
var detail: Dictionary = {}                   # machine-specific, for the result display only.
                                              # Never read by the wallet or the economy.
```

```gdscript
# src/domain/save_game.gd
class_name SaveGame
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1

var schema_version: int = CURRENT_SCHEMA_VERSION
var chips: int = 0
var debt: int = 0                             # owed to The House; never reduces below 0
var lifetime_wagered: int = 0                 # drives tier unlocks, not the current balance
var tier_unlocked: CabinetDefinition.Tier = CabinetDefinition.Tier.MAIN_FLOOR
var cabinet_stats: Dictionary = {}            # StringName -> CabinetStats
var achievements: Dictionary = {}             # StringName -> bool (LocalPlatform, AC-022)
var rng_seed: int = 0                         # the run's master seed; streams derive from it
var played_seconds: float = 0.0
var created_at: String = ""                   # ISO 8601 UTC
```

```gdscript
# src/domain/cabinet_stats.gd — per machine, for the economy audit and the stats screen
class_name CabinetStats
extends RefCounted

var rounds: int = 0
var wagered: int = 0
var returned: int = 0                         # observed RTP == returned / wagered
var best_win: int = 0
```

**Relationships**

- `SaveGame` 1:N `CabinetStats`, keyed by `CabinetDefinition.id`. A stat row is created lazily on the first round and never deleted.
- `CabinetDefinition` 1:1 `PackedScene`. A definition with a null scene is a load-time error, not a runtime one.

**Constraints**

- `chips`, `debt`, `stake`, `payout` are **integers**, always (AC-010). Money as a float is how a casino game gets `0.30000000000000004` chips.
- `debt` rises when a marker is taken and falls when the player repays at the cashier. It is clamped at zero and never goes negative (AC-053). Repayment is player-initiated only — nothing deducts debt automatically, because an automatic deduction would silently consume contract income and break the pacing model in `ECONOMY.md` §2.
- `id` is unique across `data/cabinets/`. Collision is a load-time assertion.
- `target_rtp` is bounded to `[0.80, 1.20]`. Outside that range a machine is either a scam or a money printer, and both are bugs.

---

## 6. Interfaces

### The cabinet contract — `MiniGame`

Every machine implements exactly this. It is a base class, not a framework.

```gdscript
class_name MiniGame
extends Node

## Emitted once per completed round. The ONLY way a cabinet reports money.
signal round_resolved(result: RoundResult)

## Emitted when the player wants to return to the floor.
signal exit_requested()

## Called once by CabinetSession before the cabinet is shown.
func begin(context: MiniGameContext) -> void:
    push_error("MiniGame.begin() not overridden by %s" % get_script().resource_path)

## Called when the player pauses or the session is torn down mid-round.
## Must be safe to call in any state. Implementations resolve as ABANDONED if a round is live.
func abandon() -> void:
    pass
```

### `PlatformServices` — the Steam seam

```gdscript
class_name PlatformServices
extends RefCounted

func read_save(slot: StringName) -> PackedByteArray: ...   # empty array == no save
func write_save(slot: StringName, bytes: PackedByteArray) -> Error: ...  # MUST be atomic (AC-016)
func unlock_achievement(id: StringName) -> void: ...
func is_achievement_unlocked(id: StringName) -> bool: ...
```

`LocalPlatform` implements all four against `user://` and the save file. A future `SteamPlatform` implements the same four against Steam Cloud and the Steamworks achievement API, and nothing else in the codebase changes (AC-021).

### Autoload surfaces

| Signature | Purpose | Errors |
| --- | --- | --- |
| `Wallet.try_apply(stake: int, payout: int) -> bool` | The single currency transaction. Returns false and emits `transaction_rejected` if it would go negative. | AC-011 |
| `Wallet.balance_changed(previous: int, current: int)` | Signal. Every HUD element listens; nothing polls. | AC-012 |
| `RNGService.stream(name: StringName) -> RandomNumberGenerator` | A named, independently seeded stream, derived from `SaveGame.rng_seed`. | AC-013 |
| `SceneRouter.enter_cabinet(definition: CabinetDefinition) -> void` | Pushes the cabinet scene; builds the session. | AC-003 |
| `SceneRouter.return_to_floor() -> void` | Pops; restores the avatar at the cabinet it came from. | AC-008 |
| `SaveService.save() -> Error` / `SaveService.load() -> Error` | Atomic write, versioned read, migration chain. | AC-016..020 |
| `Economy.is_below_solvency_floor() -> bool` | Drives the cashier waypoint and the marker's availability. Checked after every resolved round. | AC-025, AC-049 |
| `Economy.take_marker() -> bool` | Grants the stipend, increases debt. Cashier-only; refuses above the solvency floor. | AC-025, AC-026 |
| `Economy.repay_debt(amount: int) -> bool` | Reduces chips and debt together. Clamps to `min(balance, debt)`. | AC-046, AC-047, AC-053 |
| `InputRouter.active_device_changed(device: Device)` | Signal. Every prompt listens; glyph sets swap on it. | AC-038 |

---

## 7. Core Flows

### Flow A — Floor to cabinet and back

1. Player moves the avatar → `FloorController` integrates input at a fixed speed
2. Avatar enters a cabinet's `Area2D` → `FloorController` shows the prompt, or the unavailable state if `Wallet.balance < definition.min_bet`
3. Player presses interact → `SceneRouter.enter_cabinet(definition)`
4. `SceneRouter` instantiates the scene, creates a `CabinetSession`, which builds a `MiniGameContext` with a snapshot balance and `RNGService.stream(definition.id)`
5. `CabinetSession` calls `MiniGame.begin(context)`; the transition plays; the floor dims but stays loaded
6. Player bets and plays → the cabinet runs its own state machine, calling into `src/domain/` for every outcome
7. Cabinet emits `round_resolved(result)` → `CabinetSession` calls `Wallet.try_apply(result.stake, result.payout)` → `Economy.is_below_solvency_floor()` updates the cashier waypoint → `CabinetStats` updated
8. Player presses back → `exit_requested` → `SaveService.save()` → `SceneRouter.return_to_floor()`

**Satisfies:** AC-001 … AC-009, AC-015
**Failure branches:** exit mid-round → `abandon()` → `ABANDONED`, stake forfeit (AC-009). Wallet rejection → the cabinet is told the round could not be staked and returns to its betting state.

### Flow B — Going broke, and digging out

1. A round resolves leaving `chips` below the solvency floor
2. `Economy.is_below_solvency_floor()` returns true → a persistent waypoint to the cashier appears in the HUD (AC-049)
3. Player walks to the cashier — always reachable from the main floor (AC-048)
4. Player takes a marker → `chips += stipend`, `debt += stipend`, saved immediately
5. Play resumes; the debt sits in the HUD until repaid
6. Later, with chips in hand, the player returns to the cashier and repays any amount up to `min(balance, debt)` (AC-046, AC-047)

**Satisfies:** AC-025, AC-026, AC-046 … AC-049
**Failure branches:** none by construction. The player can always reach the cashier and the cashier always has credit, so a state with no legal bet cannot be entered. A softlock here is a bug, not an ending.

**Why the marker lives at the cashier rather than popping up after a losing round:** an offer that appears the instant you go broke is the house pouncing. Making the player stand up and walk to the cage to ask for credit is the authentic version of that moment, and it is the one the game wants. The waypoint exists so the *mechanism* is never hidden — only the asking.

### Flow C — Save, crash, relaunch

1. `SaveService.save()` serializes `SaveGame` to JSON
2. `LocalPlatform.write_save()` writes `user://save.json.tmp`, flushes, then renames over `user://save.json` (AC-016)
3. Power loss during step 2 leaves the previous save intact — the rename is the commit
4. On launch, `SaveService.load()` reads, checks `schema_version`, runs migrations forward if behind (AC-019), refuses if ahead (AC-020)
5. A parse failure renames the file to `save.json.corrupt` and starts a new game (AC-017)

**Satisfies:** AC-015 … AC-020, AC-022

### Flow D — Verifying the economy (developer flow)

1. `tests/test_rtp_harness.gd` loads each `CabinetDefinition`
2. For each, it constructs that machine's domain math with a fixed seed and runs one million rounds with a scripted strategy (basic strategy for blackjack; a fixed cash-out rule for the vault)
3. It sums stakes and payouts and compares observed RTP to `definition.target_rtp`
4. CI fails if any machine drifts more than one percentage point (AC-027)

**Satisfies:** AC-014, AC-027
**Why this exists:** the central economy risk is that the designed numbers and the built numbers disagree. This is the only thing that catches it, and it runs on every commit.

---

## 8. Edge Cases & Failure Modes

| Case | Consequence if unhandled | Handling | AC |
| --- | --- | --- | --- |
| First launch, no save | Crash or a zeroed wallet the player can't act on | New-game flow seeds the starting stake; `LocalPlatform.read_save` returns an empty array, not an error | AC-022 |
| Power loss mid-save | Truncated JSON, whole run lost | Temp file + atomic rename; the rename is the commit point | AC-016 |
| Hand-edited or truncated save | Crash on parse, run lost silently | Preserve as `.corrupt`, start fresh, tell the player | AC-017 |
| Save from a newer build | Fields silently missing, subtle wrong behavior | Refuse to load; report incompatible version | AC-020 |
| Save from an older build | Missing fields default to zero, e.g. debt vanishes | Migration chain applied in sequence | AC-019 |
| Player broke, below the solvency floor | **Softlock.** The single worst failure this design can have | Cashier waypoint appears; the cashier is always reachable and always has credit | AC-025, AC-026, AC-048, AC-049 |
| Repay attempted with zero debt | A no-op that looks like a bug, or a negative debt | Repay option hidden when `debt == 0` | AC-053 |
| Repay more than the balance, or more than the debt | Negative chips, or negative debt | Amount clamped to `min(balance, debt)` before the transaction | AC-046, AC-047 |
| Repaying drops the player below the solvency floor | Player repays into insolvency, then needs another marker | Allowed, and the waypoint reappears. The player is permitted to make a bad decision; the guarantee still holds | AC-026 |
| Locked wing entered | Player walks into an empty room, or nothing happens at all | Transition point presents as locked and names the lifetime-wagered threshold | AC-051 |
| Button mashed during a spin | Double-staking, or a stake applied twice | Cabinet state machine ignores input outside accepting states | AC-044 |
| Exit pressed mid-round | Stake vanishes or is refunded inconsistently per machine | `abandon()` on the base contract; resolves `ABANDONED`, stake forfeit, one rule for every machine | AC-009 |
| Two instances running | Last writer wins; one run silently erased | Single-instance enforced at startup | AC-045 |
| Payout overflows | Wraparound to a negative balance | 64-bit ints and a `max_win` cap per machine in its paytable | AC-010 |
| Save-scumming a bet | Player reloads to undo a loss | **Accepted.** Single player, no leaderboards, nothing to protect. Documented so it isn't "fixed" without a reason | — |
| Gamepad unplugged mid-round | Input dead, round stuck | Auto-pause on device loss; resume on reconnect | AC-037 |
| Dark UI on a 500-nit handheld in sunlight | Critical numbers unreadable | Contrast floor in the art bible; neon is decoration layered over legible shapes, never the carrier of information | AC-042 |
| Translation key missing | Raw `SCREAMING_SNAKE` shown to the player | CI check that every `tr()` key exists in `locale/en.csv` | AC-043 |

---

## 9. Security & Permissions

Short by construction. This is a single-player offline game with no accounts, no network, and no data worth protecting.

**Authentication:** none. Single-user local application; the OS account is the boundary. No login screen should ever be added.

**Authorization:** not applicable. One player, one save, one role.

**Data handling:**

- The save file is **plaintext JSON under `user://`, unencrypted, by design.** A player can read and edit it. Accepted (§2, §8) — there is nothing to protect and no integrity claim to defend.
- **No PII is collected.** No name, no email, no machine identifier, no analytics, no crash reporting.
- **No outbound network connections at all** (AC-023). Not telemetry, not version checks, not asset fetching. Anything the game needs ships in the build.
- No auto-update channel. Distribution is a zipped build; an unsigned auto-updater is remote code execution and there is no reason to have one.
- External links, if the credits ever carry one, open in the system browser rather than an in-game view.

**Content rating:** the game depicts gambling with fictional chips and no real-money wagering or cash-out. This draws a simulated-gambling content descriptor from the rating boards and sits inside storefront policy. The constraint that keeps it there — no real-money purchases, no cash-out — is recorded in §2 as out of scope, because reversing it is a legal change, not a feature.

---

## 10. Build Order

Each milestone ends in something demoable. `/spec-tasks` turns this into `TASKS.md`.

**M1 — One machine, end to end**
*Demo: launch the game, walk the floor with a gamepad, sit at the slot, bet, spin, win chips, quit, relaunch, and the chips are still there.*
- [ ] Godot project, folder layout, `.gitignore`, CI pipeline — closes AC-040, AC-041
- [ ] `Wallet` with integer transactions and signals — closes AC-010, AC-011, AC-012
- [ ] `RNGService` with named seeded streams — closes AC-013, AC-014
- [ ] `PlatformServices` + `LocalPlatform`, atomic write, schema version, migration chain — closes AC-016, AC-018, AC-019, AC-020, AC-021, AC-022
- [ ] `SaveService` with corrupt-file handling — closes AC-015, AC-017
- [ ] `FloorController`: avatar, proximity, prompts, unavailable state — closes AC-001, AC-002, AC-004
- [ ] New-game initialization: 200 chips, zero debt — closes AC-052
- [ ] `SceneRouter` + `CabinetSession` + the `MiniGame` contract — closes AC-003, AC-005, AC-006, AC-007, AC-008, AC-009
- [ ] `SlotMachineMath` in `domain/`, weighted strips, paytable resource — closes AC-028, AC-029
- [ ] Classic slot cabinet scene on the contract — closes AC-044
- [ ] Single-instance guard, no network — closes AC-023, AC-045

**M2 — The framework proves itself**
*Demo: three machines of three different shapes, all on one contract, none of which required changing the contract.*
- [ ] `BlackjackMath`: six-deck shoe, dealer rules, naturals — closes AC-030, AC-031, AC-032
- [ ] Blackjack cabinet scene on the contract — closes AC-006, AC-044 for this cabinet
- [ ] `MinefieldMath`: grid, mine placement, multiplier curve — closes AC-033, AC-034, AC-035, AC-036
- [ ] Minefield Vault cabinet scene on the contract — closes AC-006, AC-044 for this cabinet
- [ ] Check the `MiniGame` contract against the four capabilities in `docs/design/CABINET-CATALOG.md` §"What this catalog tells you" — closes AC-005
- [ ] If the contract needed changing for either cabinet, that is the finding — record it before continuing

**M3 — The economy closes**
*Demo: a CI run printing measured RTP per machine, and a player who cannot go broke.*
- [ ] Headless RTP harness over one million rounds per machine — closes AC-027
- [ ] Paytables tuned until measured meets target
- [ ] Contracts — closes AC-024
- [ ] `Cashier` floor interactable, always reachable — closes AC-048
- [ ] Marker at the cashier + solvency waypoint — closes AC-025, AC-026, AC-049
- [ ] Debt repayment at the cashier — closes AC-046, AC-047, AC-053
- [ ] Wing transition points (staircase, elevator), locked, showing thresholds — closes AC-050, AC-051

**M4 — Controller and handheld**
*Demo: the game played end to end on an Ally X with the keyboard unplugged, readable at arm's length.*
- [ ] Full gamepad coverage audit — closes AC-037
- [ ] Glyph swapping on device change — closes AC-038
- [ ] Betting snap cursor — closes AC-039
- [ ] Readability pass against the 8px/16px floor — closes AC-042
- [ ] Gamepad disconnect auto-pause

**M5 — Localization and polish**
*Demo: every string in one CSV; switching it swaps the whole UI.*
- [ ] Extract all strings to `locale/en.csv`; CI key-existence check — closes AC-043
- [ ] Art pass against the bible, audio pass, transition juice

---

## 11. Assumptions

1. **Godot 4.7.2 standard build, GDScript.** If the project moves to the .NET build, §4 tooling and every code sample change; nothing architectural does.
2. **The three v1 machines are Classic Slot, Blackjack, Minefield Vault** — chosen to cover the three archetypes. Swapping one for another cabinet of the same archetype changes only `docs/cabinets/`.
3. **Starting chips 200, starting debt zero, marker stipend 100, solvency floor 20.** Confirmed values, not placeholders. The marker is an emergency loan taken at the cashier, never an automatic grant. `ECONOMY.md` holds the curve these sit on; M3 tunes contract rewards around them, not these numbers.
4. **Blackjack ships without splitting, insurance or surrender in v1.** Hit, stand and double only. Splitting needs multi-hand UI and state, which is a cabinet-sized piece of work on its own; it is the first thing to add in v2.
5. **Minefield Vault is a 5×5 grid with a player-chosen mine count of 1–24.** The multiplier curve derives from true odds reduced by a flat house edge.
6. **Art is generated, then post-processed.** AI image generation produces raster output at its own resolution; reaching an exact 48×64 sprite at a locked palette needs a downsample, a palette quantize and a manual cleanup pass. Multi-frame animation with frame-to-frame consistency is where these tools are weakest, so animated sprites are specified for hand-pixelling or heavy cleanup, and generation is aimed at static and large elements — cabinet art, backgrounds, portraits, promo. `docs/art/ASSET-SPECS.md` is written on that basis.
7. **The Higgsfield MCP server is not connected to this session.** Asset specs are written as generation-ready briefs with literal prompts, usable once it is connected or by hand. If it becomes available, nothing in the specs changes.
8. **The project folder is still `D:\Dev\repos\MyFirstGame`.** The rename to `HouseRules` has not been run. Every path in this spec is relative to the project root, so the rename does not invalidate anything here.

---

## 12. Open Questions

- **Which achievements exist?** — blocks: nothing. `PlatformServices` carries the interface; the list can stay empty until there is a reason to fill it.

**Resolved since Draft 1.0.** Kept as a record because the reasoning behind each is load-bearing downstream:

| Was open | Resolution | Where it lives now |
| --- | --- | --- |
| Starting economy | 200 chips, zero debt, 100-chip marker, solvency floor 20 | Assumption 3, AC-052 |
| Debt repayment | Repayable at the cashier, player-initiated only — never automatic | §7 Flow B, AC-046, AC-047 |
| One room or several | Main floor plus a staircase and an elevator to separate upper-tier rooms | §3, AC-050, AC-051 |

Nothing open blocks M1.
