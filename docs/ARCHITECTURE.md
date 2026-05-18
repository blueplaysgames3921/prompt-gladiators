# Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       Flutter App                                │
│                   (prompt_gladiators)                            │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │
│  │  Home    │  │  Lobby   │  │  Battle  │  │  Tournament    │  │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  + Settings    │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬────────┘  │
│       │              │              │                │           │
│  ┌────▼──────────────▼──────────────▼────────────────▼────────┐  │
│  │                  Riverpod Providers                        │  │
│  │  AppSettingsNotifier    │  ActiveBattleNotifier            │  │
│  │  TournamentNotifier     │  DebugLogNotifier                │  │
│  │  LiteLLMStatusNotifier  │  RelayConnectionNotifier         │  │
│  │  ModelProvidersNotifier │  LobbyMembersNotifier            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────┐    ┌──────────────────────────────┐   │
│  │   BattleEngine       │    │       RelayService           │   │
│  │   (state machine)    │    │    (WebSocket client)        │   │
│  └──────────┬───────────┘    └─────────────┬────────────────┘   │
└─────────────┼────────────────────────────── ┼────────────────────┘
              │                               │
              ▼                               ▼
  ┌─────────────────────┐      ┌──────────────────────────────────┐
  │   LiteLLM Proxy     │      │    Go Relay Server               │
  │   :4000             │      │    (self-hosted, any port)        │
  │   OpenAI-compat     │      │                                  │
  │   auto-started      │      │  Lobby ── Battle ── Votes        │
  │   (desktop only)    │      │  Chat  ── Roles  ── Spectators   │
  └──────────┬──────────┘      └──────────────────────────────────┘
             │
    ┌────────┴────────────────────────────────────────┐
    │  Model Providers (via LiteLLM routing)           │
    │  OpenAI · Gemini · Groq · xAI · Ollama           │
    │  Pollinations.ai · Any OpenAI-compatible API     │
    └─────────────────────────────────────────────────┘
```

---

## Code Generation

Before building, run `build_runner` to generate:

```
lib/core/models/models.freezed.dart   — Freezed immutable model impls
lib/core/models/models.g.dart         — JSON serialisation
lib/core/config/providers.g.dart      — Riverpod provider boilerplate
```

These are generated from annotations in:
- `lib/core/models/models.dart` — `@freezed` data models
- `lib/core/config/providers.dart` — `@riverpod` / `@Riverpod` providers

---

## Flutter App

### State Management — Riverpod

All state flows through typed Riverpod providers. UI widgets consume state via `ref.watch()` and trigger mutations via `ref.read(...notifier)`.

```
Widget.build()
  │  ref.watch(activeBattleNotifierProvider)
  ▼
ActiveBattleNotifier.state  ←──  BattleEngine.onStateUpdate()
  │
  └── RelayService.syncBattleState()  →  other clients
```

**Provider dependency graph:**
```
sharedPreferencesProvider
  └── appSettingsNotifierProvider
        └── liteLLMStatusNotifier (reads liteLLMPort)
        └── relayConnectionNotifier (reads relayUrl, authToken)

activeBattleNotifier
  ├── BattleEngine (local battle state machine)
  └── RelayService (receives remote state updates)

debugLogNotifier
  └── RelayService.messages (logs all relay events)
```

### Stream Subscription Safety

All providers that listen to streams store the `StreamSubscription` and cancel it in `ref.onDispose` or `dispose()`. This prevents memory leaks when providers are invalidated or the app is torn down.

### Navigation — GoRouter

```
/                       → HomeScreen
/lobby/new              → LobbyScreen (create mode)
/lobby/join?id=...      → LobbyScreen (join mode)
/battle/:id             → BattleScreen
/tournament             → TournamentScreen
/settings               → SettingsScreen (game tab)
/settings/game          → SettingsScreen (game tab)
/settings/debug         → SettingsScreen (debug tab)
/settings/internal      → SettingsScreen (internal tab)
/debug                  → DebugScreen
```

---

## BattleEngine

The `BattleEngine` is the core local state machine. It lives in `ActiveBattleNotifier` and drives the entire battle flow asynchronously.

### Lifecycle

```
createBattle(settings, fighterA, fighterB)
  └── configure() → state = lobby

start(initialPrompt)
  └── status = countdown (3s delay)
  └── status = inProgress
  └── _runAllRounds(initialPrompt)
        └── for each round:
              1. Build BattleModeContext (opponent response, apocalypse level, injection)
              2. Build prompt via BattleModeConfig.roundPromptBuilder()
              3. Call both fighters in parallel via LiteLLMService
              4. Emit roundResponsesReady
              5. If judgeEnabled: call judge model → parse JSON verdict
              6. If votingEnabled + perRound: open 30s voting window
              7. If scoreboardEnabled: scoreRound()
              8. Emit roundComplete
        └── _finalizeBattle() → determine winner by score
```

### BattleModeConfig

Each `BattleType` has a `BattleModeConfig` that controls:
- Default system prompts for each fighter (used if user leaves prompt blank)
- `roundPromptBuilder(BattleModeContext)` → String
- `responsePromptBuilder(BattleModeContext)?` → String (battlefield only)

`BattleModeContext` carries all per-round context: round number, opponent's last response, own last response, apocalypse level, audience injection.

### JSON Parsing

`_parseJson(String raw)` handles three formats the judge model may return:
1. Clean JSON: `{"scoreA": 8, "scoreB": 6, "verdict": "..."}`
2. Markdown-fenced: ` ```json\n{...}\n``` `
3. Prose-embedded: `"After review: {...} That concludes..."`

Returns empty `Map` on any parse failure (judge verdict is optional — battle continues).

---

## Relay Server (Go)

### Architecture

```
HTTP Server (:8080)
├── GET  /health     → JSON status + client/lobby counts
├── GET  /metrics    → extended stats (uptime, messages, connects)
├── GET  /lobbies    → public lobby listings (JSON array)
└── GET  /ws         → WebSocket upgrade → client goroutine pair

WebSocket Client (per connection)
├── ReadPump goroutine   reads messages → hub.Dispatch()
└── WritePump goroutine  drains Send channel → writes to WS
```

### Hub Event Loop

The `Hub.Run()` goroutine is the single serialisation point for all lobby mutations. It processes:

```
hub.register chan   → add client to clients map
hub.unregister chan → remove client, update lobby members
hub.broadcast chan  → route(Envelope)
30s ticker         → cleanEmptyLobbies()
```

**Why a single goroutine for mutations?** `Lobby.Members` is a `map[string]*Member`. Maps are not safe for concurrent writes. The hub loop serialises all writes; reads use `sync.RWMutex`.

### Message Flow

```
Client A sends "createLobby"
  → ws/handler.go ReadPump reads raw bytes
  → ParseEnvelope() → Envelope{Type: createLobby, ...}
  → hub.Dispatch(env)  [non-blocking, channel send]
  → hub.Run() receives env
  → hub.route(env)
  → handleCreateLobby(env)
    → create Lobby struct, add to hub.lobbies
    → add Client A as owner member
    → sendLobbyState(lobbyID)
      → marshal members into DTO
      → for each connected member: client.send(env)
        → non-blocking select → member.Send channel
  → WritePump goroutine drains Send channel → websocket.WriteMessage()
```

### Lock discipline

- `hub.mu` (`sync.RWMutex`) guards `hub.lobbies` and `hub.clients`
- `lobby.mu` (`sync.RWMutex`) guards `lobby.Members` and `lobby.Settings`
- **Rule**: never hold `lobby.mu` while calling `client.send()` — channels are non-blocking but acquiring the hub lock while holding the lobby lock would invert lock order. All broadcast calls happen after releasing lobby locks.

---

## LiteLLM Sidecar

On desktop, `LiteLLMService.start()`:

1. Checks `litellm` is in PATH
2. Creates default config YAML if missing
3. Spawns `litellm --config <path> --port <port>` as child process
4. Polls `GET /health` every 500ms until ready (max 15s)
5. Sets `_running = true`

On mobile, `LiteLLMService.start()` returns immediately (no sidecar). The app calls LiteLLM at whatever URL is configured in Internal Settings.

### Stopping

`LiteLLMService.stop()` sends `SIGTERM` to the child process and waits. Called by the app on shutdown via Flutter's lifecycle hooks.

---

## Settings Architecture

```
AppSettings (persisted to SharedPreferences as 'app_settings_v1')
├── BattleSettings
│     battle type, rounds, time/token limits, blind mode
│     judge (on/off, model, criteria)
│     scoreboard (on/off, points)
│     voting (on/off, timing, audience weight)
│     spectators (on/off, audience controls, chants)
│     apocalypse (on/off, escalation prompt)
│     agentic (agents per side, allowed tools)
│     multiplayer (on/off, visibility, ranked)
│
├── DebugSettings
│     verbose logging, raw payloads, token counts
│     latency metrics, WS inspector, LiteLLM panel
│     force error states, step-through mode
│
└── InternalSettings
      LiteLLM URL, port, auto-start, config YAML
      relay URL, auth token
      mid-match override permissions:
        allowMidMatchModelSwap
        allowStateOverride
        allowScoreOverride
        allowPromptInjection
```

`AppSettingsNotifier` updates are atomic per layer — `updateBattle()` reads current state, merges, writes back. `updateDebug()` and `updateInternal()` work identically. No layer clobbers another.

---

## Data Models

All models are **Freezed** — immutable value objects with `copyWith`, `toJson`, `fromJson`.

```
BattleState
├── id: String (UUID)
├── settings: BattleSettings
├── fighterA: FighterConfig
├── fighterB: FighterConfig
├── rounds: List<BattleRound>
├── status: BattleStatus
├── currentRound: int
├── totalScoreA: double
├── totalScoreB: double
├── winnerId: String?
└── members: List<LobbyMember>

BattleRound
├── roundNumber: int
├── prompt: String
├── responseA / responseB: String
├── status: BattleRoundStatus
├── scoreA / scoreB: double?
├── judgeVerdict: String?
├── votes: Map<String, int>
├── tokensA / tokensB: int
├── latencyMsA / latencyMsB: int
└── rawPayloadA / rawPayloadB: String?

FighterConfig
├── id: String (UUID, generated by FighterConfig.create())
├── name / modelId / endpointUrl: String
├── apiKey: String?
├── systemPrompt: String
├── side: FighterSide
├── agentCount: int
└── allowedTools: List<AgentTool>
```

---

## Tournament & ELO

### Round-Robin Bracket

`_BracketTab._generateBracket()` produces rounds where no model appears twice in the same round:

```
entries = [A, B, C, D]
matchups = [AB, AC, AD, BC, BD, CD]

Round 1: [AB, CD]  (A, B, C, D each appear once)
Round 2: [AC, BD]
Round 3: [AD, BC]
```

### ELO Formula

```
K = 32
opponentRating = 1000  (baseline assumption)
expected = 1 / (1 + 10^((opponentRating - myRating) / 400))
newRating = myRating + K × (score - expected)

score: 1.0 = win, 0.5 = draw, 0.0 = loss
```

Implemented in both Dart (`TournamentNotifier._eloUpdate`) and Go (`battle.ELOUpdate`) using `math.pow` — not `^` (XOR).

---

## Testing

### Dart test coverage

| File | What's tested |
|------|--------------|
| `models_test.dart` | Serialisation, UUID generation, copyWith isolation |
| `battle_engine_test.dart` | Engine lifecycle, `_parseJson` (6 variants), all 5 mode prompt builders, scoring, event factories |
| `relay_service_test.dart` | Message type enum exhaustiveness, singleton, initial state |
| `utils_and_extensions_test.dart` | All extension methods, validators, formatters, LobbyCodeUtil |
| `widget_test.dart` | ArenaSection, ArenaToggle, ArenaTextField, ArenaTheme |
| `providers_test.dart` | AppSettings persistence, ModelProviders CRUD, DebugLog cap, Tournament ELO |

### Go test coverage

| File | What's tested |
|------|--------------|
| `hub_test.go` | Create lobby, join, error on nonexistent, duplicate ID rejection, ping/pong, kick auth, public listing, client counts |
| `types_test.go` | Envelope parse/marshal roundtrip, all 23 message types, all 5 roles, client ID assignment |
| `battle_test.go` | VoteResult (6 cases), ELOUpdate (5 cases), ParseSnapshot (4 cases) |
| `auth_test.go` | Empty token allows all, correct token validates, wrong token fails, case sensitivity, constant-time |
| `metrics_test.go` | Summary fields, record operations, SetLobbies |
