import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'models.freezed.dart';
part 'models.g.dart';

const _uuid = Uuid();

// ─── Battle Type ────────────────────────────────────────────────────────────

enum BattleType {
  classic,      // same prompt, one round, vote
  battlefield,  // multi-round back and forth
  agenticSwarm, // multi-agent with tool use
  tournament,   // bracket + ELO
  commander,    // human controls system prompt live
}

// ─── Fighter / Model Config ──────────────────────────────────────────────────

@freezed
class FighterConfig with _$FighterConfig {
  const factory FighterConfig({
    required String id,
    required String name,
    required String modelId,        // e.g. "gpt-4o", "gemini-1.5-pro"
    required String endpointUrl,    // LiteLLM or direct
    String? apiKey,
    @Default('') String systemPrompt,
    @Default(FighterSide.a) FighterSide side,
    @Default(1) int agentCount,     // for agentic swarm
    @Default([]) List<AgentTool> allowedTools,
  }) = _FighterConfig;

  factory FighterConfig.create({
    required String name,
    required String modelId,
    String endpointUrl = 'http://localhost:4000',
    String systemPrompt = '',
    FighterSide side = FighterSide.a,
    int agentCount = 1,
    List<AgentTool> allowedTools = const [],
    String? apiKey,
  }) =>
      FighterConfig(
        id: _uuid.v4(),
        name: name,
        modelId: modelId,
        endpointUrl: endpointUrl,
        systemPrompt: systemPrompt,
        side: side,
        agentCount: agentCount,
        allowedTools: allowedTools,
        apiKey: apiKey,
      );

  factory FighterConfig.fromJson(Map<String, dynamic> json) =>
      _$FighterConfigFromJson(json);
}

enum FighterSide { a, b }

enum AgentTool { webSearch, codeExecution, fileIO, spawnSubAgents }

// ─── Battle Settings ─────────────────────────────────────────────────────────

@freezed
class BattleSettings with _$BattleSettings {
  const factory BattleSettings({
    // Core
    @Default(BattleType.classic) BattleType battleType,
    @Default(3) int roundCount,
    @Default(60) int timeLimitSeconds,    // 0 = unlimited
    @Default(2000) int tokenLimitPerTurn, // 0 = unlimited
    @Default(false) bool blindMode,       // hide model identities until end

    // Judge
    @Default(false) bool judgeEnabled,
    String? judgeModelId,
    @Default('Score each response 1-10 on: relevance, clarity, depth, creativity') 
    String judgeCriteria,

    // Scoreboard
    @Default(false) bool scoreboardEnabled,
    @Default(10) int pointsPerRoundWin,
    @Default(5) int pointsPerRoundDraw,

    // Voting
    @Default(false) bool votingEnabled,
    @Default(VotingTiming.perRound) VotingTiming votingTiming,
    @Default(0.5) double audienceVoteWeight, // 0.0 = judge only, 1.0 = audience only

    // Spectators
    @Default(true) bool spectatorsAllowed,
    @Default(false) bool audienceControlsEnabled,  // power-ups, injections
    @Default(false) bool crowdChantsEnabled,

    // Apocalypse mode
    @Default(false) bool apocalypseMode,
    @Default('Escalate the adversarial pressure each round') String apocalypsePrompt,

    // Agentic
    @Default(1) int agentsPerSide,
    @Default([]) List<AgentTool> allowedTools,

    // Multiplayer
    @Default(false) bool multiplayerEnabled,
    @Default(MatchVisibility.private) MatchVisibility matchVisibility,
    @Default(false) bool rankedMatch,
  }) = _BattleSettings;

  factory BattleSettings.fromJson(Map<String, dynamic> json) =>
      _$BattleSettingsFromJson(json);
}

enum VotingTiming { perRound, endOfMatch }
enum MatchVisibility { public, private, inviteOnly }

// ─── Debug Settings ──────────────────────────────────────────────────────────

@freezed
class DebugSettings with _$DebugSettings {
  const factory DebugSettings({
    @Default(false) bool verboseLogging,
    @Default(false) bool showRawPayloads,
    @Default(false) bool showTokenCounts,
    @Default(false) bool showLatencyMetrics,
    @Default(false) bool wsEventInspector,
    @Default(false) bool showLiteLLMStatus,
    @Default(false) bool forceErrorStates,
    @Default(false) bool stepThroughMode, // pause after each round
  }) = _DebugSettings;

  factory DebugSettings.fromJson(Map<String, dynamic> json) =>
      _$DebugSettingsFromJson(json);
}

// ─── Internal Settings ───────────────────────────────────────────────────────

@freezed
class InternalSettings with _$InternalSettings {
  const factory InternalSettings({
    @Default('http://localhost:4000') String liteLLMUrl,
    @Default(4000) int liteLLMPort,
    @Default(true) bool autoStartLiteLLM,
    @Default('') String liteLLMConfigYaml,   // raw editable config
    @Default('ws://localhost:8080') String relayUrl,
    @Default('') String relayAuthToken,
    @Default(false) bool allowMidMatchModelSwap,
    @Default(false) bool allowStateOverride,
    @Default(false) bool allowScoreOverride,
    @Default(false) bool allowPromptInjection,
  }) = _InternalSettings;

  factory InternalSettings.fromJson(Map<String, dynamic> json) =>
      _$InternalSettingsFromJson(json);
}

// ─── App Settings (root) ─────────────────────────────────────────────────────

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(BattleSettings()) BattleSettings battle,
    @Default(DebugSettings()) DebugSettings debug,
    @Default(InternalSettings()) InternalSettings internal,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

// ─── Battle State ─────────────────────────────────────────────────────────────

@freezed
class BattleRound with _$BattleRound {
  const factory BattleRound({
    required int roundNumber,
    required String prompt,
    @Default('') String responseA,
    @Default('') String responseB,
    @Default(BattleRoundStatus.pending) BattleRoundStatus status,
    double? scoreA,
    double? scoreB,
    String? judgeVerdict,
    @Default({}) Map<String, int> votes, // 'a' | 'b' | 'draw' -> count
    @Default(0) int tokensA,
    @Default(0) int tokensB,
    @Default(0) int latencyMsA,
    @Default(0) int latencyMsB,
    String? rawPayloadA,
    String? rawPayloadB,
  }) = _BattleRound;

  factory BattleRound.fromJson(Map<String, dynamic> json) =>
      _$BattleRoundFromJson(json);
}

enum BattleRoundStatus { pending, inProgress, judging, voting, complete }

@freezed
class BattleState with _$BattleState {
  const factory BattleState({
    required String id,
    required BattleSettings settings,
    required FighterConfig fighterA,
    required FighterConfig fighterB,
    @Default([]) List<BattleRound> rounds,
    @Default(BattleStatus.lobby) BattleStatus status,
    @Default(0) int currentRound,
    @Default(0.0) double totalScoreA,
    @Default(0.0) double totalScoreB,
    String? winnerId,
    @Default([]) List<LobbyMember> members,
  }) = _BattleState;

  factory BattleState.empty() => BattleState(
        id: _uuid.v4(),
        settings: const BattleSettings(),
        fighterA: FighterConfig.create(
          name: 'Fighter A',
          modelId: '',
          side: FighterSide.a,
        ),
        fighterB: FighterConfig.create(
          name: 'Fighter B',
          modelId: '',
          side: FighterSide.b,
        ),
      );

  factory BattleState.fromJson(Map<String, dynamic> json) =>
      _$BattleStateFromJson(json);
}

enum BattleStatus { lobby, countdown, inProgress, paused, judging, voting, complete }

// ─── Lobby / Multiplayer ──────────────────────────────────────────────────────

enum LobbyRole { owner, moderator, commander, spectator, audience }

@freezed
class LobbyMember with _$LobbyMember {
  const factory LobbyMember({
    required String id,
    required String displayName,
    required LobbyRole role,
    @Default(false) bool isConnected,
    FighterSide? commandingSide, // for commander role
  }) = _LobbyMember;

  factory LobbyMember.fromJson(Map<String, dynamic> json) =>
      _$LobbyMemberFromJson(json);
}

// ─── Model Provider ──────────────────────────────────────────────────────────

@freezed
class ModelProvider with _$ModelProvider {
  const factory ModelProvider({
    required String id,
    required String name,
    required String baseUrl,
    String? apiKey,
    @Default([]) List<String> availableModels,
    @Default(true) bool isEnabled,
  }) = _ModelProvider;

  factory ModelProvider.fromJson(Map<String, dynamic> json) =>
      _$ModelProviderFromJson(json);
}

// ─── Tournament ───────────────────────────────────────────────────────────────

@freezed
class TournamentEntry with _$TournamentEntry {
  const factory TournamentEntry({
    required String id,
    required String modelId,
    required String modelName,
    @Default(1000) int eloRating,
    @Default(0) int wins,
    @Default(0) int losses,
    @Default(0) int draws,
  }) = _TournamentEntry;

  factory TournamentEntry.fromJson(Map<String, dynamic> json) =>
      _$TournamentEntryFromJson(json);
}

@freezed
class TournamentState with _$TournamentState {
  const factory TournamentState({
    @Default([]) List<TournamentEntry> entries,
    @Default([]) List<TournamentMatch> completedMatches,
  }) = _TournamentState;

  factory TournamentState.fromJson(Map<String, dynamic> json) =>
      _$TournamentStateFromJson(json);
}

@freezed
class TournamentMatch with _$TournamentMatch {
  const factory TournamentMatch({
    required String id,
    required String entryAId,
    required String entryBId,
    String? winnerId,
    @Default(false) bool isDraw,
    required DateTime playedAt,
  }) = _TournamentMatch;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      _$TournamentMatchFromJson(json);
}
