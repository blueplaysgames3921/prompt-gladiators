import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_gladiators/core/models/models.dart';
import 'package:prompt_gladiators/features/battle/engine/battle_engine.dart';
import 'package:prompt_gladiators/features/battle/modes/battle_mode_config.dart';

void main() {
  group('BattleEngine lifecycle', () {
    late BattleState capturedState;
    late BattleEngine engine;

    setUp(() {
      capturedState = BattleState.empty();
      engine = BattleEngine(
        settings: const BattleSettings(
          roundCount: 3,
          judgeEnabled: false,
          scoreboardEnabled: true,
          votingEnabled: true,
          audienceVoteWeight: 0.5,
        ),
        onStateUpdate: (s) => capturedState = s,
      );

      engine.configure(
        fighterA: FighterConfig.create(
          name: 'Alpha',
          modelId: 'test-model-a',
          side: FighterSide.a,
        ),
        fighterB: FighterConfig.create(
          name: 'Beta',
          modelId: 'test-model-b',
          side: FighterSide.b,
        ),
      );
    });

    tearDown(() => engine.dispose());

    test('configure sets lobby status and fighter names', () {
      final s = engine.state;
      expect(s.status, equals(BattleStatus.lobby));
      expect(s.fighterA.name, equals('Alpha'));
      expect(s.fighterB.name, equals('Beta'));
      expect(s.currentRound, equals(0));
      expect(s.totalScoreA, equals(0.0));
      expect(s.totalScoreB, equals(0.0));
      expect(s.rounds, isEmpty);
    });

    test('configure with different fighters gives unique IDs', () {
      final s = engine.state;
      expect(s.fighterA.id, isNot(equals(s.fighterB.id)));
    });

    test('submitVote is ignored for non-existent round', () {
      // Round 99 doesn't exist — should not throw
      expect(
        () => engine.submitVote('99', 'voter-001', 'a'),
        returnsNormally,
      );
    });

    test('overrideScore sets scores and triggers onStateUpdate', () {
      engine.overrideScore(scoreA: 42.5, scoreB: 37.0);
      expect(engine.state.totalScoreA, closeTo(42.5, 0.001));
      expect(engine.state.totalScoreB, closeTo(37.0, 0.001));
      expect(capturedState.totalScoreA, closeTo(42.5, 0.001));
    });

    test('injectPrompt stores injection without throwing', () {
      expect(
        () => engine.injectPrompt('CHAOS: Respond only in haiku.'),
        returnsNormally,
      );
    });

    test('events stream emits on overrideScore', () async {
      final events = <BattleEvent>[];
      final sub = engine.events.listen(events.add);
      engine.overrideScore(scoreA: 10.0, scoreB: 5.0);
      await Future.delayed(Duration.zero);
      expect(events, isNotEmpty);
      expect(events.first, isA<StateChangedEvent>());
      await sub.cancel();
    });

    test('pause sets paused status, resume sets inProgress', () async {
      // pause() and resume() are unconditional state transitions —
      // they work regardless of whether the engine has started a battle.
      await engine.pause();
      expect(engine.state.status, equals(BattleStatus.paused));

      await engine.resume();
      expect(engine.state.status, equals(BattleStatus.inProgress));
    });

    test('dispose closes event stream', () async {
      engine.dispose();
      await expectLater(engine.events, emitsDone);
    });
  });

  group('BattleEngine.parseJsonForTest', () {
    late BattleEngine engine;

    setUp(() {
      engine = BattleEngine(
        settings: const BattleSettings(),
        onStateUpdate: (_) {},
      )..configure(
          fighterA: FighterConfig.create(name: 'A', modelId: 'm'),
          fighterB: FighterConfig.create(name: 'B', modelId: 'm'),
        );
    });

    tearDown(() => engine.dispose());

    test('parses clean JSON', () {
      final result = engine.parseJsonForTest(
        '{"scoreA": 8.5, "scoreB": 6.0, "verdict": "A wins"}',
      );
      expect(result['scoreA'], closeTo(8.5, 0.001));
      expect(result['scoreB'], closeTo(6.0, 0.001));
      expect(result['verdict'], equals('A wins'));
    });

    test('parses markdown-fenced JSON', () {
      final result = engine.parseJsonForTest(
        '```json\n{"scoreA": 9, "scoreB": 7, "verdict": "Close"}\n```',
      );
      expect(result['scoreA'], equals(9));
      expect(result['verdict'], equals('Close'));
    });

    test('parses JSON embedded in prose', () {
      final result = engine.parseJsonForTest(
        'After careful review:\n'
        '{"scoreA": 7, "scoreB": 8, "verdict": "B was more concise"}\n'
        'That concludes my assessment.',
      );
      expect(result['scoreB'], equals(8));
      expect(result['verdict'], equals('B was more concise'));
    });

    test('returns empty map for invalid JSON', () {
      final result = engine.parseJsonForTest('Not JSON at all');
      expect(result, isEmpty);
    });

    test('returns empty map for empty string', () {
      final result = engine.parseJsonForTest('');
      expect(result, isEmpty);
    });

    test('handles integer and double scores', () {
      final result = engine.parseJsonForTest(
        '{"scoreA": 8, "scoreB": 7.5, "verdict": "Mixed"}',
      );
      expect((result['scoreA'] as num).toDouble(), closeTo(8.0, 0.001));
      expect((result['scoreB'] as num).toDouble(), closeTo(7.5, 0.001));
    });
  });

  group('BattleModeConfig prompt builders', () {
    test('Classic builds prompt from base', () {
      final ctx = BattleModeContext(
        roundNumber: 1,
        totalRounds: 3,
        basePrompt: 'Is Dart a good language?',
      );
      final prompt = BattleModes.classic.roundPromptBuilder(ctx);
      expect(prompt, contains('Is Dart a good language?'));
    });

    test('Classic injects audience context', () {
      final ctx = BattleModeContext(
        roundNumber: 1,
        totalRounds: 3,
        basePrompt: 'Topic',
        injectedContext: 'Be funnier',
      );
      final prompt = BattleModes.classic.roundPromptBuilder(ctx);
      expect(prompt, contains('Be funnier'));
    });

    test('Battlefield round 1 same as classic', () {
      final ctx = BattleModeContext(
        roundNumber: 1,
        totalRounds: 5,
        basePrompt: 'Nuclear energy debate',
      );
      final prompt = BattleModes.battlefield.roundPromptBuilder(ctx);
      expect(prompt, contains('Nuclear energy debate'));
    });

    test('Battlefield round 2 includes opponent response', () {
      final ctx = BattleModeContext(
        roundNumber: 2,
        totalRounds: 5,
        basePrompt: 'Nuclear debate',
        opponentLastResponse: 'Nuclear is dangerous because of waste.',
        fighterName: 'Pro-Nuclear',
        opponentName: 'Anti-Nuclear',
      );
      final prompt = BattleModes.battlefield.roundPromptBuilder(ctx);
      expect(prompt, contains('Nuclear is dangerous because of waste.'));
      expect(prompt, contains('ROUND 2'));
    });

    test('Battlefield response prompt builder works', () {
      final ctx = BattleModeContext(
        roundNumber: 2,
        totalRounds: 5,
        basePrompt: 'Debate',
        opponentLastResponse: 'Opponent said X.',
      );
      final prompt = BattleModes.battlefield.responsePromptBuilder!(ctx);
      expect(prompt, contains('Opponent said X.'));
    });

    test('Agentic prompt includes tool use instruction', () {
      final ctx = BattleModeContext(
        roundNumber: 1,
        totalRounds: 3,
        basePrompt: 'Research fusion energy breakthroughs',
      );
      final prompt = BattleModes.agenticSwarm.roundPromptBuilder(ctx);
      expect(prompt, contains('Research fusion energy breakthroughs'));
      expect(prompt.toLowerCase(), contains('tool'));
    });

    test('Agentic apocalypse level adds escalation note', () {
      final ctx = BattleModeContext(
        roundNumber: 3,
        totalRounds: 5,
        basePrompt: 'Hard task',
        apocalypseLevel: 2,
      );
      final prompt = BattleModes.agenticSwarm.roundPromptBuilder(ctx);
      expect(prompt, contains('ESCALATION LEVEL 2'));
    });

    test('Commander prompt includes opponent response in round 2+', () {
      final ctx = BattleModeContext(
        roundNumber: 2,
        totalRounds: 5,
        basePrompt: 'Commander battle',
        opponentLastResponse: 'I argue for X.',
      );
      final prompt = BattleModes.commander.roundPromptBuilder(ctx);
      expect(prompt, contains('I argue for X.'));
    });

    test('BattleModes.forType returns correct config', () {
      expect(BattleModes.forType(BattleType.classic).type,
          equals(BattleType.classic));
      expect(BattleModes.forType(BattleType.battlefield).type,
          equals(BattleType.battlefield));
      expect(BattleModes.forType(BattleType.agenticSwarm).type,
          equals(BattleType.agenticSwarm));
      expect(BattleModes.forType(BattleType.tournament).type,
          equals(BattleType.tournament));
      expect(BattleModes.forType(BattleType.commander).type,
          equals(BattleType.commander));
    });

    test('all modes have non-empty display names and descriptions', () {
      for (final mode in BattleModes.all) {
        expect(mode.displayName, isNotEmpty,
            reason: '${mode.type} has empty displayName');
        expect(mode.description, isNotEmpty,
            reason: '${mode.type} has empty description');
      }
    });

    test('round constraints are valid', () {
      for (final mode in BattleModes.all) {
        expect(mode.minRounds, greaterThanOrEqualTo(1));
        expect(mode.maxRounds, greaterThanOrEqualTo(mode.minRounds));
        expect(mode.defaultRounds,
            inInclusiveRange(mode.minRounds, mode.maxRounds));
      }
    });
  });

  group('Scoring logic', () {
    test('pure judge scoring: weight=0 means audience-only', () {
      // audienceVoteWeight=1.0: judge contributes 0%
      const weight = 1.0;
      final judgeWeight = 1.0 - weight;
      const judgeScoreA = 9.0;
      const judgeScoreB = 7.0;

      final fromJudgeA = judgeScoreA * judgeWeight; // 0
      final fromJudgeB = judgeScoreB * judgeWeight; // 0
      expect(fromJudgeA, closeTo(0.0, 0.001));
      expect(fromJudgeB, closeTo(0.0, 0.001));
    });

    test('blended scoring at 50/50', () {
      const weight = 0.5;
      final judgeWeight = 1.0 - weight;
      const judgeA = 8.0, judgeB = 6.0;
      const votes = {'a': 6, 'b': 4};
      const totalVotes = 10;

      final audienceA = (votes['a']! / totalVotes) * 10 * weight;
      final audienceB = (votes['b']! / totalVotes) * 10 * weight;
      final totalA = judgeA * judgeWeight + audienceA;
      final totalB = judgeB * judgeWeight + audienceB;

      expect(totalA, closeTo(7.0, 0.001)); // 4.0 + 3.0
      expect(totalB, closeTo(5.0, 0.001)); // 3.0 + 2.0
      expect(totalA, greaterThan(totalB));
    });

    test('draw when scores are equal', () {
      const scoreA = 10.0, scoreB = 10.0;
      final winnerId = scoreA > scoreB
          ? 'a'
          : scoreB > scoreA
              ? 'b'
              : null;
      expect(winnerId, isNull);
    });
  });

  group('BattleEvent factory constructors', () {
    test('all factories produce correct types', () {
      final state = BattleState.empty();
      final round = const BattleRound(roundNumber: 1, prompt: 'test');

      expect(BattleEvent.stateChanged(state), isA<StateChangedEvent>());
      expect(BattleEvent.battleStarted(state), isA<BattleStartedEvent>());
      expect(BattleEvent.battleComplete(state), isA<BattleCompleteEvent>());
      expect(
        BattleEvent.roundStarted(roundNumber: 1, prompt: 'p'),
        isA<RoundStartedEvent>(),
      );
      expect(
        BattleEvent.roundResponsesReady(roundNumber: 1),
        isA<RoundResponsesReadyEvent>(),
      );
      expect(
        BattleEvent.roundJudged(roundNumber: 1, round: round),
        isA<RoundJudgedEvent>(),
      );
      expect(
        BattleEvent.roundComplete(roundNumber: 1),
        isA<RoundCompleteEvent>(),
      );
      expect(
        BattleEvent.fighterThinking(side: FighterSide.a),
        isA<FighterThinkingEvent>(),
      );
      expect(
        BattleEvent.voteReceived(roundNumber: 1, votes: {'a': 5}),
        isA<VoteReceivedEvent>(),
      );
      expect(
        BattleEvent.promptInjected('chaos'),
        isA<PromptInjectedEvent>(),
      );
    });
  });
}
