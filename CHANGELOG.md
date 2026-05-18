# Changelog

All notable changes to Prompt Gladiators are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased] — 0.1.0-alpha

### Added

#### App
- **Home screen** — responsive wide/narrow layout, animated spinning logo with dual counter-rotating arcs (fighter A blue, fighter B red), hover-highlight menu items with keyboard shortcut badges, animated status pills with glow, dual radial grid, scanline overlay
- **Lobby screen** — `FighterCard` with live `ModelSelector` dropdown (populated from LiteLLM), collapsible system prompt editor with dirty-state dot indicator; `PromptInputCard` with mode-aware suggestion chips; `SettingsSummaryChips` chip row; local/multiplayer mode tab toggle; lobby code card with clipboard copy
- **Battle screen** — animated score ratio bar, per-fighter thinking indicator (bouncing bars), per-round `_RoundCard` with markdown rendering, debug token/latency readouts, vote tally with animated bars, judge verdict chip, raw payload collapsible; `CommanderPanel` wired as side panel with A/B side picker in AppBar; mid-match settings sheet with score override and prompt injection (gated by internal settings); confirm-exit dialog when battle is live; debug side panel live-wired to `DebugLogNotifier`
- **Tournament screen** — ELO leaderboard (sorted, medal icons), round-robin bracket generator (no fighter plays twice per round), match history with winner highlight
- **Settings screen** — three-tab layout (Game / Debug / Internal); `ArenaSection`, `ArenaToggle`, `ArenaTextField` shared widgets; LiteLLM YAML config editor; relay URL + token fields; all internal override toggles
- **Debug screen** — event log (newest first, split view with payload inspector), LiteLLM health panel with model list, battle state JSON viewer with copy button

#### Core
- `BattleEngine` — `BattleModeConfig`-driven prompt generation per round per fighter; apocalypse level passed through `BattleModeContext`; `_parseJson` handles clean JSON, markdown-fenced JSON, prose-embedded JSON; `parseJsonForTest` exposed with `@visibleForTesting`
- `BattleModeConfig` — per-mode default system prompts, prompt builder functions, round constraints, capability flags for all 5 types (Classic, Battlefield, Agentic, Tournament, Commander)
- `BattleModeContext` — carries roundNumber, totalRounds, basePrompt, opponentLastResponse, ownLastResponse, fighterName, opponentName, apocalypseLevel, injectedContext
- `LiteLLMService` — auto-launch sidecar on desktop, `dart:async` for `TimeoutException`, health polling, config read/write
- `RelayService` — WebSocket client, full lobby/battle/audience message types, `_assertRole` with correct hierarchy (no dead `orHigher:` param)
- Riverpod providers — all stream subscriptions stored and cancelled via `ref.onDispose`; `LiteLLMStatusNotifier` uses `_active` flag instead of `disposed` enum; `ActiveBattleNotifier` stores `_relaySub` and cancels on dispose

#### Go relay
- Hub — lobby lifecycle (create/join/leave), role assignment, kick/mute, public lobby listing, empty lobby cleanup
- WebSocket handler — upgrader, ping/pong keepalive, token auth via `Authorization` header or `?token=` query param
- Auth package — constant-time token comparison
- Battle package — `ParseSnapshot`, `VoteResult`, `ELOUpdate` (K=32, Taylor-series `pow10`)
- Metrics package — atomic counters for messages, connects, active clients/lobbies
- Graceful shutdown on SIGINT/SIGTERM

#### Developer tooling
- `app/Makefile` — get/gen/test/lint/fmt/run/build targets for all platforms
- `relay/Makefile` — build/test/run/lint/docker/fmt/vuln targets
- `analysis_options.yaml` — strict lints (strict-casts, strict-inference, strict-raw-types, 50+ lint rules)
- `CONTRIBUTING.md` — layout reference, how-to guides for adding modes/settings/messages, code style, commit format, release checklist
- Platform configs — Android manifest + build.gradle, macOS entitlements (debug + release), iOS Info.plist (ATS config, local network usage), Windows CMakeLists + main.cpp, Linux CMakeLists + main.cc
- Docker Compose — relay + LiteLLM services with healthchecks; relay Dockerfile (multi-stage scratch image)
- LiteLLM sidecar launcher script (`start.sh`) with health polling and PID management

#### Tests — 200+ test cases across 7 files
- `models_test.dart` — FighterConfig, BattleSettings, BattleState, BattleRound, AppSettings, InternalSettings, TournamentEntry
- `battle_engine_test.dart` — lifecycle, `parseJsonForTest` (6 variants), BattleModeConfig prompt builders (all 5 modes + edge cases), scoring logic, BattleEvent factories
- `relay_service_test.dart` — message type coverage, enum exhaustiveness, singleton
- `utils_and_extensions_test.dart` — StringX, BattleStateX, BattleSettingsX, FighterConfigX, BattleRoundX, LobbyMemberX, ListX, ModelIdUtil, DurationFormat, TokenFormat, Validators, LobbyCodeUtil
- `widget_test.dart` — ArenaSection, ArenaToggle, ArenaTextField, ArenaTheme
- `relay/internal/battle/battle_test.go` — VoteResult, ELOUpdate, ParseSnapshot
- `relay/internal/auth/auth_test.go` — token validation, case-sensitivity, constant-time

### Fixed
- `_parseJson` — completely rewritten; was a nonsensical JS-ism returning empty map always
- `_assertRole` — removed unused `orHigher:` param from all call sites
- `FighterConfig.id` — now UUID-generated via `.create()` factory (was always `''`)
- `_escalatePrompt` — removed dead method; apocalypse handled via `BattleModeContext.apocalypseLevel`
- `TournamentState`/`TournamentMatch` — moved from `providers.dart` to `models.dart` (eliminates double-`part` collision)
- `DurationX` — renamed `IntDurationX`, removed `.ms`/`.seconds` that conflicted with `flutter_animate`
- `battle_screen` — `ConsumerStatefulWidget` (was plain `StatefulWidget`, not wired to Riverpod)
- `commander_panel` import path — was `../battle/modes/` (wrong), now `modes/` (correct relative path)
- `relay_service.dart` — removed `headers` unused variable in `connect()`; clarified auth via first-message pattern
- `home_screen` — added missing `relay_service.dart` import for `RelayConnectionStatus`
- `litellm_service` — added `dart:async` import for `TimeoutException`
- All stream subscriptions in providers — stored in variables, cancelled via `ref.onDispose` or `dispose()` override; eliminates 4 leak points
- `LiteLLMStatus.disposed` — removed unused enum value; poll loop now uses `_active` bool flag guarded by `ref.onDispose`
- ELO calculation — `^` (XOR) replaced with `math.pow` (Go) and `math.pow` (Dart)
