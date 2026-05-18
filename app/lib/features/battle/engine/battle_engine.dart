import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../core/models/models.dart';
import '../../core/services/litellm_service.dart';
import '../modes/battle_mode_config.dart';

final _log = Logger();

/// Core battle engine. Drives rounds, streaming, judging, scoring.
/// Platform-agnostic — works locally or synced via relay.
class BattleEngine {
  BattleEngine({required this.settings, required this.onStateUpdate});

  final BattleSettings settings;
  final void Function(BattleState state) onStateUpdate;

  BattleState _state = BattleState.empty();
  final _eventController = StreamController<BattleEvent>.broadcast();

  Stream<BattleEvent> get events => _eventController.stream;
  BattleState get state => _state;

  // ─── Setup ────────────────────────────────────────────────────────────────

  void configure({
    required FighterConfig fighterA,
    required FighterConfig fighterB,
  }) {
    _state = _state.copyWith(
      settings: settings,
      fighterA: fighterA,
      fighterB: fighterB,
      status: BattleStatus.lobby,
    );
    _emit(BattleEvent.stateChanged(_state));
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> start(String initialPrompt) async {
    _state = _state.copyWith(status: BattleStatus.countdown);
    _emit(BattleEvent.stateChanged(_state));

    await Future.delayed(const Duration(seconds: 3)); // countdown

    _state = _state.copyWith(status: BattleStatus.inProgress, currentRound: 0);
    _emit(BattleEvent.battleStarted(_state));

    await _runAllRounds(initialPrompt);
  }

  Future<void> pause() async {
    _state = _state.copyWith(status: BattleStatus.paused);
    _emit(BattleEvent.stateChanged(_state));
  }

  Future<void> resume() async {
    _state = _state.copyWith(status: BattleStatus.inProgress);
    _emit(BattleEvent.stateChanged(_state));
  }

  void submitVote(String roundId, String voterId, String choice) {
    final rounds = [..._state.rounds];
    final idx = rounds.indexWhere((r) => r.roundNumber.toString() == roundId);
    if (idx == -1) return;

    final round = rounds[idx];
    final votes = {...round.votes};
    votes[choice] = (votes[choice] ?? 0) + 1;
    rounds[idx] = round.copyWith(votes: votes);

    _state = _state.copyWith(rounds: rounds);
    _emit(BattleEvent.voteReceived(roundNumber: idx, votes: votes));
    onStateUpdate(_state);
  }

  /// Override score mid-match (internal settings)
  void overrideScore({required double scoreA, required double scoreB}) {
    _state = _state.copyWith(totalScoreA: scoreA, totalScoreB: scoreB);
    _emit(BattleEvent.stateChanged(_state));
    onStateUpdate(_state);
  }

  /// Inject a message into the next round prompt (audience control)
  String? _injectedPrompt;
  void injectPrompt(String injection) {
    _injectedPrompt = injection;
    _emit(BattleEvent.promptInjected(injection));
  }

  // ─── Round Runner ─────────────────────────────────────────────────────────

  Future<void> _runAllRounds(String initialPrompt) async {
    final modeConfig = BattleModes.forType(settings.battleType);
    final conversationA = <Map<String, String>>[];
    final conversationB = <Map<String, String>>[];

    // Seed system prompts
    if (_state.fighterA.systemPrompt.isNotEmpty) {
      conversationA.add({'role': 'system', 'content': _state.fighterA.systemPrompt});
    }
    if (_state.fighterB.systemPrompt.isNotEmpty) {
      conversationB.add({'role': 'system', 'content': _state.fighterB.systemPrompt});
    }

    String? lastResponseA;
    String? lastResponseB;

    for (int i = 0; i < settings.roundCount; i++) {
      // Respect pause
      while (_state.status == BattleStatus.paused) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Build context for this round
      final ctx = BattleModeContext(
        roundNumber: i + 1,
        totalRounds: settings.roundCount,
        basePrompt: initialPrompt,
        opponentLastResponse: null, // set per-fighter below
        fighterName: _state.fighterA.name,
        opponentName: _state.fighterB.name,
        apocalypseLevel: settings.apocalypseMode ? i : 0,
        injectedContext: _injectedPrompt,
      );
      _injectedPrompt = null;

      // Build prompt for fighter A (sees B's last response as opponent)
      final ctxA = BattleModeContext(
        roundNumber: ctx.roundNumber,
        totalRounds: ctx.totalRounds,
        basePrompt: initialPrompt,
        opponentLastResponse: lastResponseB,
        ownLastResponse: lastResponseA,
        fighterName: _state.fighterA.name,
        opponentName: _state.fighterB.name,
        apocalypseLevel: ctx.apocalypseLevel,
        injectedContext: ctx.injectedContext,
      );

      // Build prompt for fighter B (sees A's last response as opponent)
      final ctxB = BattleModeContext(
        roundNumber: ctx.roundNumber,
        totalRounds: ctx.totalRounds,
        basePrompt: initialPrompt,
        opponentLastResponse: lastResponseA,
        ownLastResponse: lastResponseB,
        fighterName: _state.fighterB.name,
        opponentName: _state.fighterA.name,
        apocalypseLevel: ctx.apocalypseLevel,
        injectedContext: null, // only inject once (already used in ctxA)
      );

      final promptA = modeConfig.roundPromptBuilder(ctxA);
      final promptB = (i == 0 || modeConfig.responsePromptBuilder == null)
          ? modeConfig.roundPromptBuilder(ctxB)
          : modeConfig.responsePromptBuilder!(ctxB);

      final roundPromptDisplay = i == 0
          ? initialPrompt
          : 'Round ${i + 1}: $initialPrompt';

      final round = BattleRound(
        roundNumber: i + 1,
        prompt: roundPromptDisplay,
        status: BattleRoundStatus.inProgress,
      );

      final rounds = [..._state.rounds, round];
      _state = _state.copyWith(rounds: rounds, currentRound: i + 1);
      _emit(BattleEvent.roundStarted(roundNumber: i + 1, prompt: roundPromptDisplay));
      onStateUpdate(_state);

      // Send to both fighters in parallel
      conversationA.add({'role': 'user', 'content': promptA});
      conversationB.add({'role': 'user', 'content': promptB});

      final results = await Future.wait([
        _runFighter(_state.fighterA, conversationA),
        _runFighter(_state.fighterB, conversationB),
      ]);

      final resultA = results[0];
      final resultB = results[1];

      lastResponseA = resultA.content;
      lastResponseB = resultB.content;

      // Add to conversation history so next round has context
      conversationA.add({'role': 'assistant', 'content': resultA.content});
      conversationB.add({'role': 'assistant', 'content': resultB.content});

      // Update round with responses
      var updatedRound = round.copyWith(
        responseA: resultA.content,
        responseB: resultB.content,
        tokensA: resultA.outputTokens,
        tokensB: resultB.outputTokens,
        latencyMsA: resultA.latencyMs,
        latencyMsB: resultB.latencyMs,
        rawPayloadA: resultA.rawResponse.toString(),
        rawPayloadB: resultB.rawResponse.toString(),
        status: BattleRoundStatus.judging,
      );

      final updatedRounds = [..._state.rounds];
      updatedRounds[i] = updatedRound;
      _state = _state.copyWith(rounds: updatedRounds);
      _emit(BattleEvent.roundResponsesReady(roundNumber: i + 1));
      onStateUpdate(_state);

      // Judge
      if (settings.judgeEnabled && settings.judgeModelId != null) {
        updatedRound = await _judgeRound(updatedRound);
        updatedRounds[i] = updatedRound;
        _state = _state.copyWith(rounds: updatedRounds);
        _emit(BattleEvent.roundJudged(roundNumber: i + 1, round: updatedRound));
        onStateUpdate(_state);
      }

      // Voting window
      if (settings.votingEnabled &&
          settings.votingTiming == VotingTiming.perRound) {
        updatedRound = updatedRound.copyWith(status: BattleRoundStatus.voting);
        updatedRounds[i] = updatedRound;
        _state = _state.copyWith(
            rounds: updatedRounds, status: BattleStatus.voting);
        onStateUpdate(_state);
        await Future.delayed(const Duration(seconds: 30));
        _state = _state.copyWith(status: BattleStatus.inProgress);
      }

      // Score round
      if (settings.scoreboardEnabled) {
        _scoreRound(updatedRound, i);
      }

      updatedRounds[i] = updatedRound.copyWith(status: BattleRoundStatus.complete);
      _state = _state.copyWith(rounds: updatedRounds);
      _emit(BattleEvent.roundComplete(roundNumber: i + 1));
      onStateUpdate(_state);
    }

    await _finalizeBattle();
  }

  Future<CompletionResult> _runFighter(
    FighterConfig fighter,
    List<Map<String, String>> messages,
  ) async {
    _emit(BattleEvent.fighterThinking(side: fighter.side));
    try {
      return await LiteLLMService.instance.complete(
        model: fighter.modelId,
        messages: messages,
        maxTokens: settings.tokenLimitPerTurn > 0 ? settings.tokenLimitPerTurn : 2000,
      );
    } catch (e) {
      _log.e('Fighter ${fighter.side} failed: $e');
      return CompletionResult(
        content: '[ERROR: ${e.toString()}]',
        inputTokens: 0,
        outputTokens: 0,
        latencyMs: 0,
        rawResponse: {'error': e.toString()},
      );
    }
  }

  Future<BattleRound> _judgeRound(BattleRound round) async {
    try {
      final judgePrompt = '''
${settings.judgeCriteria}

--- FIGHTER A ---
${round.responseA}

--- FIGHTER B ---
${round.responseB}

Respond ONLY with JSON:
{"scoreA": <0-10>, "scoreB": <0-10>, "verdict": "<brief explanation>"}
''';

      final result = await LiteLLMService.instance.complete(
        model: settings.judgeModelId!,
        messages: [
          {'role': 'system', 'content': 'You are an impartial judge. Always respond with valid JSON only.'},
          {'role': 'user', 'content': judgePrompt},
        ],
        maxTokens: 500,
        temperature: 0.3,
      );

      // Parse judge response
      final json = _parseJson(result.content);
      return round.copyWith(
        scoreA: (json['scoreA'] as num?)?.toDouble(),
        scoreB: (json['scoreB'] as num?)?.toDouble(),
        judgeVerdict: json['verdict'] as String?,
      );
    } catch (e) {
      _log.e('Judge failed: $e');
      return round;
    }
  }

  void _scoreRound(BattleRound round, int index) {
    double addA = 0, addB = 0;

    if (settings.judgeEnabled && round.scoreA != null && round.scoreB != null) {
      final judgeWeight = 1.0 - settings.audienceVoteWeight;
      addA += round.scoreA! * judgeWeight;
      addB += round.scoreB! * judgeWeight;
    }

    if (settings.votingEnabled) {
      final totalVotes = (round.votes['a'] ?? 0) +
          (round.votes['b'] ?? 0) +
          (round.votes['draw'] ?? 0);
      if (totalVotes > 0) {
        final audienceA = (round.votes['a'] ?? 0) / totalVotes * 10;
        final audienceB = (round.votes['b'] ?? 0) / totalVotes * 10;
        addA += audienceA * settings.audienceVoteWeight;
        addB += audienceB * settings.audienceVoteWeight;
      }
    }

    _state = _state.copyWith(
      totalScoreA: _state.totalScoreA + addA,
      totalScoreB: _state.totalScoreB + addB,
    );
  }

  Future<void> _finalizeBattle() async {
    final winnerId = _state.totalScoreA > _state.totalScoreB
        ? _state.fighterA.id
        : _state.totalScoreB > _state.totalScoreA
            ? _state.fighterB.id
            : null; // draw

    _state = _state.copyWith(
      status: BattleStatus.complete,
      winnerId: winnerId,
    );
    _emit(BattleEvent.battleComplete(_state));
    onStateUpdate(_state);
  }

  // ─── Utils ────────────────────────────────────────────────────────────────

  void _emit(BattleEvent event) {
    _eventController.add(event);
    _log.d('BattleEvent: ${event.runtimeType}');
  }

  /// Exposed for unit testing only.
  @visibleForTesting
  Map<String, dynamic> parseJsonForTest(String raw) => _parseJson(raw);

  Map<String, dynamic> _parseJson(String raw) {
    try {
      // Strip markdown code fences if present
      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        final firstNewline = cleaned.indexOf('\n');
        final lastFence = cleaned.lastIndexOf('```');
        if (firstNewline != -1 && lastFence > firstNewline) {
          cleaned = cleaned.substring(firstNewline + 1, lastFence).trim();
        }
      }
      // Extract JSON object
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return {};
      final jsonStr = cleaned.substring(start, end + 1);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      _log.w('_parseJson failed: $e\nRaw: $raw');
      return {};
    }
  }

  void dispose() {
    _eventController.close();
  }
}

// ─── Battle Events ────────────────────────────────────────────────────────────

abstract class BattleEvent {
  const BattleEvent();

  factory BattleEvent.stateChanged(BattleState state) = StateChangedEvent;
  factory BattleEvent.battleStarted(BattleState state) = BattleStartedEvent;
  factory BattleEvent.battleComplete(BattleState state) = BattleCompleteEvent;
  factory BattleEvent.roundStarted({required int roundNumber, required String prompt}) = RoundStartedEvent;
  factory BattleEvent.roundResponsesReady({required int roundNumber}) = RoundResponsesReadyEvent;
  factory BattleEvent.roundJudged({required int roundNumber, required BattleRound round}) = RoundJudgedEvent;
  factory BattleEvent.roundComplete({required int roundNumber}) = RoundCompleteEvent;
  factory BattleEvent.fighterThinking({required FighterSide side}) = FighterThinkingEvent;
  factory BattleEvent.voteReceived({required int roundNumber, required Map<String, int> votes}) = VoteReceivedEvent;
  factory BattleEvent.promptInjected(String injection) = PromptInjectedEvent;
}

class StateChangedEvent extends BattleEvent {
  final BattleState state;
  const StateChangedEvent(this.state);
}

class BattleStartedEvent extends BattleEvent {
  final BattleState state;
  const BattleStartedEvent(this.state);
}

class BattleCompleteEvent extends BattleEvent {
  final BattleState state;
  const BattleCompleteEvent(this.state);
}

class RoundStartedEvent extends BattleEvent {
  final int roundNumber;
  final String prompt;
  const RoundStartedEvent({required this.roundNumber, required this.prompt});
}

class RoundResponsesReadyEvent extends BattleEvent {
  final int roundNumber;
  const RoundResponsesReadyEvent({required this.roundNumber});
}

class RoundJudgedEvent extends BattleEvent {
  final int roundNumber;
  final BattleRound round;
  const RoundJudgedEvent({required this.roundNumber, required this.round});
}

class RoundCompleteEvent extends BattleEvent {
  final int roundNumber;
  const RoundCompleteEvent({required this.roundNumber});
}

class FighterThinkingEvent extends BattleEvent {
  final FighterSide side;
  const FighterThinkingEvent({required this.side});
}

class VoteReceivedEvent extends BattleEvent {
  final int roundNumber;
  final Map<String, int> votes;
  const VoteReceivedEvent({required this.roundNumber, required this.votes});
}

class PromptInjectedEvent extends BattleEvent {
  final String injection;
  const PromptInjectedEvent(this.injection);
}
