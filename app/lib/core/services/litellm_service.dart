import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final _log = Logger();

/// Manages the LiteLLM sidecar process and provides a typed client
/// for calling any model through the OpenAI-compatible proxy.
class LiteLLMService {
  LiteLLMService._();
  static final instance = LiteLLMService._();

  Process? _process;
  bool _running = false;
  String _baseUrl = 'http://localhost:4000';

  Dio get _dio => Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ));

  bool get isRunning => _running;
  String get baseUrl => _baseUrl;

  // ─── Sidecar Lifecycle ───────────────────────────────────────────────────

  /// Start LiteLLM sidecar. Only works on desktop platforms.
  Future<void> start({
    int port = 4000,
    String? configPath,
    bool verbose = false,
  }) async {
    if (_running) return;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      _log.i('LiteLLM sidecar not available on mobile — skipping');
      return;
    }

    _baseUrl = 'http://localhost:$port';
    final config = configPath ?? await _defaultConfigPath();

    // Ensure config exists
    await _ensureDefaultConfig(config);

    try {
      _log.i('Starting LiteLLM on port $port...');
      _process = await Process.start(
        'litellm',
        [
          '--config', config,
          '--port', '$port',
          if (verbose) '--detailed_debug',
        ],
        mode: ProcessStartMode.normal,
      );

      _process!.stdout.transform(utf8.decoder).listen((data) {
        _log.d('[LiteLLM] $data');
        if (data.contains('Application startup complete')) {
          _running = true;
          _log.i('LiteLLM ready on $_baseUrl');
        }
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        _log.w('[LiteLLM stderr] $data');
      });

      // Poll until ready
      await _waitForReady(port: port);
      _running = true;
    } catch (e) {
      _log.e('Failed to start LiteLLM: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    _running = false;
    _log.i('LiteLLM stopped');
  }

  Future<void> restart({int port = 4000, String? configPath}) async {
    await stop();
    await start(port: port, configPath: configPath);
  }

  // ─── Health ───────────────────────────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> listModels() async {
    try {
      final res = await _dio.get('/v1/models');
      final data = res.data as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((m) => m['id'] as String).toList();
    } catch (e) {
      _log.e('Failed to list models: $e');
      return [];
    }
  }

  // ─── Completions ─────────────────────────────────────────────────────────

  /// Standard (non-streaming) completion
  Future<CompletionResult> complete({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 2000,
    double temperature = 0.7,
    Map<String, dynamic> extra = const {},
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await _dio.post('/v1/chat/completions', data: {
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
        ...extra,
      });

      sw.stop();
      final d = res.data as Map<String, dynamic>;
      final choice = d['choices'][0];
      final usage = d['usage'] as Map<String, dynamic>? ?? {};

      return CompletionResult(
        content: choice['message']['content'] as String,
        inputTokens: usage['prompt_tokens'] as int? ?? 0,
        outputTokens: usage['completion_tokens'] as int? ?? 0,
        latencyMs: sw.elapsedMilliseconds,
        rawResponse: d,
      );
    } catch (e) {
      sw.stop();
      _log.e('Completion failed: $e');
      rethrow;
    }
  }

  /// Streaming completion — yields chunks
  Stream<String> stream({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 2000,
    double temperature = 0.7,
  }) async* {
    try {
      final res = await _dio.post<ResponseBody>(
        '/v1/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': temperature,
          'stream': true,
        },
        options: Options(responseType: ResponseType.stream),
      );

      await for (final chunk in res.data!.stream) {
        final lines = utf8.decode(chunk).split('\n');
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null) yield delta as String;
          } catch (_) {}
        }
      }
    } catch (e) {
      _log.e('Stream failed: $e');
      rethrow;
    }
  }

  // ─── Config ───────────────────────────────────────────────────────────────

  Future<String> readConfig() async {
    final path = await _defaultConfigPath();
    final file = File(path);
    if (await file.exists()) return file.readAsString();
    return _defaultConfigYaml;
  }

  Future<void> writeConfig(String yaml) async {
    final path = await _defaultConfigPath();
    await File(path).writeAsString(yaml);
    _log.i('LiteLLM config written to $path');
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<String> _defaultConfigPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'litellm_config.yaml');
  }

  Future<void> _ensureDefaultConfig(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.writeAsString(_defaultConfigYaml);
    }
  }

  Future<void> _waitForReady({required int port, int maxWaitMs = 15000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: maxWaitMs));
    while (DateTime.now().isBefore(deadline)) {
      if (await healthCheck()) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('LiteLLM did not start within ${maxWaitMs}ms');
  }
}

class CompletionResult {
  final String content;
  final int inputTokens;
  final int outputTokens;
  final int latencyMs;
  final Map<String, dynamic> rawResponse;

  const CompletionResult({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
    required this.latencyMs,
    required this.rawResponse,
  });
}

const _defaultConfigYaml = '''
# Prompt Gladiators — LiteLLM Config
# Edit via Settings > Internal > LiteLLM Config
# Docs: https://docs.litellm.ai/docs/proxy/configs

model_list:
  # Pollinations.ai (OpenAI-compatible)
  - model_name: pollinations/openai
    litellm_params:
      model: openai/openai
      api_base: https://text.pollinations.ai/openai
      api_key: your-pollinations-key

  # Add more models here:
  # - model_name: gpt-4o
  #   litellm_params:
  #     model: gpt-4o
  #     api_key: sk-...

  # - model_name: gemini-1.5-pro
  #   litellm_params:
  #     model: gemini/gemini-1.5-pro
  #     api_key: your-gemini-key

  # - model_name: local-ollama
  #   litellm_params:
  #     model: ollama/llama3
  #     api_base: http://localhost:11434

litellm_settings:
  drop_params: true
  set_verbose: false
''';
