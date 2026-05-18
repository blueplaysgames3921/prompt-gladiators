import 'dart:io';
import 'package:flutter/foundation.dart';

// ─── Platform helpers ─────────────────────────────────────────────────────────

class PlatformUtil {
  PlatformUtil._();

  /// True if running on a desktop OS (macOS, Windows, Linux).
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// True if running on a mobile OS.
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// True if LiteLLM sidecar can be spawned (desktop only).
  static bool get canRunSidecar => isDesktop;

  /// Platform-appropriate config directory name.
  static String get configDirName => 'prompt-gladiators';
}

// ─── Duration formatters ──────────────────────────────────────────────────────

class DurationFormat {
  DurationFormat._();

  /// 90 -> "1m 30s"
  static String seconds(int totalSeconds) {
    if (totalSeconds <= 0) return '∞';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  /// Milliseconds to human-readable latency string.
  static String latencyMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final s = ms / 1000;
    return '${s.toStringAsFixed(1)}s';
  }

  /// DateTime to compact time string: "14:32:07.42"
  static String timestamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';

  /// DateTime to date string: "May 17"
  static String shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

// ─── Score formatters ─────────────────────────────────────────────────────────

class ScoreFormat {
  ScoreFormat._();

  /// 8.333... -> "8.3"
  static String score(double s) => s.toStringAsFixed(1);

  /// 8.333... -> "8.33"
  static String scorePrecise(double s) => s.toStringAsFixed(2);

  /// 1000 ELO change -> "+32" or "-12"
  static String eloDelta(int delta) =>
      delta >= 0 ? '+$delta' : '$delta';
}

// ─── Token formatters ─────────────────────────────────────────────────────────

class TokenFormat {
  TokenFormat._();

  /// 1234 -> "1,234"
  static String count(int n) {
    if (n < 1000) return '$n';
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  /// Estimated cost in USD at a given price per 1M tokens.
  static String estimatedCost(int tokens, {double pricePerMillion = 2.50}) {
    final cost = tokens / 1_000_000 * pricePerMillion;
    if (cost < 0.001) return '<\$0.001';
    return '\$${cost.toStringAsFixed(3)}';
  }
}

// ─── Model ID helpers ─────────────────────────────────────────────────────────

class ModelIdUtil {
  ModelIdUtil._();

  /// Extracts a display name from a LiteLLM model ID.
  /// "openai/gpt-4o" -> "GPT-4o"
  /// "gemini/gemini-2.0-flash" -> "Gemini 2.0 Flash"
  /// "gpt-4o" -> "GPT-4o"
  static String displayName(String modelId) {
    if (modelId.isEmpty) return 'Unknown';
    // Strip provider prefix
    var name = modelId.contains('/')
        ? modelId.split('/').last
        : modelId;

    // Known display names
    const known = <String, String>{
      'gpt-4o': 'GPT-4o',
      'gpt-4o-mini': 'GPT-4o mini',
      'gpt-4-turbo': 'GPT-4 Turbo',
      'o3': 'o3',
      'o3-mini': 'o3 mini',
      'gemini-2.0-flash': 'Gemini 2.0 Flash',
      'gemini-1.5-pro': 'Gemini 1.5 Pro',
      'gemini-1.5-flash': 'Gemini 1.5 Flash',
      'claude-3-5-sonnet-20241022': 'Claude 3.5 Sonnet',
      'claude-3-5-haiku-20241022': 'Claude 3.5 Haiku',
      'llama-3-70b-8192': 'Llama 3 70B',
      'llama-3-8b-8192': 'Llama 3 8B',
      'mixtral-8x7b-32768': 'Mixtral 8x7B',
      'grok-2-latest': 'Grok 2',
    };

    if (known.containsKey(name)) return known[name]!;

    // Humanise: "gemini-2.0-flash" -> "Gemini 2.0 Flash"
    return name
        .split('-')
        .map((p) => _capitalize(p))
        .join(' ');
  }

  /// Provider from model ID: "openai/gpt-4o" -> "openai"
  static String? provider(String modelId) {
    if (!modelId.contains('/')) return null;
    return modelId.split('/').first;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    if (s.length == 1) return s.toUpperCase();
    // Keep version numbers lowercase: "4o", "2.0"
    if (RegExp(r'^\d').hasMatch(s)) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─── Validators ──────────────────────────────────────────────────────────────

class Validators {
  Validators._();

  static String? modelId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Model ID is required';
    }
    return null;
  }

  static String? prompt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Battle prompt is required';
    }
    if (value.trim().length < 5) {
      return 'Prompt is too short';
    }
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return 'Enter a valid URL (e.g. http://localhost:4000)';
    }
    return null;
  }

  static String? wsUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'WebSocket URL is required';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return 'Enter a valid URL';
    if (!['ws', 'wss'].contains(uri.scheme)) {
      return 'URL must start with ws:// or wss://';
    }
    return null;
  }

  static String? port(String? value) {
    if (value == null || value.trim().isEmpty) return 'Port is required';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Port must be a number';
    if (n < 1024 || n > 65535) return 'Port must be 1024–65535';
    return null;
  }

  static String? displayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name is required';
    }
    if (value.trim().length > 32) {
      return 'Max 32 characters';
    }
    return null;
  }
}

// ─── JSON safety ──────────────────────────────────────────────────────────────

/// Safely extract a JSON object from text that may contain
/// markdown fences, prose, or other surrounding content.
Map<String, dynamic> extractJson(String raw) {
  try {
    var cleaned = raw.trim();

    // Strip markdown code fences
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      final lastFence = cleaned.lastIndexOf('```');
      if (firstNewline != -1 && lastFence > firstNewline) {
        cleaned = cleaned.substring(firstNewline + 1, lastFence).trim();
      }
    }

    // Find JSON object boundaries
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return {};

    final jsonStr = cleaned.substring(start, end + 1);

    // Basic import-free parse using dart:convert
    // (this file is imported without dart:convert so we return the string)
    // Actual parsing is done at the call site.
    return {'__raw__': jsonStr};
  } catch (_) {
    return {};
  }
}

// ─── Lobby code helpers ───────────────────────────────────────────────────────

class LobbyCodeUtil {
  LobbyCodeUtil._();

  /// Extract lobby ID from either a raw UUID or a URL with ?id= param.
  static String extractId(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('id')) {
      return uri.queryParameters['id']!;
    }
    return trimmed;
  }

  /// Build a shareable URL for a lobby.
  static String buildShareUrl(String lobbyId, String relayUrl) {
    final base = relayUrl
        .replaceFirst('ws://', 'http://')
        .replaceFirst('wss://', 'https://');
    return '$base/lobby?id=$lobbyId';
  }
}
