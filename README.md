# ⚔️ Prompt Gladiators

**Pit AI models against each other. Let the best mind win.**

Prompt Gladiators is a self-hostable, cross-platform app for running live battles between AI language models. Choose your fighters, set your arena rules, and watch them clash — with judges, voting, spectators, and full multiplayer.

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-54C5F8)
![Go](https://img.shields.io/badge/Go-1.22%2B-00ADD8)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What It Does

- **Battle any model against any model** — connect to LiteLLM and fight GPT-4o vs Gemini vs Llama vs anything with an OpenAI-compatible endpoint
- **5 battle types** — Classic, Battlefield (multi-round back-and-forth), Agentic Swarm (multi-agent with tool use), Tournament (ELO bracket), Commander (human controls system prompt live)
- **Fully configurable** — Judge mode, Scoreboard, Voting, Spectators, Audience controls, Apocalypse escalation, Blind mode — all stackable
- **Real multiplayer** — host a lobby, share a code, spectate live, vote per round
- **Self-hostable** — relay server is a single Go binary; LiteLLM runs as a local sidecar; no cloud dependency

---

## Quick Start

### Prerequisites

| Tool | Min version | Install |
|------|-------------|---------|
| Flutter | 3.19.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.3.0 | Bundled with Flutter |
| Python + pip | 3.9+ | [python.org](https://python.org) |
| LiteLLM | latest | `pip install 'litellm[proxy]'` |

### 1. Clone

```bash
git clone https://github.com/blueplaysgames3921/prompt-gladiators
cd prompt-gladiators
```

### 2. Install Flutter dependencies + generate code

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

> **Why `build_runner`?** Prompt Gladiators uses Freezed (immutable models) and Riverpod code generation. The generated `.freezed.dart` and `.g.dart` files are not committed — you must generate them once before building.

### 3. Configure models

On first launch the app creates a LiteLLM config at:

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/prompt-gladiators/litellm_config.yaml` |
| Linux | `~/.config/prompt-gladiators/litellm_config.yaml` |
| Windows | `%APPDATA%\prompt-gladiators\litellm_config.yaml` |

Edit it to add your API keys, or use **Settings → Internal → LiteLLM Config** in the app. Example:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: gpt-4o
      api_key: sk-...

  - model_name: gemini-2.0-flash
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: AIza...

  - model_name: pollinations
    litellm_params:
      model: openai/openai
      api_base: https://text.pollinations.ai/openai
      api_key: your-pollinations-key
```

### 4. Run

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# Android (device connected)
flutter run -d android

# iOS (device/simulator connected)
flutter run -d ios
```

LiteLLM starts automatically as a background process on desktop. On mobile, configure a remote LiteLLM URL in **Settings → Internal**.

---

## Multiplayer (Relay Server)

### Option A — Docker (easiest)

```bash
cp .env.example .env              # optionally set RELAY_AUTH_TOKEN
cd docker
cp litellm_config.yaml.example litellm_config.yaml
# add your API keys to litellm_config.yaml
docker compose up -d
```

Relay at `ws://localhost:8080`. LiteLLM at `http://localhost:4000`.

### Option B — Go binary

```bash
cd relay
go mod download           # downloads gorilla/websocket, uuid
go build -o prompt-gladiators-relay ./cmd/server
./prompt-gladiators-relay -port 8080 -token "optional-secret"
```

### Option C — make

```bash
cd relay && make run PORT=8080
```

Share your server IP with friends. In the app: **Settings → Internal → Relay URL** → `ws://your-ip:8080`.

---

## Project Structure

```
prompt-gladiators/
├── app/                        Flutter app (all platforms)
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/         Riverpod providers, GoRouter
│   │   │   ├── models/         Freezed data models
│   │   │   ├── services/       LiteLLMService, RelayService
│   │   │   └── utils/          Formatters, validators, platform helpers
│   │   ├── features/
│   │   │   ├── home/           Landing screen
│   │   │   ├── lobby/          Create/join battle
│   │   │   ├── battle/
│   │   │   │   ├── engine/     BattleEngine state machine
│   │   │   │   ├── modes/      BattleModeConfig, CommanderPanel
│   │   │   │   └── widgets/    ModelSelector, FighterCard, PromptInputCard
│   │   │   ├── tournament/     Bracket, ELO leaderboard
│   │   │   ├── settings/       Game / Debug / Internal tabs
│   │   │   └── debug/          Event log, LiteLLM inspector
│   │   └── shared/
│   │       ├── theme/          ArenaTheme (dark, monospace aesthetic)
│   │       ├── widgets/        ArenaSection, ArenaToggle, ArenaTextField
│   │       └── extensions/     BuildContext, String, BattleState, etc.
│   └── test/                   Unit + widget tests
├── relay/                      Go relay server
│   ├── cmd/server/             Entry point (main.go)
│   └── internal/
│       ├── lobby/              Hub, types, client, WS handler
│       ├── battle/             State helpers, ELO
│       └── auth/               Token validation
├── docker/                     Docker Compose setup
├── litellm-sidecar/            Sidecar launcher scripts
└── docs/                       Setup, architecture, battle modes
```

---

## Battle Modes

| Mode | Description |
|------|-------------|
| **Classic** | Same prompt, both respond once, vote the winner |
| **Battlefield** | Multi-round — models respond to each other |
| **Agentic Swarm** | Multiple agents per side with tool use |
| **Tournament** | Round-robin bracket with ELO rankings |
| **Commander** | Human controls system prompt live during battle |

Stack any combination of: Judge · Scoreboard · Voting · Spectators · Audience Controls · Apocalypse Mode · Blind Mode.

See [`docs/BATTLE_MODES.md`](docs/BATTLE_MODES.md) for the full reference.

---

## Settings

Three independent layers:

- **Game** — battle type, rounds, time/token limits, judge, voting, spectators, apocalypse
- **Debug** — verbose logging, raw payloads, token counts, latency, WebSocket inspector, step-through mode
- **Internal** — LiteLLM config editor, relay URL, mid-match overrides (score, state, prompt injection)

---

## Does It Compile?

**Flutter app:**
```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze          # should return no errors
flutter test             # runs all unit/widget tests
flutter build macos      # or windows / linux / apk / ios
```

**Go relay:**
```bash
cd relay
go mod tidy              # generates go.sum with real hashes
go build ./...           # must pass before go test
go test -race ./...      # all tests pass
```

> **Note on `go.sum`:** The `go.sum` file in this repo is a placeholder. Run `go mod tidy` once after cloning to generate real checksums. This requires internet access to fetch `github.com/google/uuid` and `github.com/gorilla/websocket`.

---

## Docs

- [`docs/SETUP.md`](docs/SETUP.md) — full setup, platform-specific notes, troubleshooting
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system design, data flow, state machine
- [`docs/BATTLE_MODES.md`](docs/BATTLE_MODES.md) — all modes and settings reference
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to add modes, settings, relay messages
- [`CHANGELOG.md`](CHANGELOG.md) — version history

---

## License

MIT — self-host freely, fork freely, fight your models freely.
