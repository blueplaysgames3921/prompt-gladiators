# Prompt Gladiators — Quick Start

**You've just extracted the source code. Here's exactly what to do.**

---

## Can it compile?

**Yes** — with two one-time setup steps.

---

## Step 1 — Install tools (once)

```bash
# Flutter (includes Dart)
# → https://flutter.dev/docs/get-started/install

# LiteLLM (the model proxy)
pip install 'litellm[proxy]'

# Go (for the relay server — only needed for multiplayer)
# → https://go.dev/dl/
```

Verify:
```bash
flutter --version    # should print Flutter 3.19+
litellm --version    # should print a version number
go version           # should print go1.22+
```

---

## Step 2 — Generate code (once per clone)

The project uses **Freezed** and **Riverpod** code generation. Generated files
are not committed. You must run this before any `flutter` command:

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected output: files ending in `.freezed.dart` and `.g.dart` appear in
`lib/core/models/` and `lib/core/config/`.

---

## Step 3 — Run

```bash
cd app

# Pick your platform:
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d android    # device must be connected
flutter run -d ios        # requires Xcode
```

The app launches, LiteLLM starts automatically in the background (desktop only),
and you land on the Prompt Gladiators home screen.

---

## Step 4 — Add your first model

Go to **Settings → Internal → LiteLLM Config** and add at least one model.
The fastest way to get started with no API key is Pollinations.ai:

```yaml
model_list:
  - model_name: pollinations
    litellm_params:
      model: openai/openai
      api_base: https://text.pollinations.ai/openai
      api_key: your-pollinations-key
```

Tap **SAVE & APPLY**, then restart LiteLLM from the same screen.

---

## Step 5 — Start a battle

1. Tap **NEW BATTLE** on the home screen
2. Enter a model ID in both Fighter A and Fighter B fields
   (they appear in the dropdown once LiteLLM is running)
3. Type a battle prompt — or pick a suggestion
4. Tap **LAUNCH BATTLE**

---

## Multiplayer

To host a lobby others can join:

```bash
# Terminal 1 — relay server
cd relay
go mod tidy          # generates go.sum (first time only)
go run ./cmd/server -port 8080

# In the app: Settings → Internal → Relay URL → ws://localhost:8080 → Connect
# Then: New Battle → MULTIPLAYER tab → Create Lobby
```

Share the lobby code with anyone on your network.

---

## Run tests

```bash
# Flutter
cd app && flutter test

# Go
cd relay && go mod tidy && go test -race ./...
```

---

## What's in this archive

```
prompt-gladiators/
├── QUICKSTART.md          ← you are here
├── README.md              ← full overview
├── CONTRIBUTING.md        ← developer guide
├── CHANGELOG.md           ← version history
├── .env.example           ← Docker env vars template
├── app/                   ← Flutter app (iOS/Android/macOS/Windows/Linux)
├── relay/                 ← Go WebSocket relay server
├── docker/                ← Docker Compose (relay + LiteLLM)
├── litellm-sidecar/       ← LiteLLM launcher script
└── docs/
    ├── SETUP.md           ← full setup with troubleshooting
    ├── ARCHITECTURE.md    ← system design
    └── BATTLE_MODES.md    ← all modes and settings reference
```

---

## Troubleshooting

**`dart run build_runner build` fails**
→ Run `flutter pub get` first, then retry.

**"No models found" in model selector**
→ LiteLLM isn't running or has no models configured.
→ Check Settings → Debug → LiteLLM Status Panel.

**`go test` fails with "cannot find module"**
→ Run `go mod tidy` inside `relay/` first.

**`flutter run` fails — no device found**
→ Run `flutter doctor` to diagnose your toolchain.

Full troubleshooting: [`docs/SETUP.md`](docs/SETUP.md)
