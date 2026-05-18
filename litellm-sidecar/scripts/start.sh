#!/usr/bin/env bash
# Prompt Gladiators — LiteLLM Sidecar Launcher
# Called automatically by the Flutter desktop app on startup.
# Can also be run manually for debugging.

set -euo pipefail

PORT="${LITELLM_PORT:-4000}"
CONFIG="${LITELLM_CONFIG:-$HOME/.config/prompt-gladiators/litellm_config.yaml}"
VERBOSE="${LITELLM_VERBOSE:-false}"
PID_FILE="${TMPDIR:-/tmp}/prompt-gladiators-litellm.pid"

# ─── Check dependencies ───────────────────────────────────────────────────────

if ! command -v litellm &>/dev/null; then
  echo "[arena] LiteLLM not found. Install with: pip install litellm"
  echo "[arena] Or: pip install 'litellm[proxy]'"
  exit 1
fi

# ─── Kill any existing instance ───────────────────────────────────────────────

if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "[arena] Stopping existing LiteLLM (PID $OLD_PID)..."
    kill "$OLD_PID" || true
    sleep 1
  fi
  rm -f "$PID_FILE"
fi

# ─── Create default config if missing ────────────────────────────────────────

CONFIG_DIR=$(dirname "$CONFIG")
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG" ]]; then
  echo "[arena] Creating default LiteLLM config at $CONFIG"
  cp "$(dirname "$0")/../configs/default_litellm_config.yaml" "$CONFIG" 2>/dev/null || cat > "$CONFIG" <<'YAML'
model_list:
  - model_name: pollinations/openai
    litellm_params:
      model: openai/openai
      api_base: https://text.pollinations.ai/openai
      api_key: your-pollinations-key

litellm_settings:
  drop_params: true
  set_verbose: false
YAML
fi

# ─── Start LiteLLM ───────────────────────────────────────────────────────────

VERBOSE_FLAG=""
if [[ "$VERBOSE" == "true" ]]; then
  VERBOSE_FLAG="--detailed_debug"
fi

echo "[arena] Starting LiteLLM on port $PORT..."
echo "[arena] Config: $CONFIG"

litellm --config "$CONFIG" --port "$PORT" $VERBOSE_FLAG &
LITELLM_PID=$!
echo $LITELLM_PID > "$PID_FILE"

# ─── Wait for ready ───────────────────────────────────────────────────────────

RETRIES=30
while [[ $RETRIES -gt 0 ]]; do
  if curl -sf "http://localhost:$PORT/health" &>/dev/null; then
    echo "[arena] ✓ LiteLLM ready on http://localhost:$PORT"
    exit 0
  fi
  sleep 0.5
  RETRIES=$((RETRIES - 1))
done

echo "[arena] ✗ LiteLLM did not become ready in time"
kill $LITELLM_PID 2>/dev/null || true
exit 1
