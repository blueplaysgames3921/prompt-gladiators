import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../shared/theme/arena_theme.dart';
import '../../shared/widgets/arena_section.dart';
import '../../shared/widgets/arena_text_field.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TOURNAMENT'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: ArenaTheme.accentGold,
          unselectedLabelColor: ArenaTheme.textMuted,
          indicatorColor: ArenaTheme.accentGold,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'LEADERBOARD'),
            Tab(text: 'BRACKET'),
            Tab(text: 'HISTORY'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add fighter',
            onPressed: () => _showAddFighter(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear tournament',
            onPressed: () => _confirmClear(context),
          ),
          const Gap(8),
        ],
      ),
      body: ref.watch(tournamentNotifierProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tournament) => TabBarView(
              controller: _tabs,
              children: [
                _LeaderboardTab(tournament: tournament),
                _BracketTab(tournament: tournament),
                _HistoryTab(tournament: tournament),
              ],
            ),
          ),
    );
  }

  void _showAddFighter(BuildContext context) {
    final modelIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ArenaTheme.surfaceElevated,
        title: const Text('ADD FIGHTER'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArenaTextField(
              label: 'DISPLAY NAME',
              controller: nameCtrl,
            ),
            const Gap(12),
            ArenaTextField(
              label: 'MODEL ID',
              hint: 'e.g. gpt-4o',
              controller: modelIdCtrl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (modelIdCtrl.text.isEmpty) return;
              ref.read(tournamentNotifierProvider.notifier).addEntry(
                    TournamentEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      modelId: modelIdCtrl.text.trim(),
                      modelName:
                          nameCtrl.text.trim().isEmpty
                              ? modelIdCtrl.text.trim()
                              : nameCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ArenaTheme.surfaceElevated,
        title: const Text('CLEAR TOURNAMENT?'),
        content: const Text(
            'This will delete all fighters and match history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: ArenaTheme.accent),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(tournamentNotifierProvider.notifier).clear();
    }
  }
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.tournament});
  final TournamentState tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.entries.isEmpty) {
      return _EmptyState(
        message: 'NO FIGHTERS YET',
        subtitle: 'Add fighters with the + button to start a tournament',
        icon: Icons.emoji_events,
      );
    }

    // Sort by ELO descending
    final sorted = [...tournament.entries]
      ..sort((a, b) => b.eloRating.compareTo(a.eloRating));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final entry = sorted[i];
        final isTop3 = i < 3;
        final medal = i == 0
            ? '🥇'
            : i == 1
                ? '🥈'
                : i == 2
                    ? '🥉'
                    : '${i + 1}.';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isTop3
                ? ArenaTheme.accentGold.withOpacity(0.06)
                : ArenaTheme.surfaceElevated,
            border: Border.all(
              color: isTop3
                  ? ArenaTheme.accentGold.withOpacity(0.3)
                  : ArenaTheme.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  medal,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: isTop3 ? 20 : 14,
                        color: isTop3
                            ? ArenaTheme.accentGold
                            : ArenaTheme.textMuted,
                      ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.modelName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      entry.modelId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Win/Loss/Draw
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.eloRating}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 22,
                          color: ArenaTheme.accentGold,
                        ),
                  ),
                  Text(
                    '${entry.wins}W  ${entry.draws}D  ${entry.losses}L',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
              const Gap(12),
              // Quick match button
              OutlinedButton(
                onPressed: () {
                  // Pre-fill fighter in lobby
                  context.push('/lobby/new');
                },
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('BATTLE'),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 40).ms).slideX(begin: 0.05);
      },
    );
  }
}

// ─── Bracket ──────────────────────────────────────────────────────────────────

class _BracketTab extends StatelessWidget {
  const _BracketTab({required this.tournament});
  final TournamentState tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.entries.length < 2) {
      return _EmptyState(
        message: 'NEED AT LEAST 2 FIGHTERS',
        subtitle: 'Add fighters to generate a bracket',
        icon: Icons.account_tree,
      );
    }

    final bracket = _generateBracket(tournament.entries);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bracket.map((round) {
            return _BracketRound(
              roundLabel: 'ROUND ${bracket.indexOf(round) + 1}',
              matches: round,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Generate a round-robin bracket from entries
  List<List<_BracketMatch>> _generateBracket(List<TournamentEntry> entries) {
    final rounds = <List<_BracketMatch>>[];
    final n = entries.length;

    // Simple round-robin: each entry plays every other once
    final matchups = <_BracketMatch>[];
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        matchups.add(_BracketMatch(
          entryA: entries[i],
          entryB: entries[j],
        ));
      }
    }

    // Group into rounds (no fighter plays twice in same round)
    while (matchups.isNotEmpty) {
      final round = <_BracketMatch>[];
      final usedIds = <String>{};
      for (final m in [...matchups]) {
        if (!usedIds.contains(m.entryA.id) && !usedIds.contains(m.entryB.id)) {
          round.add(m);
          usedIds.add(m.entryA.id);
          usedIds.add(m.entryB.id);
          matchups.remove(m);
        }
      }
      if (round.isEmpty) break; // safety
      rounds.add(round);
    }

    return rounds;
  }
}

class _BracketMatch {
  final TournamentEntry entryA;
  final TournamentEntry entryB;
  const _BracketMatch({required this.entryA, required this.entryB});
}

class _BracketRound extends ConsumerWidget {
  const _BracketRound({required this.roundLabel, required this.matches});
  final String roundLabel;
  final List<_BracketMatch> matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roundLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ArenaTheme.accentGold,
                  fontSize: 11,
                ),
          ),
          const Gap(12),
          ...matches.map((m) {
            return Container(
              width: 220,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ArenaTheme.surfaceElevated,
                border: Border.all(color: ArenaTheme.surfaceBorder),
              ),
              child: Column(
                children: [
                  _MatchSlot(entry: m.entryA, isWinner: false),
                  const Divider(height: 1),
                  _MatchSlot(entry: m.entryB, isWinner: false),
                  InkWell(
                    onTap: () => context.push('/lobby/new'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: ArenaTheme.accent.withOpacity(0.08),
                      child: Center(
                        child: Text(
                          'START MATCH',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: ArenaTheme.accent,
                                fontSize: 10,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MatchSlot extends StatelessWidget {
  const _MatchSlot({required this.entry, required this.isWinner});
  final TournamentEntry entry;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (isWinner)
            const Icon(Icons.star, color: ArenaTheme.accentGold, size: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.modelName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        color: isWinner
                            ? ArenaTheme.accentGold
                            : ArenaTheme.textPrimary,
                      ),
                ),
                Text(
                  '${entry.eloRating} ELO',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History ──────────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.tournament});
  final TournamentState tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.completedMatches.isEmpty) {
      return _EmptyState(
        message: 'NO MATCHES PLAYED',
        subtitle: 'Completed matches will appear here',
        icon: Icons.history,
      );
    }

    final sorted = [...tournament.completedMatches]
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final match = sorted[i];
        final entryA = tournament.entries
            .where((e) => e.id == match.entryAId)
            .firstOrNull;
        final entryB = tournament.entries
            .where((e) => e.id == match.entryBId)
            .firstOrNull;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ArenaTheme.surfaceElevated,
            border: Border.all(color: ArenaTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entryA?.modelName ?? match.entryAId,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: match.winnerId == match.entryAId
                            ? ArenaTheme.accentGreen
                            : ArenaTheme.textSecondary,
                        fontSize: 14,
                      ),
                  textAlign: TextAlign.end,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  match.isDraw ? 'DRAW' : 'vs',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: Text(
                  entryB?.modelName ?? match.entryBId,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: match.winnerId == match.entryBId
                            ? ArenaTheme.accentGreen
                            : ArenaTheme.textSecondary,
                        fontSize: 14,
                      ),
                ),
              ),
              const Gap(8),
              Text(
                _formatDate(match.playedAt),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 30).ms);
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.subtitle,
    required this.icon,
  });

  final String message;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: ArenaTheme.textMuted),
          const Gap(16),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: ArenaTheme.textMuted),
          ),
          const Gap(8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
