import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_gladiators/shared/extensions/extensions.dart';
import 'package:prompt_gladiators/core/utils/utils.dart';
import 'package:prompt_gladiators/core/models/models.dart';

void main() {
  group('StringX extensions', () {
    test('truncate cuts long strings', () {
      expect('hello world'.truncate(5), equals('hello…'));
      expect('hi'.truncate(10), equals('hi'));
      expect('exact'.truncate(5), equals('exact'));
    });

    test('truncate uses custom ellipsis', () {
      expect('hello world'.truncate(5, ellipsis: '...'), equals('hello...'));
    });

    test('titleCase converts snake_case', () {
      expect('hello_world'.titleCase, equals('Hello World'));
      expect('battle_arena'.titleCase, equals('Battle Arena'));
      expect('single'.titleCase, equals('Single'));
    });

    test('isUuid recognises valid UUID v4', () {
      expect('550e8400-e29b-41d4-a716-446655440000'.isUuid, isFalse); // v1
      expect('f47ac10b-58cc-4372-a567-0e02b2c3d479'.isUuid, isTrue);  // v4
      expect('not-a-uuid'.isUuid, isFalse);
      expect(''.isUuid, isFalse);
    });

    test('isWsUrl validates WebSocket URLs', () {
      expect('ws://localhost:8080'.isWsUrl, isTrue);
      expect('wss://relay.example.com'.isWsUrl, isTrue);
      expect('http://localhost'.isWsUrl, isFalse);
      expect('not a url'.isWsUrl, isFalse);
    });

    test('normalised trims and collapses whitespace', () {
      expect('  hello   world  '.normalised, equals('hello world'));
      expect('\t\nhello\n\t'.normalised, equals('hello'));
    });
  });

  group('BattleStateX extensions', () {
    late BattleState emptyState;

    setUp(() {
      emptyState = BattleState.empty();
    });

    test('isActive reflects battle status', () {
      expect(emptyState.isActive, isFalse); // lobby
      expect(
        emptyState.copyWith(status: BattleStatus.inProgress).isActive,
        isTrue,
      );
      expect(
        emptyState.copyWith(status: BattleStatus.paused).isActive,
        isTrue,
      );
      expect(
        emptyState.copyWith(status: BattleStatus.complete).isActive,
        isFalse,
      );
    });

    test('isFinished and isDraw', () {
      final complete = emptyState.copyWith(status: BattleStatus.complete);
      expect(complete.isFinished, isTrue);
      expect(complete.isDraw, isTrue); // winnerId is null

      final withWinner = complete.copyWith(winnerId: 'fighter-a');
      expect(withWinner.isDraw, isFalse);
    });

    test('scoreRatioA returns 0.5 for equal scores', () {
      expect(emptyState.scoreRatioA, closeTo(0.5, 0.001));
    });

    test('scoreRatioA returns correct ratio', () {
      final state = emptyState.copyWith(
        totalScoreA: 60.0,
        totalScoreB: 40.0,
      );
      expect(state.scoreRatioA, closeTo(0.6, 0.001));
    });

    test('completedRoundCount counts correctly', () {
      final state = emptyState.copyWith(
        rounds: [
          const BattleRound(
              roundNumber: 1,
              prompt: 'p1',
              status: BattleRoundStatus.complete),
          const BattleRound(
              roundNumber: 2,
              prompt: 'p2',
              status: BattleRoundStatus.inProgress),
          const BattleRound(
              roundNumber: 3,
              prompt: 'p3',
              status: BattleRoundStatus.complete),
        ],
      );
      expect(state.completedRoundCount, equals(2));
    });
  });

  group('BattleSettingsX extensions', () {
    test('hasScoringActive detects active scoring', () {
      const none = BattleSettings();
      expect(none.hasScoringActive, isFalse);

      const withJudge = BattleSettings(judgeEnabled: true);
      expect(withJudge.hasScoringActive, isTrue);

      const withVoting = BattleSettings(votingEnabled: true);
      expect(withVoting.hasScoringActive, isTrue);
    });

    test('modifierSummary returns Standard for plain settings', () {
      const s = BattleSettings();
      expect(s.modifierSummary, equals('Standard'));
    });

    test('modifierSummary lists active modifiers', () {
      const s = BattleSettings(
        judgeEnabled: true,
        votingEnabled: true,
        apocalypseMode: true,
      );
      expect(s.modifierSummary, contains('Judge'));
      expect(s.modifierSummary, contains('Voting'));
      expect(s.modifierSummary, contains('Apocalypse'));
    });
  });

  group('FighterConfigX extensions', () {
    test('sideColor returns correct color', () {
      final a = FighterConfig.create(
          name: 'A', modelId: 'x', side: FighterSide.a);
      final b = FighterConfig.create(
          name: 'B', modelId: 'y', side: FighterSide.b);
      expect(a.sideColor, isNot(equals(b.sideColor)));
    });

    test('displayName falls back when name is empty', () {
      final f = FighterConfig.create(name: '', modelId: 'x', side: FighterSide.a);
      expect(f.displayName, equals('Fighter A'));

      final named = FighterConfig.create(
          name: 'Titan', modelId: 'x', side: FighterSide.a);
      expect(named.displayName, equals('Titan'));
    });

    test('sideLabel returns A or B', () {
      final a = FighterConfig.create(
          name: 'A', modelId: 'x', side: FighterSide.a);
      final b = FighterConfig.create(
          name: 'B', modelId: 'y', side: FighterSide.b);
      expect(a.sideLabel, equals('A'));
      expect(b.sideLabel, equals('B'));
    });
  });

  group('BattleRoundX extensions', () {
    test('hasResponses checks both responses', () {
      const empty = BattleRound(roundNumber: 1, prompt: 'p');
      expect(empty.hasResponses, isFalse);

      const partial = BattleRound(
          roundNumber: 1, prompt: 'p', responseA: 'Hello');
      expect(partial.hasResponses, isFalse);

      const full = BattleRound(
          roundNumber: 1,
          prompt: 'p',
          responseA: 'Hello',
          responseB: 'World');
      expect(full.hasResponses, isTrue);
    });

    test('totalVotes sums all vote types', () {
      const round = BattleRound(
        roundNumber: 1,
        prompt: 'p',
        votes: {'a': 10, 'b': 5, 'draw': 3},
      );
      expect(round.totalVotes, equals(18));
    });

    test('voteWinner returns correct winner', () {
      const aWins = BattleRound(
        roundNumber: 1,
        prompt: 'p',
        votes: {'a': 8, 'b': 2},
      );
      expect(aWins.voteWinner, equals('a'));

      const bWins = BattleRound(
        roundNumber: 1,
        prompt: 'p',
        votes: {'a': 1, 'b': 9},
      );
      expect(bWins.voteWinner, equals('b'));

      const tie = BattleRound(
        roundNumber: 1,
        prompt: 'p',
        votes: {'a': 5, 'b': 5},
      );
      expect(tie.voteWinner, equals('draw'));

      const noVotes = BattleRound(roundNumber: 1, prompt: 'p');
      expect(noVotes.voteWinner, isNull);
    });
  });

  group('ListX extensions', () {
    test('chunked splits correctly', () {
      final list = [1, 2, 3, 4, 5, 6, 7];
      final chunks = list.chunked(3).toList();
      expect(chunks.length, equals(3));
      expect(chunks[0], equals([1, 2, 3]));
      expect(chunks[1], equals([4, 5, 6]));
      expect(chunks[2], equals([7]));
    });

    test('chunked handles empty list', () {
      final chunks = <int>[].chunked(3).toList();
      expect(chunks, isEmpty);
    });

    test('getOrDefault returns default for out-of-range', () {
      final list = [10, 20, 30];
      expect(list.getOrDefault(0, 99), equals(10));
      expect(list.getOrDefault(5, 99), equals(99));
      expect(list.getOrDefault(-1, 99), equals(99));
    });
  });

  group('ModelIdUtil', () {
    test('displayName strips provider prefix', () {
      expect(ModelIdUtil.displayName('openai/gpt-4o'), equals('GPT-4o'));
      expect(ModelIdUtil.displayName('gemini/gemini-2.0-flash'),
          equals('Gemini 2.0 Flash'));
    });

    test('displayName handles bare model IDs', () {
      expect(ModelIdUtil.displayName('gpt-4o'), equals('GPT-4o'));
      expect(ModelIdUtil.displayName(''), equals('Unknown'));
    });

    test('provider extracts prefix', () {
      expect(ModelIdUtil.provider('openai/gpt-4o'), equals('openai'));
      expect(ModelIdUtil.provider('gpt-4o'), isNull);
    });
  });

  group('DurationFormat', () {
    test('seconds formats duration', () {
      expect(DurationFormat.seconds(0), equals('∞'));
      expect(DurationFormat.seconds(45), equals('45s'));
      expect(DurationFormat.seconds(90), equals('1m 30s'));
      expect(DurationFormat.seconds(120), equals('2m'));
      expect(DurationFormat.seconds(3661), equals('61m 1s'));
    });

    test('latencyMs formats latency', () {
      expect(DurationFormat.latencyMs(500), equals('500ms'));
      expect(DurationFormat.latencyMs(1500), equals('1.5s'));
      expect(DurationFormat.latencyMs(2000), equals('2.0s'));
    });
  });

  group('TokenFormat', () {
    test('count formats numbers', () {
      expect(TokenFormat.count(0), equals('0'));
      expect(TokenFormat.count(999), equals('999'));
      expect(TokenFormat.count(1000), equals('1,000'));
      expect(TokenFormat.count(1234567), equals('1,234,567'));
    });
  });

  group('Validators', () {
    test('modelId validates correctly', () {
      expect(Validators.modelId('gpt-4o'), isNull);
      expect(Validators.modelId(''), isNotNull);
      expect(Validators.modelId(null), isNotNull);
    });

    test('prompt validates correctly', () {
      expect(Validators.prompt('Is AI good?'), isNull);
      expect(Validators.prompt(''), isNotNull);
      expect(Validators.prompt('hi'), isNotNull); // too short
    });

    test('url validates correctly', () {
      expect(Validators.url('http://localhost:4000'), isNull);
      expect(Validators.url('https://api.example.com'), isNull);
      expect(Validators.url('not-a-url'), isNotNull);
      expect(Validators.url(''), isNotNull);
    });

    test('wsUrl validates correctly', () {
      expect(Validators.wsUrl('ws://localhost:8080'), isNull);
      expect(Validators.wsUrl('wss://relay.example.com'), isNull);
      expect(Validators.wsUrl('http://localhost:8080'), isNotNull);
      expect(Validators.wsUrl(''), isNotNull);
    });

    test('port validates range', () {
      expect(Validators.port('8080'), isNull);
      expect(Validators.port('1024'), isNull);
      expect(Validators.port('65535'), isNull);
      expect(Validators.port('1023'), isNotNull);
      expect(Validators.port('65536'), isNotNull);
      expect(Validators.port('abc'), isNotNull);
      expect(Validators.port(''), isNotNull);
    });

    test('displayName validates length', () {
      expect(Validators.displayName('Player'), isNull);
      expect(Validators.displayName('A' * 32), isNull);
      expect(Validators.displayName('A' * 33), isNotNull);
      expect(Validators.displayName(''), isNotNull);
    });
  });

  group('LobbyCodeUtil', () {
    test('extractId returns raw code for non-URL', () {
      expect(LobbyCodeUtil.extractId('abc-123-def'), equals('abc-123-def'));
    });

    test('extractId extracts ?id= from URL', () {
      expect(
        LobbyCodeUtil.extractId('http://localhost:8080/lobby?id=my-lobby-id'),
        equals('my-lobby-id'),
      );
    });

    test('buildShareUrl constructs correct URL', () {
      final url = LobbyCodeUtil.buildShareUrl(
          'lobby-xyz', 'ws://192.168.1.100:8080');
      expect(url, equals('http://192.168.1.100:8080/lobby?id=lobby-xyz'));
    });

    test('buildShareUrl handles wss', () {
      final url = LobbyCodeUtil.buildShareUrl(
          'lobby-abc', 'wss://relay.example.com');
      expect(url, startsWith('https://'));
    });
  });
}
