import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/services/litellm_service.dart';
import 'shared/theme/arena_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-start LiteLLM sidecar on desktop
  await LiteLLMService.instance.start().catchError((e) {
    debugPrint('LiteLLM sidecar failed to start: $e');
    // App continues — user can configure manually in Internal Settings
  });

  runApp(const ProviderScope(child: ArenaBattleApp()));
}

class ArenaBattleApp extends StatelessWidget {
  const ArenaBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Prompt Gladiators',
      debugShowCheckedModeBanner: false,
      theme: ArenaTheme.dark,
      routerConfig: appRouter,
    );
  }
}
