# Setup Guide

## Prerequisites

### Required for all platforms

| Tool | Min version | Check | Install |
|------|-------------|-------|---------|
| Flutter | 3.19.0 | `flutter --version` | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.3.0 | `dart --version` | Bundled with Flutter |
| Python | 3.9+ | `python3 --version` | [python.org](https://python.org) |
| pip | latest | `pip --version` | Bundled with Python 3.4+ |
| LiteLLM | latest | `litellm --version` | `pip install 'litellm[proxy]'` |

### Required for relay server (multiplayer)

| Tool | Min version | Check | Install |
|------|-------------|-------|---------|
| Go | 1.22+ | `go version` | [go.dev/dl](https://go.dev/dl/) |
| Docker | 24+ | `docker --version` | [docker.com](https://docker.com) *(optional, for Docker Compose setup)* |

---

## Step 1 — Clone the repository

```bash
git clone https://github.com/yourusername/prompt-gladiators
cd prompt-gladiators
```

---

## Step 2 — Install Flutter dependencies

```bash
cd app
flutter pub get
```

---

## Step 3 — Generate code (required)

Prompt Gladiators uses **Freezed** for immutable models and **Riverpod** code generation. The generated files (`.freezed.dart`, `.g.dart`) are not committed to the repo — you must generate them once before any build.

```bash
cd app   # must be inside the app/ directory
dart run build_runner build --delete-conflicting-outputs
```

Expected output: several `*.freezed.dart` and `*.g.dart` files created in `lib/core/models/` and `lib/core/config/`.

If you see conflicts, use:
```bash
dart run build_runner build --delete-conflicting-outputs
```

For ongoing development with auto-regeneration on file save:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Step 4 — Configure LiteLLM

LiteLLM is the universal model proxy. It starts automatically when you launch the desktop app, but you need to add your API keys first.

### Config file location

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/prompt-gladiators/litellm_config.yaml` |
| Linux | `~/.config/prompt-gladiators/litellm_config.yaml` |
| Windows | `%APPDATA%\prompt-gladiators\litellm_config.yaml` |

The app creates a default config on first launch. You can also edit it at any time via **Settings → Internal → LiteLLM Config** inside the app.

### Example configurations

**Pollinations.ai (free tier):**
```yaml
model_list:
  - model_name: pollinations
    litellm_params:
      model: openai/openai
      api_base: https://text.pollinations.ai/openai
      api_key: your-pollinations-key
```

**Multiple providers:**
```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: gpt-4o
      api_key: sk-...

  - model_name: gpt-4o-mini
    litellm_params:
      model: gpt-4o-mini
      api_key: sk-...

  - model_name: gemini-2.0-flash
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: AIza...

  - model_name: llama-3-70b
    litellm_params:
      model: groq/llama-3-70b-8192
      api_key: gsk_...

  - model_name: grok-2
    litellm_params:
      model: xai/grok-2-latest
      api_key: xai-...

  - model_name: local-ollama
    litellm_params:
      model: ollama/llama3
      api_base: http://localhost:11434

litellm_settings:
  drop_params: true
  set_verbose: false
```

---

## Step 5 — Run the app

### Desktop (recommended for development)

```bash
cd app

# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

LiteLLM starts automatically as a background sidecar process. Watch the debug console in the app (Settings → Debug → LiteLLM Status Panel) to confirm it's healthy.

### Mobile

LiteLLM cannot run as a local process on mobile. Two options:

**Option A — Use Pollinations.ai directly** (no extra setup)
Configure Pollinations in your LiteLLM config. The app talks to it over the internet.

**Option B — Point mobile at desktop LiteLLM**
1. Start LiteLLM manually on your desktop, bound to all interfaces:
   ```bash
   litellm --config ~/.config/prompt-gladiators/litellm_config.yaml \
           --port 4000 \
           --host 0.0.0.0
   ```
2. Find your desktop's LAN IP: `ifconfig` / `ipconfig`
3. In the app: **Settings → Internal → LiteLLM URL** → `http://192.168.x.x:4000`

```bash
# Android
flutter run -d android

# iOS (requires Xcode + provisioning profile)
flutter run -d ios
```

---

## Step 6 — Build for release

```bash
cd app

# macOS app bundle
flutter build macos --release

# Windows MSIX / executable
flutter build windows --release

# Linux AppImage
flutter build linux --release

# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires Apple developer account)
flutter build ios --release
```

---

## Step 7 — Relay server (multiplayer)

The relay server enables lobby creation, spectating, live voting, and real-time battle sync between multiple players.

### Generate go.sum first

The `go.sum` file in this repo is a placeholder. Generate real checksums before building:

```bash
cd relay
go mod tidy
```

This downloads `github.com/google/uuid` and `github.com/gorilla/websocket` and writes `go.sum`.

### Option A — Docker Compose (easiest, includes LiteLLM)

```bash
# From repo root
cp .env.example .env
# Edit .env if you want to set RELAY_AUTH_TOKEN

cd docker
cp litellm_config.yaml.example litellm_config.yaml
# Edit litellm_config.yaml with your API keys

docker compose up -d
```

Services:
- Relay WebSocket: `ws://localhost:8080`
- LiteLLM proxy: `http://localhost:4000`

### Option B — Go binary

```bash
cd relay
go mod tidy              # generates go.sum
go build -o prompt-gladiators-relay ./cmd/server

# Run locally
./prompt-gladiators-relay -port 8080

# Run with auth token (recommended if exposed to internet)
./prompt-gladiators-relay -port 8080 -token "your-secret-token"
```

### Option C — make

```bash
cd relay
make deps    # go mod download + tidy
make build   # builds binary
make run     # builds and runs on port 8080
make test    # runs all Go tests with race detector
```

### Connecting the app to the relay

1. Go to **Settings → Internal → Relay Server**
2. Set URL: `ws://your-server-ip:8080`
3. Set auth token (if configured)
4. Tap **Connect**

---

## Running Tests

### Dart / Flutter

```bash
cd app
flutter test                     # all tests
flutter test --coverage          # with coverage report
flutter analyze                  # static analysis (should return 0 errors)
```

### Go

```bash
cd relay
go mod tidy                      # ensure go.sum is current
go test -v -race ./...           # all packages with race detector
go vet ./...                     # static analysis
```

---

## Troubleshooting

### `dart run build_runner build` fails

Check the error message. Common causes:
- **Conflicting outputs**: run with `--delete-conflicting-outputs`
- **Syntax error in models.dart**: fix the error first, then regenerate
- **Missing dependency**: run `flutter pub get` first

### LiteLLM won't start

```bash
# Check it's installed
litellm --version

# Install if missing
pip install 'litellm[proxy]'

# Check port 4000 isn't in use
lsof -i :4000         # macOS/Linux
netstat -ano | findstr :4000   # Windows

# Start manually to see errors
litellm --config ~/.config/prompt-gladiators/litellm_config.yaml --port 4000
```

### No models appear in the model selector

```bash
# Test LiteLLM directly
curl http://localhost:4000/v1/models

# Check health
curl http://localhost:4000/health
```

If LiteLLM returns no models, check your `litellm_config.yaml` has valid `model_list` entries with correct API keys.

### `flutter run` fails with "No supported devices found"

```bash
flutter devices          # list connected devices
flutter doctor           # diagnose missing toolchains
```

### `go build` fails with "cannot find module"

```bash
cd relay
go mod tidy              # downloads and generates go.sum
go build ./...
```

### Relay connection fails in-app

```bash
# Test relay health
curl http://your-server-ip:8080/health

# Check firewall allows port 8080
# On Linux: ufw allow 8080/tcp
# Check relay is bound to 0.0.0.0 not 127.0.0.1
```

### Mobile can't reach LiteLLM

1. Desktop and mobile must be on the same LAN
2. Start LiteLLM with `--host 0.0.0.0`
3. Check your desktop's firewall allows port 4000
4. Verify the IP address: `ifconfig | grep inet` (macOS/Linux)

---

## Environment Variables

The Docker Compose setup reads from `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_PORT` | `8080` | Port for the relay WebSocket server |
| `RELAY_AUTH_TOKEN` | *(empty)* | Bearer token for relay auth. Empty = no auth. |
| `LITELLM_PORT` | `4000` | Port for the LiteLLM proxy |

---

## Platform Notes

### macOS
- App sandbox is **disabled** in entitlements to allow spawning the LiteLLM subprocess
- For App Store distribution, the sidecar approach won't work — you'd need to replace it with a helper tool or XPC service
- Minimum macOS version: 10.14 (Mojave)

### Windows
- Requires Visual Studio Build Tools 2019+ for Flutter Windows builds
- Run as normal user — no admin rights needed for local LiteLLM

### Linux
- Requires GTK 3.0: `sudo apt install libgtk-3-dev`
- Requires Ninja build system: `sudo apt install ninja-build`
- LiteLLM sidecar uses `bash` — ensure `/bin/bash` exists

### Android
- Minimum SDK: 24 (Android 7.0)
- `NSAllowsArbitraryLoads` equivalent: `android:usesCleartextTraffic="true"` in manifest (for localhost LiteLLM)

### iOS
- Requires Xcode 15+ and a valid signing identity
- `NSLocalNetworkUsageDescription` set for LAN relay discovery
- ATS `NSAllowsArbitraryLoads: true` for local LiteLLM HTTP (test builds only — for production use HTTPS)
