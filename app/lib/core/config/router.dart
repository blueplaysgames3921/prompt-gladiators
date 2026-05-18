import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/battle/battle_screen.dart';
import '../features/tournament/tournament_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/debug/debug_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/lobby/new',
      builder: (_, __) => const LobbyScreen(mode: LobbyMode.create),
    ),
    GoRoute(
      path: '/lobby/join',
      builder: (context, state) {
        final lobbyId = state.uri.queryParameters['id'];
        return LobbyScreen(mode: LobbyMode.join, lobbyId: lobbyId);
      },
    ),
    GoRoute(
      path: '/battle/:id',
      builder: (context, state) {
        final battleId = state.pathParameters['id']!;
        return BattleScreen(battleId: battleId);
      },
    ),
    GoRoute(
      path: '/tournament',
      builder: (_, __) => const TournamentScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'game',
          builder: (_, __) => const SettingsScreen(initialTab: SettingsTab.game),
        ),
        GoRoute(
          path: 'debug',
          builder: (_, __) => const SettingsScreen(initialTab: SettingsTab.debug),
        ),
        GoRoute(
          path: 'internal',
          builder: (_, __) => const SettingsScreen(initialTab: SettingsTab.internal),
        ),
      ],
    ),
    GoRoute(
      path: '/debug',
      builder: (_, __) => const DebugScreen(),
    ),
  ],
);
