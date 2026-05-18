import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/litellm_service.dart';
import '../services/relay_service.dart';
import '../../features/battle/engine/battle_engine.dart';

part 'providers.g.dart';

// ─── SharedPreferences ────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return SharedPreferences.getInstance();
}

// ─── App Settings ─────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  static const _key = 'app_settings_v1';

  @override
  Future<AppSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> updateBattle(BattleSettings battle) => _update(
        (s) => s.copyWith(battle: battle),
      );

  Future<void> updateDebug(DebugSettings debug) => _update(
        (s) => s.copyWith(debug: debug),
      );

  Future<void> updateInternal(InternalSettings internal) => _update(
        (s) => s.copyWith(internal: internal),
      );

  Future<void> _update(AppSettings Function(AppSettings) fn) async {
    final current = await future;
    final updated = fn(current);
    state = AsyncData(updated);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_key, jsonEncode(updated.toJson()));
  }
}

// ─── Model Providers (saved endpoints) ────────────────────────────────────────

@Riverpod(keepAlive: true)
class ModelProvidersNotifier extends _$ModelProvidersNotifier {
  static const _key = 'model_providers_v1';

  @override
  Future<List<ModelProvider>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final raw = prefs.getString(_key);
    if (raw == null) return _defaults;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ModelProvider.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaults;
    }
  }

  Future<void> add(ModelProvider provider) async {
    final current = await future;
    await _save([...current, provider]);
  }

  Future<void> update(ModelProvider provider) async {
    final current = await future;
    final updated = current.map((p) => p.id == provider.id ? provider : p).toList();
    await _save(updated);
  }

  Future<void> remove(String id) async {
    final current = await future;
    await _save(current.where((p) => p.id != id).toList());
  }

  Future<void> _save(List<ModelProvider> providers) async {
    state = AsyncData(providers);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(
      _key,
      jsonEncode(providers.map((p) => p.toJson()).toList()),
    );
  }

  static const _defaults = <ModelProvider>[];
}

// ─── Available Models (fetched from LiteLLM) ──────────────────────────────────

@riverpod
Future<List<String>> availableModels(Ref ref) async {
  // Re-fetch when settings change
  ref.watch(appSettingsNotifierProvider);
  return LiteLLMService.instance.listModels();
}

// ─── LiteLLM Status ───────────────────────────────────────────────────────────

@riverpod
class LiteLLMStatusNotifier extends _$LiteLLMStatusNotifier {
  bool _active = false;

  @override
  LiteLLMStatus build() {
    _active = true;
    ref.onDispose(() => _active = false);
    // Kick off the poll loop after a short delay to let the sidecar start.
    Future.delayed(const Duration(seconds: 2), _poll);
    return LiteLLMStatus.unknown;
  }

  Future<void> _poll() async {
    if (!_active) return;
    final healthy = await LiteLLMService.instance.healthCheck();
    if (!_active) return;
    state = healthy ? LiteLLMStatus.healthy : LiteLLMStatus.unreachable;
    await Future.delayed(const Duration(seconds: 10));
    if (_active) _poll();
  }

  Future<void> restart() async {
    state = LiteLLMStatus.starting;
    try {
      final settings = await ref.read(appSettingsNotifierProvider.future);
      await LiteLLMService.instance.restart(
          port: settings.internal.liteLLMPort);
      state = LiteLLMStatus.healthy;
    } catch (_) {
      state = LiteLLMStatus.unreachable;
    }
  }
}

enum LiteLLMStatus { unknown, starting, healthy, unreachable }

// ─── Relay Connection ─────────────────────────────────────────────────────────

@riverpod
class RelayConnectionNotifier extends _$RelayConnectionNotifier {
  @override
  RelayConnectionStatus build() {
    final sub = RelayService.instance.connectionStatus.listen((status) {
      state = status;
    });
    ref.onDispose(sub.cancel);
    return RelayConnectionStatus.disconnected;
  }

  Future<void> connect() async {
    final settings = await ref.read(appSettingsNotifierProvider.future);
    await RelayService.instance.connect(
      settings.internal.relayUrl,
      authToken: settings.internal.relayAuthToken.isEmpty
          ? null
          : settings.internal.relayAuthToken,
    );
  }

  Future<void> disconnect() => RelayService.instance.disconnect();
}

// ─── Active Battle ────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class ActiveBattleNotifier extends _$ActiveBattleNotifier {
  BattleEngine? _engine;
  StreamSubscription<RelayMessage>? _relaySub;

  @override
  BattleState? build() => null;

  /// Create and configure a new local battle.
  void createBattle({
    required BattleSettings settings,
    required FighterConfig fighterA,
    required FighterConfig fighterB,
  }) {
    _engine?.dispose();
    _engine = BattleEngine(
      settings: settings,
      onStateUpdate: (s) => state = s,
    );
    _engine!.configure(fighterA: fighterA, fighterB: fighterB);
    state = _engine!.state;

    // Wire relay messages to engine if multiplayer
    if (settings.multiplayerEnabled) {
      _wireRelay();
    }
  }

  /// Load battle state pushed by relay (spectator/remote player).
  void loadRemoteState(BattleState remoteState) {
    state = remoteState;
  }

  Future<void> start(String prompt) => _engine!.start(prompt);
  Future<void> pause() => _engine!.pause();
  Future<void> resume() => _engine!.resume();

  void vote(int roundNumber, String voterId, String choice) {
    _engine?.submitVote(roundNumber.toString(), voterId, choice);
    // Also relay to other spectators
    RelayService.instance.castVote(roundNumber, choice);
  }

  void injectPrompt(String injection) {
    _engine?.injectPrompt(injection);
    RelayService.instance.injectPrompt(injection);
  }

  void overrideScore({required double a, required double b}) {
    _engine?.overrideScore(scoreA: a, scoreB: b);
  }

  void swapModel(FighterSide side, FighterConfig newFighter) {
    if (state == null) return;
    state = side == FighterSide.a
        ? state!.copyWith(fighterA: newFighter)
        : state!.copyWith(fighterB: newFighter);
    _engine?.configure(
      fighterA: state!.fighterA,
      fighterB: state!.fighterB,
    );
  }

  Stream<BattleEvent> get events =>
      _engine?.events ?? const Stream.empty();

  void _wireRelay() {
    _relaySub?.cancel();
    _relaySub = RelayService.instance.messages.listen((msg) {
      switch (msg.type) {
        case RelayMessageType.battleStateSync:
          final remoteState = BattleState.fromJson(
            msg.payload['state'] as Map<String, dynamic>,
          );
          loadRemoteState(remoteState);
        case RelayMessageType.castVote:
          _engine?.submitVote(
            msg.payload['roundNumber'].toString(),
            msg.payload['voterId'] as String,
            msg.payload['choice'] as String,
          );
        case RelayMessageType.injectPrompt:
          _engine?.injectPrompt(msg.payload['injection'] as String);
        case RelayMessageType.pauseBattle:
          _engine?.pause();
        case RelayMessageType.resumeBattle:
          _engine?.resume();
        case RelayMessageType.updateSystemPrompt:
          final side =
              FighterSide.values.byName(msg.payload['side'] as String);
          final prompt = msg.payload['systemPrompt'] as String;
          if (state == null) return;
          state = side == FighterSide.a
              ? state!.copyWith(
                  fighterA: state!.fighterA.copyWith(systemPrompt: prompt),
                )
              : state!.copyWith(
                  fighterB: state!.fighterB.copyWith(systemPrompt: prompt),
                );
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _relaySub?.cancel();
    _engine?.dispose();
    super.dispose();
  }
}

// ─── Lobby Members ────────────────────────────────────────────────────────────

@riverpod
class LobbyMembersNotifier extends _$LobbyMembersNotifier {
  @override
  List<LobbyMember> build() {
    final sub = RelayService.instance.messages.listen((msg) {
      if (msg.type == RelayMessageType.lobbyState) {
        final membersJson = msg.payload['members'] as List<dynamic>? ?? [];
        state = membersJson
            .map((e) => LobbyMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
    ref.onDispose(sub.cancel);
    return [];
  }
}

// ─── Debug Log ────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class DebugLogNotifier extends _$DebugLogNotifier {
  static const _maxEntries = 500;

  @override
  List<DebugLogEntry> build() {
    final sub = RelayService.instance.messages.listen((msg) {
      append(DebugLogEntry(
        source: 'RELAY',
        direction: LogDirection.inbound,
        label: msg.type.name,
        payload: msg.payload,
      ));
    });
    ref.onDispose(sub.cancel);
    return [];
  }

  void append(DebugLogEntry entry) {
    final updated = [...state, entry];
    state = updated.length > _maxEntries
        ? updated.sublist(updated.length - _maxEntries)
        : updated;
  }

  void clear() => state = [];
}

class DebugLogEntry {
  final DateTime timestamp;
  final String source;
  final LogDirection direction;
  final String label;
  final Map<String, dynamic> payload;

  DebugLogEntry({
    required this.source,
    required this.direction,
    required this.label,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum LogDirection { inbound, outbound, internal }

// ─── Tournament ────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class TournamentNotifier extends _$TournamentNotifier {
  static const _key = 'tournament_v1';

  @override
  Future<TournamentState> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final raw = prefs.getString(_key);
    if (raw == null) return const TournamentState();
    try {
      return TournamentState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TournamentState();
    }
  }

  Future<void> addEntry(TournamentEntry entry) async {
    final current = await future;
    final updated = current.copyWith(entries: [...current.entries, entry]);
    await _save(updated);
  }

  Future<void> recordResult({
    required String winnerId,
    required String loserId,
    bool draw = false,
  }) async {
    final current = await future;
    final entries = current.entries.map((e) {
      if (e.id == winnerId) {
        return draw
            ? e.copyWith(draws: e.draws + 1, eloRating: _eloUpdate(e.eloRating, false, isDraw: true))
            : e.copyWith(wins: e.wins + 1, eloRating: _eloUpdate(e.eloRating, true));
      } else if (e.id == loserId) {
        return draw
            ? e.copyWith(draws: e.draws + 1, eloRating: _eloUpdate(e.eloRating, false, isDraw: true))
            : e.copyWith(losses: e.losses + 1, eloRating: _eloUpdate(e.eloRating, false));
      }
      return e;
    }).toList();
    await _save(current.copyWith(entries: entries));
  }

  Future<void> clear() async => _save(const TournamentState());

  Future<void> _save(TournamentState s) async {
    state = AsyncData(s);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  /// Simple ELO update — K=32, assumes opponent ~1000 ELO
  int _eloUpdate(int rating, bool won, {bool isDraw = false}) {
    const k = 32;
    const opponentRating = 1000;
    // Expected score using standard ELO formula
    final expected = 1.0 / (1.0 + math.pow(10, (opponentRating - rating) / 400.0));
    final score = isDraw ? 0.5 : (won ? 1.0 : 0.0);
    return (rating + k * (score - expected)).round();
  }
}

// ─── Tournament State ─────────────────────────────────────────────────────────
// TournamentState and TournamentMatch are defined in core/models/models.dart
// and generated by build_runner alongside the other Freezed models.
