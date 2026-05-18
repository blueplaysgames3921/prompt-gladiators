import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../shared/theme/arena_theme.dart';

// ─── BuildContext extensions ──────────────────────────────────────────────────

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isWide => MediaQuery.sizeOf(this).width > 900;
  bool get isNarrow => MediaQuery.sizeOf(this).width <= 600;

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ArenaTheme.accent : null,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

// ─── String extensions ────────────────────────────────────────────────────────

extension StringX on String {
  /// Truncates to [maxLen] characters with ellipsis.
  String truncate(int maxLen, {String ellipsis = '…'}) {
    if (length <= maxLen) return this;
    return '${substring(0, maxLen)}$ellipsis';
  }

  /// "hello_world" -> "Hello World"
  String get titleCase => split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// true if string is a valid UUID v4
  bool get isUuid => RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(this);

  /// true if string looks like a ws:// or wss:// URL
  bool get isWsUrl {
    final uri = Uri.tryParse(this);
    return uri != null && (uri.scheme == 'ws' || uri.scheme == 'wss');
  }

  /// Strips leading/trailing whitespace and collapses internal whitespace.
  String get normalised => trim().replaceAll(RegExp(r'\s+'), ' ');
}

// ─── BattleState extensions ───────────────────────────────────────────────────

extension BattleStateX on BattleState {
  bool get isActive =>
      status == BattleStatus.inProgress || status == BattleStatus.paused;

  bool get isFinished => status == BattleStatus.complete;

  bool get hasWinner => winnerId != null;

  bool get isDraw => isFinished && winnerId == null;

  /// Returns the winning fighter config, or null on draw / not finished.
  FighterConfig? get winnerConfig {
    if (winnerId == null) return null;
    if (winnerId == fighterA.id) return fighterA;
    if (winnerId == fighterB.id) return fighterB;
    return null;
  }

  /// Score percentage for fighter A (0.0 – 1.0). Returns 0.5 if no scores.
  double get scoreRatioA {
    final total = totalScoreA + totalScoreB;
    if (total <= 0) return 0.5;
    return totalScoreA / total;
  }

  /// Number of completed rounds.
  int get completedRoundCount =>
      rounds.where((r) => r.status == BattleRoundStatus.complete).length;

  /// Current round or null if no rounds yet.
  BattleRound? get currentRoundData =>
      rounds.isNotEmpty ? rounds.last : null;
}

// ─── BattleSettings extensions ────────────────────────────────────────────────

extension BattleSettingsX on BattleSettings {
  /// Whether any scoring mechanism is active.
  bool get hasScoringActive => judgeEnabled || votingEnabled || scoreboardEnabled;

  /// Human-readable summary of active modifiers.
  String get modifierSummary {
    final parts = <String>[];
    if (judgeEnabled) parts.add('Judge');
    if (votingEnabled) parts.add('Voting');
    if (apocalypseMode) parts.add('Apocalypse');
    if (agentsPerSide > 1) parts.add('${agentsPerSide}× Agents');
    if (blindMode) parts.add('Blind');
    if (parts.isEmpty) return 'Standard';
    return parts.join(' · ');
  }
}

// ─── FighterConfig extensions ─────────────────────────────────────────────────

extension FighterConfigX on FighterConfig {
  Color get sideColor =>
      side == FighterSide.a ? ArenaTheme.fighterA : ArenaTheme.fighterB;

  String get displayName =>
      name.isNotEmpty ? name : 'Fighter ${side == FighterSide.a ? 'A' : 'B'}';

  String get sideLabel => side == FighterSide.a ? 'A' : 'B';
}

// ─── BattleRound extensions ───────────────────────────────────────────────────

extension BattleRoundX on BattleRound {
  bool get hasResponses => responseA.isNotEmpty && responseB.isNotEmpty;

  bool get hasJudgement => scoreA != null && scoreB != null;

  bool get hasVotes =>
      votes.isNotEmpty && votes.values.any((v) => v > 0);

  int get totalVotes =>
      votes.values.fold(0, (a, b) => a + b);

  /// 'a', 'b', or 'draw' — the winning side by vote count.
  String? get voteWinner {
    if (!hasVotes) return null;
    final aVotes = votes['a'] ?? 0;
    final bVotes = votes['b'] ?? 0;
    if (aVotes == bVotes) return 'draw';
    return aVotes > bVotes ? 'a' : 'b';
  }
}

// ─── LobbyMember extensions ───────────────────────────────────────────────────

extension LobbyMemberX on LobbyMember {
  bool get isOwner => role == LobbyRole.owner;
  bool get isModerator =>
      role == LobbyRole.owner || role == LobbyRole.moderator;
  bool get isCommander => role == LobbyRole.commander;
  bool get canVote =>
      role == LobbyRole.spectator || role == LobbyRole.audience;
}

// ─── List extensions ──────────────────────────────────────────────────────────

extension ListX<T> on List<T> {
  /// Splits list into chunks of [size].
  Iterable<List<T>> chunked(int size) sync* {
    for (var i = 0; i < length; i += size) {
      yield sublist(i, (i + size).clamp(0, length));
    }
  }

  /// Returns the element at [index] or [defaultValue] if out of range.
  T getOrDefault(int index, T defaultValue) =>
      index >= 0 && index < length ? this[index] : defaultValue;
}

// ─── Duration convenience ─────────────────────────────────────────────────────
// Note: .ms and .seconds are already provided by flutter_animate.
// These are additional helpers not covered by flutter_animate.

extension IntDurationX on int {
  Duration get minutes => Duration(minutes: this);
  Duration get hours => Duration(hours: this);
}
