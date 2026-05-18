import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_gladiators/core/services/relay_service.dart';

void main() {
  group('RelayService message types', () {
    test('all message types have unique string names', () {
      final names = RelayMessageType.values.map((t) => t.name).toList();
      final uniqueNames = names.toSet();
      expect(names.length, equals(uniqueNames.length),
          reason: 'Duplicate RelayMessageType names found');
    });

    test('RelayMessage stores type and payload', () {
      const msg = RelayMessage(
        type: RelayMessageType.battleStateSync,
        payload: {'status': 'inProgress', 'round': 2},
      );
      expect(msg.type, equals(RelayMessageType.battleStateSync));
      expect(msg.payload['status'], equals('inProgress'));
      expect(msg.payload['round'], equals(2));
    });

    test('relay connection status enum has expected values', () {
      expect(RelayConnectionStatus.values, contains(RelayConnectionStatus.connected));
      expect(RelayConnectionStatus.values, contains(RelayConnectionStatus.disconnected));
      expect(RelayConnectionStatus.values, contains(RelayConnectionStatus.connecting));
      expect(RelayConnectionStatus.values, contains(RelayConnectionStatus.error));
    });
  });

  group('RelayService singleton', () {
    test('instance is always the same object', () {
      final a = RelayService.instance;
      final b = RelayService.instance;
      expect(identical(a, b), isTrue);
    });

    test('starts disconnected', () {
      expect(RelayService.instance.isConnected, isFalse);
    });

    test('lobbyId is null initially', () {
      expect(RelayService.instance.lobbyId, isNull);
    });
  });

  group('Message type coverage', () {
    // Verify every message type we send from Flutter has a corresponding
    // relay server handler by checking the enum exhaustiveness
    test('all message types are present', () {
      final expected = [
        'createLobby', 'joinLobby', 'leaveLobby', 'lobbyState', 'lobbyError',
        'assignRole', 'kickMember', 'muteMember', 'updateSettings',
        'startBattle', 'pauseBattle', 'resumeBattle', 'battleStateSync',
        'updateSystemPrompt', 'injectPrompt',
        'castVote', 'voteResult', 'powerUp', 'crowdChant',
        'chat',
        'ping', 'pong', 'error',
      ];

      for (final name in expected) {
        final found = RelayMessageType.values
            .any((t) => t.name == name);
        expect(found, isTrue,
            reason: 'RelayMessageType.$name is missing from enum');
      }
    });
  });
}
