# Contributing

## Development Setup

```bash
git clone https://github.com/yourusername/prompt-gladiators
cd prompt-gladiators

# Flutter app
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Go relay
cd ../relay
go mod download
```

## Project Layout

```
app/lib/
  core/
    config/         # Riverpod providers, GoRouter
    models/         # All Freezed data models
    services/       # LiteLLMService, RelayService
    utils/          # PlatformUtil, Validators, ModelIdUtil, formatters
  features/
    home/           # Landing screen
    lobby/          # Create/join battle
    battle/
      engine/       # BattleEngine — core state machine
      modes/        # BattleModeConfig, CommanderPanel
      widgets/      # ModelSelector, FighterCard, PromptInputCard
    tournament/     # Bracket, leaderboard, ELO
    settings/       # Game / Debug / Internal settings
    debug/          # Event log, LiteLLM inspector, state viewer
  shared/
    theme/          # ArenaTheme
    widgets/        # ArenaSection, ArenaToggle, ArenaTextField
    extensions/     # BuildContext, String, BattleState, etc.

relay/
  cmd/server/       # main.go — entry point
  internal/
    lobby/          # Hub, types, client
    battle/         # Battle helpers, ELO
    ws/             # WebSocket handler
    auth/           # Token validation
  pkg/
    metrics/        # In-memory counters
```

## Making Changes

### Adding a new battle mode

1. Add a value to `BattleType` in `models.dart`
2. Add a `BattleModeConfig` entry in `battle_mode_config.dart`
3. Update `BattleModes.forType()` switch
4. Update `_BattleTypeBadge` in `battle_screen.dart`
5. Add a description to `docs/BATTLE_MODES.md`

### Adding a new setting

**Game setting:**
1. Add field to `BattleSettings` in `models.dart` (with `@Default`)
2. Add UI toggle/slider in `_GameSettingsTab` in `settings_screen.dart`
3. Wire into `BattleEngine` or relay as needed

**Debug setting:**
1. Add field to `DebugSettings`
2. Add toggle in `_DebugSettingsTab`
3. Wire into the relevant service/widget

**Internal setting:**
1. Add field to `InternalSettings`
2. Add control in `_InternalSettingsTab`
3. Wire into `LiteLLMService` or `RelayService`

After any model changes, regenerate code:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

### Adding a relay message type

1. Add to `RelayMessageType` enum in `relay_service.dart` (Dart)
2. Add to `MessageType` constants in `relay/internal/lobby/types.go` (Go)
3. Add handler in `hub.go` `route()` switch
4. Wire the new message in `providers.dart` `_wireRelay()`

## Code Style

**Dart:**
- Strict analysis options enforced (`analysis_options.yaml`)
- Private widgets prefixed with `_`
- Extensions in `shared/extensions/extensions.dart`
- Use `FighterConfigX.displayName` not inline `isEmpty` checks
- Never hardcode colors — use `ArenaTheme.*`

**Go:**
- Standard `gofmt` formatting
- Errors wrapped with context
- Tests in `_test.go` files in same package (`package X_test`)
- Use `metrics.RecordMessage()` in hot paths

## Running Tests

```bash
# Dart
cd app && flutter test

# Go
cd relay && go test -v -race ./...

# Both with coverage
cd app && flutter test --coverage
cd relay && go test -race -coverprofile=coverage.out ./... && go tool cover -html=coverage.out
```

## Commit Style

```
feat: add voting weight slider to game settings
fix: remove duplicate TournamentState from providers.dart
test: add BattleEngine.parseJsonForTest coverage
refactor: replace inline isEmpty checks with displayName extension
docs: add BATTLE_MODES.md reference
```

## Release Checklist

- [ ] `dart run build_runner build` passes cleanly
- [ ] `flutter analyze` returns no errors
- [ ] `flutter test` all pass
- [ ] `go test -race ./...` all pass
- [ ] `go vet ./...` clean
- [ ] `docs/SETUP.md` updated if config changed
- [ ] `CHANGELOG.md` entry added
