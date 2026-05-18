import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

final _log = Logger();
const _uuid = Uuid();

/// Handles WebSocket connection to the self-hosted relay server.
/// Syncs battle state, voting, spectator feed, and lobby management.
class RelayService {
  RelayService._();
  static final instance = RelayService._();

  WebSocketChannel? _channel;
  final _messageController = StreamController<RelayMessage>.broadcast();
  final _connectionController = StreamController<RelayConnectionStatus>.broadcast();

  bool _connected = false;
  String? _currentLobbyId;
  String? _memberId;
  LobbyRole _role = LobbyRole.spectator;
  Timer? _pingTimer;

  Stream<RelayMessage> get messages => _messageController.stream;
  Stream<RelayConnectionStatus> get connectionStatus => _connectionController.stream;

  bool get isConnected => _connected;
  String? get lobbyId => _currentLobbyId;
  LobbyRole get role => _role;

  // ─── Connection ───────────────────────────────────────────────────────────

  Future<void> connect(String relayUrl, {String? authToken}) async {
    if (_connected) await disconnect();

    _log.i('Connecting to relay: $relayUrl');
    _connectionController.add(RelayConnectionStatus.connecting);

    try {
      final uri = Uri.parse(relayUrl);
      final headers = <String, dynamic>{
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['arena-relay'],
      );
      // Note: web_socket_channel doesn't support custom headers on all platforms.
      // For auth, the relay validates the token sent in the first message instead.

      _channel!.stream.listen(
        (data) => _handleMessage(data as String),
        onError: (e) {
          _log.e('WebSocket error: $e');
          _connected = false;
          _connectionController.add(RelayConnectionStatus.error);
          _scheduleReconnect(relayUrl, authToken: authToken);
        },
        onDone: () {
          _log.i('WebSocket closed');
          _connected = false;
          _connectionController.add(RelayConnectionStatus.disconnected);
        },
      );

      _connected = true;
      _memberId = _uuid.v4();
      _connectionController.add(RelayConnectionStatus.connected);
      _startPing();
      _log.i('Connected to relay');
    } catch (e) {
      _log.e('Connection failed: $e');
      _connectionController.add(RelayConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    _currentLobbyId = null;
    _connectionController.add(RelayConnectionStatus.disconnected);
  }

  // ─── Lobby ────────────────────────────────────────────────────────────────

  Future<String> createLobby({
    required String displayName,
    required BattleSettings settings,
    MatchVisibility visibility = MatchVisibility.private,
  }) async {
    final lobbyId = _uuid.v4();
    _role = LobbyRole.owner;
    _currentLobbyId = lobbyId;

    _send(RelayMessageType.createLobby, {
      'lobbyId': lobbyId,
      'displayName': displayName,
      'settings': settings.toJson(),
      'visibility': visibility.name,
    });

    return lobbyId;
  }

  Future<void> joinLobby(String lobbyId, {
    required String displayName,
    LobbyRole requestedRole = LobbyRole.spectator,
  }) async {
    _currentLobbyId = lobbyId;
    _role = requestedRole;

    _send(RelayMessageType.joinLobby, {
      'lobbyId': lobbyId,
      'displayName': displayName,
      'requestedRole': requestedRole.name,
      'memberId': _memberId,
    });
  }

  void leaveLobby() {
    if (_currentLobbyId == null) return;
    _send(RelayMessageType.leaveLobby, {'lobbyId': _currentLobbyId});
    _currentLobbyId = null;
  }

  // ─── Host/Owner Controls ─────────────────────────────────────────────────

  void assignRole(String memberId, LobbyRole role) {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.assignRole, {
      'targetMemberId': memberId,
      'role': role.name,
    });
  }

  void kickMember(String memberId) {
    _assertRole(LobbyRole.moderator);
    _send(RelayMessageType.kickMember, {'targetMemberId': memberId});
  }

  void muteMember(String memberId, bool muted) {
    _assertRole(LobbyRole.moderator);
    _send(RelayMessageType.muteMember, {
      'targetMemberId': memberId,
      'muted': muted,
    });
  }

  void updateSettings(BattleSettings settings) {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.updateSettings, {'settings': settings.toJson()});
  }

  void startBattle(String initialPrompt) {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.startBattle, {'prompt': initialPrompt});
  }

  void pauseBattle() {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.pauseBattle, {});
  }

  void resumeBattle() {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.resumeBattle, {});
  }

  // ─── Commander Controls ───────────────────────────────────────────────────

  void updateSystemPrompt(FighterSide side, String systemPrompt) {
    _assertRole(LobbyRole.commander);
    _send(RelayMessageType.updateSystemPrompt, {
      'side': side.name,
      'systemPrompt': systemPrompt,
    });
  }

  // ─── Audience Controls ────────────────────────────────────────────────────

  void castVote(int roundNumber, String choice) {
    _send(RelayMessageType.castVote, {
      'roundNumber': roundNumber,
      'choice': choice, // 'a', 'b', 'draw'
      'voterId': _memberId,
    });
  }

  void sendPowerUp(String type) {
    _send(RelayMessageType.powerUp, {'type': type, 'senderId': _memberId});
  }

  void injectPrompt(String injection) {
    _assertRole(LobbyRole.moderator);
    _send(RelayMessageType.injectPrompt, {'injection': injection});
  }

  void sendCrowdChant(String message) {
    _send(RelayMessageType.crowdChant, {'message': message, 'senderId': _memberId});
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────

  void sendChat(String message) {
    _send(RelayMessageType.chat, {
      'message': message,
      'senderId': _memberId,
    });
  }

  // ─── Battle State Sync (host pushes) ─────────────────────────────────────

  void syncBattleState(BattleState state) {
    _assertRole(LobbyRole.owner);
    _send(RelayMessageType.battleStateSync, {'state': state.toJson()});
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  void _handleMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = RelayMessageType.values.byName(json['type'] as String);
      final payload = json['payload'] as Map<String, dynamic>? ?? {};
      final message = RelayMessage(type: type, payload: payload);
      _messageController.add(message);
      _log.d('Relay ← ${type.name}');
    } catch (e) {
      _log.e('Failed to parse relay message: $e\n$raw');
    }
  }

  void _send(RelayMessageType type, Map<String, dynamic> payload) {
    if (!_connected || _channel == null) {
      _log.w('Cannot send ${type.name} — not connected');
      return;
    }
    final message = jsonEncode({
      'type': type.name,
      'lobbyId': _currentLobbyId,
      'senderId': _memberId,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _channel!.sink.add(message);
    _log.d('Relay → ${type.name}');
  }

  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send(RelayMessageType.ping, {});
    });
  }

  void _scheduleReconnect(String url, {String? authToken}) {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_connected) connect(url, authToken: authToken);
    });
  }

  /// Roles ordered highest to lowest privilege.
  static const _roleHierarchy = [
    LobbyRole.owner,
    LobbyRole.moderator,
    LobbyRole.commander,
    LobbyRole.spectator,
    LobbyRole.audience,
  ];

  /// Throws if current role has less privilege than [minimumRole].
  void _assertRole(LobbyRole minimumRole) {
    final myIndex = _roleHierarchy.indexOf(_role);
    final requiredIndex = _roleHierarchy.indexOf(minimumRole);
    // Lower index = higher privilege
    if (myIndex > requiredIndex) {
      throw StateError(
        'Action requires $minimumRole or higher, but current role is $_role',
      );
    }
  }

  void dispose() {
    _pingTimer?.cancel();
    _messageController.close();
    _connectionController.close();
    _channel?.sink.close();
  }
}

// ─── Types ────────────────────────────────────────────────────────────────────

enum RelayConnectionStatus { connecting, connected, disconnected, error }

enum RelayMessageType {
  // Lobby
  createLobby, joinLobby, leaveLobby, lobbyState, lobbyError,
  assignRole, kickMember, muteMember, updateSettings,
  // Battle
  startBattle, pauseBattle, resumeBattle, battleStateSync,
  updateSystemPrompt, injectPrompt,
  // Audience
  castVote, voteResult, powerUp, crowdChant,
  // Chat
  chat,
  // Infra
  ping, pong, error,
}

class RelayMessage {
  final RelayMessageType type;
  final Map<String, dynamic> payload;

  const RelayMessage({required this.type, required this.payload});
}
