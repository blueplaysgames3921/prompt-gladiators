import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_gladiators/core/models/models.dart';

void main() {
  group('FighterConfig', () {
    test('create() generates unique IDs', () {
      final a = FighterConfig.create(name: 'Alpha', modelId: 'gpt-4o');
      final b = FighterConfig.create(name: 'Beta', modelId: 'gpt-4o');
      expect(a.id, isNotEmpty);
      expect(b.id, isNotEmpty);
      expect(a.id, isNot(equals(b.id)));
    });

    test('create() sets correct defaults', () {
      final f = FighterConfig.create(name: 'Test', modelId: 'claude-3-5');
      expect(f.side, equals(FighterSide.a));
      expect(f.agentCount, equals(1));
      expect(f.allowedTools, isEmpty);
      expect(f.systemPrompt, isEmpty);
      expect(f.endpointUrl, equals('http://localhost:4000'));
    });

    test('serialises and deserialises correctly', () {
      final original = FighterConfig.create(
        name: 'Fighter',
        modelId: 'gpt-4o',
        systemPrompt: 'You are aggressive.',
        side: FighterSide.b,
        agentCount: 3,
        allowedTools: [AgentTool.webSearch, AgentTool.codeExecution],
      );
      final json = original.toJson();
      final restored = FighterConfig.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.modelId, equals(original.modelId));
      expect(restored.systemPrompt, equals(original.systemPrompt));
      expect(restored.side, equals(FighterSide.b));
      expect(restored.agentCount, equals(3));
      expect(restored.allowedTools,
          containsAll([AgentTool.webSearch, AgentTool.codeExecution]));
    });
  });

  group('BattleSettings', () {
    test('default values are sensible', () {
      const s = BattleSettings();
      expect(s.battleType, equals(BattleType.classic));
      expect(s.roundCount, equals(3));
      expect(s.judgeEnabled, isFalse);
      expect(s.votingEnabled, isFalse);
      expect(s.apocalypseMode, isFalse);
      expect(s.agentsPerSide, equals(1));
      expect(s.audienceVoteWeight, equals(0.5));
    });

    test('copyWith only changes specified fields', () {
      const original = BattleSettings();
      final updated = original.copyWith(
        roundCount: 10,
        judgeEnabled: true,
        battleType: BattleType.battlefield,
      );
      expect(updated.roundCount, equals(10));
      expect(updated.judgeEnabled, isTrue);
      expect(updated.battleType, equals(BattleType.battlefield));
      // Unchanged fields
      expect(updated.votingEnabled, isFalse);
      expect(updated.apocalypseMode, isFalse);
    });

    test('serialises and deserialises correctly', () {
      const original = BattleSettings(
        roundCount: 7,
        judgeEnabled: true,
        judgeModelId: 'gpt-4o',
        votingEnabled: true,
        votingTiming: VotingTiming.endOfMatch,
        audienceVoteWeight: 0.3,
        apocalypseMode: true,
        agentsPerSide: 4,
        allowedTools: [AgentTool.webSearch],
      );
      final json = original.toJson();
      final restored = BattleSettings.fromJson(json);

      expect(restored.roundCount, equals(7));
      expect(restored.judgeEnabled, isTrue);
      expect(restored.judgeModelId, equals('gpt-4o'));
      expect(restored.votingEnabled, isTrue);
      expect(restored.votingTiming, equals(VotingTiming.endOfMatch));
      expect(restored.audienceVoteWeight, closeTo(0.3, 0.001));
      expect(restored.apocalypseMode, isTrue);
      expect(restored.agentsPerSide, equals(4));
      expect(restored.allowedTools, contains(AgentTool.webSearch));
    });
  });

  group('BattleState', () {
    test('empty() creates valid initial state', () {
      final state = BattleState.empty();
      expect(state.id, isNotEmpty);
      expect(state.status, equals(BattleStatus.lobby));
      expect(state.currentRound, equals(0));
      expect(state.totalScoreA, equals(0.0));
      expect(state.totalScoreB, equals(0.0));
      expect(state.rounds, isEmpty);
      expect(state.winnerId, isNull);
      expect(state.fighterA.id, isNot(equals(state.fighterB.id)));
    });

    test('two empty() calls produce different IDs', () {
      final a = BattleState.empty();
      final b = BattleState.empty();
      expect(a.id, isNot(equals(b.id)));
    });

    test('serialises and deserialises correctly', () {
      final original = BattleState.empty().copyWith(
        status: BattleStatus.inProgress,
        currentRound: 2,
        totalScoreA: 14.5,
        totalScoreB: 12.0,
        rounds: [
          const BattleRound(
            roundNumber: 1,
            prompt: 'Argue that cats are better than dogs.',
            responseA: 'Cats are clearly superior...',
            responseB: 'Dogs are loyal companions...',
            status: BattleRoundStatus.complete,
            scoreA: 8.0,
            scoreB: 6.5,
            judgeVerdict: 'Fighter A made more compelling points.',
            tokensA: 142,
            tokensB: 138,
            latencyMsA: 1200,
            latencyMsB: 1350,
          ),
        ],
      );

      final json = original.toJson();
      final restored = BattleState.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.status, equals(BattleStatus.inProgress));
      expect(restored.currentRound, equals(2));
      expect(restored.totalScoreA, closeTo(14.5, 0.001));
      expect(restored.totalScoreB, closeTo(12.0, 0.001));
      expect(restored.rounds.length, equals(1));
      expect(restored.rounds.first.prompt,
          equals('Argue that cats are better than dogs.'));
      expect(restored.rounds.first.scoreA, closeTo(8.0, 0.001));
      expect(restored.rounds.first.judgeVerdict,
          equals('Fighter A made more compelling points.'));
    });
  });

  group('BattleRound', () {
    test('vote tracking works correctly', () {
      const round = BattleRound(
        roundNumber: 1,
        prompt: 'Test prompt',
        votes: {'a': 12, 'b': 8, 'draw': 3},
      );
      expect(round.votes['a'], equals(12));
      expect(round.votes['b'], equals(8));
      expect(round.votes['draw'], equals(3));

      final updated = round.copyWith(
        votes: {...round.votes, 'a': 13},
      );
      expect(updated.votes['a'], equals(13));
      expect(updated.votes['b'], equals(8)); // unchanged
    });
  });

  group('AppSettings', () {
    test('nested serialisation round-trips correctly', () {
      const original = AppSettings(
        battle: BattleSettings(roundCount: 5, judgeEnabled: true),
        debug: DebugSettings(verboseLogging: true, showRawPayloads: true),
        internal: InternalSettings(
          liteLLMPort: 5000,
          relayUrl: 'ws://192.168.1.100:8080',
        ),
      );

      final json = jsonEncode(original.toJson());
      final restored =
          AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(restored.battle.roundCount, equals(5));
      expect(restored.battle.judgeEnabled, isTrue);
      expect(restored.debug.verboseLogging, isTrue);
      expect(restored.debug.showRawPayloads, isTrue);
      expect(restored.internal.liteLLMPort, equals(5000));
      expect(restored.internal.relayUrl, equals('ws://192.168.1.100:8080'));
    });
  });

  group('InternalSettings', () {
    test('defaults use localhost', () {
      const s = InternalSettings();
      expect(s.liteLLMUrl, equals('http://localhost:4000'));
      expect(s.liteLLMPort, equals(4000));
      expect(s.relayUrl, equals('ws://localhost:8080'));
      expect(s.autoStartLiteLLM, isTrue);
      expect(s.allowStateOverride, isFalse);
      expect(s.allowScoreOverride, isFalse);
    });
  });

  group('TournamentEntry', () {
    test('starts with 1000 ELO', () {
      const entry = TournamentEntry(
        id: 'test-1',
        modelId: 'gpt-4o',
        modelName: 'GPT-4o',
      );
      expect(entry.eloRating, equals(1000));
      expect(entry.wins, equals(0));
      expect(entry.losses, equals(0));
      expect(entry.draws, equals(0));
    });

    test('serialises correctly', () {
      const entry = TournamentEntry(
        id: 'entry-abc',
        modelId: 'gemini-2.0-flash',
        modelName: 'Gemini Flash',
        eloRating: 1150,
        wins: 5,
        losses: 2,
        draws: 1,
      );
      final restored = TournamentEntry.fromJson(entry.toJson());
      expect(restored.eloRating, equals(1150));
      expect(restored.wins, equals(5));
      expect(restored.losses, equals(2));
      expect(restored.draws, equals(1));
    });
  });
}
