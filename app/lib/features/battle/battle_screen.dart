import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'modes/commander_panel.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../shared/theme/arena_theme.dart';
import '../../shared/extensions/extensions.dart';
import '../../shared/widgets/arena_section.dart';
import '../../shared/widgets/arena_text_field.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key, required this.battleId});
  final String battleId;

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showDebugPanel = false;
  bool _showCommanderPanel = false;

  // For commander mode — track the side being commanded
  FighterSide? _commandingSide;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battle = ref.watch(activeBattleNotifierProvider);
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;

    if (battle == null) {
      return _NoActiveBattle();
    }

    return Scaffold(
      backgroundColor: ArenaTheme.background,
      appBar: _buildAppBar(context, battle),
      body: Column(
        children: [
          _ScoreBar(state: battle),
          _StatusStrip(state: battle),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _BattleBody(
                    state: battle,
                    tabController: _tabController,
                    settings: settings,
                  ),
                ),
                // Commander panel — shown when user has commander role
                if (_showCommanderPanel && _commandingSide != null)
                  CommanderPanel(
                    commandingSide: _commandingSide!,
                    currentSystemPrompt: _commandingSide == FighterSide.a
                        ? battle.fighterA.systemPrompt
                        : battle.fighterB.systemPrompt,
                    onSystemPromptChanged: (prompt) {
                      ref
                          .read(activeBattleNotifierProvider.notifier)
                          .swapModel(
                            _commandingSide!,
                            (_commandingSide == FighterSide.a
                                    ? battle.fighterA
                                    : battle.fighterB)
                                .copyWith(systemPrompt: prompt),
                          );
                    },
                  ),
                if (_showDebugPanel)
                  _DebugSidePanel(state: battle),
              ],
            ),
          ),
          _BottomBar(state: battle, settings: settings),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, BattleState battle) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        onPressed: () => _confirmExit(context),
      ),
      title: Row(
        children: [
          _BattleTypeBadge(type: battle.settings.battleType),
          const Gap(10),
          Text(
            'ROUND ${battle.currentRound} / ${battle.settings.roundCount}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
          ),
          if (battle.settings.blindMode) ...[
            const Gap(8),
            _Tag(label: 'BLIND', color: ArenaTheme.accentGold),
          ],
          if (battle.settings.apocalypseMode) ...[
            const Gap(8),
            _Tag(label: '🔥 APOCALYPSE', color: ArenaTheme.accent),
          ],
        ],
      ),
      actions: [
        // Pause / Resume
        if (battle.status == BattleStatus.inProgress)
          IconButton(
            icon: const Icon(Icons.pause_circle_outline_rounded),
            tooltip: 'Pause',
            onPressed: () =>
                ref.read(activeBattleNotifierProvider.notifier).pause(),
          ),
        if (battle.status == BattleStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded,
                color: ArenaTheme.accentGreen),
            tooltip: 'Resume',
            onPressed: () =>
                ref.read(activeBattleNotifierProvider.notifier).resume(),
          ),

        // Commander toggle — shown for commander mode battles
        if (battle.settings.battleType == BattleType.commander) ...[
          IconButton(
            icon: Icon(
              Icons.videogame_asset_rounded,
              color: _showCommanderPanel
                  ? ArenaTheme.accentBlue
                  : ArenaTheme.textMuted,
              size: 20,
            ),
            tooltip: 'Commander panel',
            onPressed: () => setState(() {
              _showCommanderPanel = !_showCommanderPanel;
              _commandingSide ??= FighterSide.a;
            }),
          ),
          // Side picker when commander panel is open
          if (_showCommanderPanel)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ToggleButtons(
                isSelected: [
                  _commandingSide == FighterSide.a,
                  _commandingSide == FighterSide.b,
                ],
                onPressed: (i) => setState(() =>
                    _commandingSide =
                        i == 0 ? FighterSide.a : FighterSide.b),
                color: ArenaTheme.textMuted,
                selectedColor: Colors.white,
                fillColor: _commandingSide == FighterSide.a
                    ? ArenaTheme.fighterA
                    : ArenaTheme.fighterB,
                borderColor: ArenaTheme.surfaceBorder,
                selectedBorderColor: ArenaTheme.surfaceBorder,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 28),
                children: const [
                  Text('A',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  Text('B',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
        ],

        // Debug toggle
        IconButton(
          icon: Icon(
            Icons.bug_report_outlined,
            color: _showDebugPanel ? ArenaTheme.accentGreen : ArenaTheme.textMuted,
            size: 20,
          ),
          tooltip: 'Debug panel',
          onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
        ),

        // Settings
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          tooltip: 'Battle settings',
          onPressed: () => _showSettingsSheet(context, battle),
        ),
        const Gap(4),
      ],
    );
  }

  void _confirmExit(BuildContext context) {
    final battle = ref.read(activeBattleNotifierProvider);
    if (battle?.status == BattleStatus.inProgress ||
        battle?.status == BattleStatus.paused) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: ArenaTheme.surfaceElevated,
          title: const Text('LEAVE BATTLE?'),
          content: const Text('The battle is still in progress. Leave anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('STAY'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ArenaTheme.accent),
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('LEAVE'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  void _showSettingsSheet(BuildContext context, BattleState battle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArenaTheme.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _BattleSettingsSheet(state: battle),
    );
  }
}

// ─── Score Bar ────────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context) {
    final totalScore = state.totalScoreA + state.totalScoreB;
    final ratioA = totalScore > 0 ? state.totalScoreA / totalScore : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: ArenaTheme.surface,
        border: Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Fighter A
              Expanded(
                child: _FighterInfo(
                  config: state.fighterA,
                  score: state.totalScoreA,
                  isWinner: state.winnerId == state.fighterA.id,
                  isThinking: state.status == BattleStatus.inProgress,
                ),
              ),

              // VS + round
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'VS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: ArenaTheme.textMuted,
                            fontSize: 14,
                            letterSpacing: 4,
                          ),
                    ),
                    if (state.status == BattleStatus.inProgress) ...[
                      const Gap(4),
                      SizedBox(
                        width: 48,
                        child: LinearProgressIndicator(
                          backgroundColor: ArenaTheme.surfaceBorder,
                          color: ArenaTheme.accent,
                          minHeight: 2,
                        ),
                      ).animate(onPlay: (c) => c.repeat()).shimmer(
                            duration: 1200.ms,
                            color: ArenaTheme.accent.withOpacity(0.3),
                          ),
                    ],
                  ],
                ),
              ),

              // Fighter B
              Expanded(
                child: _FighterInfo(
                  config: state.fighterB,
                  score: state.totalScoreB,
                  isWinner: state.winnerId == state.fighterB.id,
                  isThinking: state.status == BattleStatus.inProgress,
                  reversed: true,
                ),
              ),
            ],
          ),
          const Gap(10),

          // Score ratio bar
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: Stack(
              children: [
                Container(height: 3, color: ArenaTheme.surfaceBorder),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  widthFactor: ratioA,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ArenaTheme.fighterA, ArenaTheme.accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FighterInfo extends StatelessWidget {
  const _FighterInfo({
    required this.config,
    required this.score,
    required this.isWinner,
    required this.isThinking,
    this.reversed = false,
  });

  final FighterConfig config;
  final double score;
  final bool isWinner;
  final bool isThinking;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final color =
        config.side == FighterSide.a ? ArenaTheme.fighterA : ArenaTheme.fighterB;

    final nameWidget = Column(
      crossAxisAlignment:
          reversed ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              reversed ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isThinking && !reversed) _ThinkingIndicator(color: color),
            if (isWinner && !reversed)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.emoji_events_rounded,
                    color: ArenaTheme.accentGold, size: 14),
              ),
            Text(
              config.displayName.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontSize: 13,
                  ),
            ),
            if (isWinner && reversed)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.emoji_events_rounded,
                    color: ArenaTheme.accentGold, size: 14),
              ),
            if (isThinking && reversed) _ThinkingIndicator(color: color),
          ],
        ),
        Text(
          config.modelId.isEmpty ? 'No model' : config.modelId,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final scoreWidget = Text(
      score.toStringAsFixed(1),
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: color,
            fontSize: 28,
          ),
    );

    return Row(
      mainAxisAlignment:
          reversed ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: reversed
          ? [scoreWidget, const Gap(12), Expanded(child: nameWidget)]
          : [Expanded(child: nameWidget), const Gap(12), scoreWidget],
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.color});
  final Color color;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 900.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final val =
                math.sin((_ctrl.value + delay) * math.pi).clamp(0.0, 1.0);
            return Container(
              width: 3,
              height: 3 + val * 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: widget.color.withOpacity(0.4 + val * 0.6),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Status Strip ─────────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state.status) {
      BattleStatus.lobby => (ArenaTheme.textMuted, 'WAITING IN LOBBY'),
      BattleStatus.countdown => (ArenaTheme.accentGold, 'STARTING SOON'),
      BattleStatus.inProgress => (ArenaTheme.accentGreen, 'BATTLE IN PROGRESS'),
      BattleStatus.paused => (ArenaTheme.accentGold, 'PAUSED'),
      BattleStatus.judging => (ArenaTheme.accentBlue, 'JUDGING'),
      BattleStatus.voting => (ArenaTheme.accentBlue, 'VOTING OPEN'),
      BattleStatus.complete => (ArenaTheme.accentGold, 'BATTLE COMPLETE'),
    };

    final spectators = state.members
        .where((m) =>
            m.role == LobbyRole.spectator || m.role == LobbyRole.audience)
        .length;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: color.withOpacity(0.07),
      child: Row(
        children: [
          _PulsingDot(color: color, active: state.status == BattleStatus.inProgress),
          const Gap(8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontSize: 10,
                ),
          ),
          if (spectators > 0) ...[
            const Gap(16),
            const Icon(Icons.remove_red_eye_outlined,
                size: 11, color: ArenaTheme.textMuted),
            const Gap(4),
            Text(
              '$spectators watching',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 10),
            ),
          ],
          const Spacer(),
          if (state.settings.judgeEnabled)
            _MicroTag(label: 'JUDGE', color: ArenaTheme.accentGold),
          if (state.settings.votingEnabled) ...[
            const Gap(6),
            _MicroTag(label: 'VOTING', color: ArenaTheme.accentBlue),
          ],
          if (state.settings.agentsPerSide > 1) ...[
            const Gap(6),
            _MicroTag(
              label: '${state.settings.agentsPerSide}× AGENTS',
              color: ArenaTheme.accentGreen,
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 900.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
          width: 6, height: 6, color: widget.color.withOpacity(0.5));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_ctrl.value * 0.8),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroTag extends StatelessWidget {
  const _MicroTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 8,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Battle Body ──────────────────────────────────────────────────────────────

class _BattleBody extends StatelessWidget {
  const _BattleBody({
    required this.state,
    required this.tabController,
    required this.settings,
  });
  final BattleState state;
  final TabController tabController;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    if (state.status == BattleStatus.lobby ||
        state.status == BattleStatus.countdown) {
      return _WaitingView(state: state);
    }

    return Column(
      children: [
        Container(
          color: ArenaTheme.surface,
          child: TabBar(
            controller: tabController,
            labelColor: ArenaTheme.textPrimary,
            unselectedLabelColor: ArenaTheme.textMuted,
            indicatorColor: ArenaTheme.accent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 14),
                    const Gap(4),
                    const Text('BATTLE'),
                    if (state.rounds.isNotEmpty) ...[
                      const Gap(6),
                      _RoundBadge(count: state.rounds.length),
                    ],
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 14),
                    Gap(4),
                    Text('SCORES'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 14),
                    const Gap(4),
                    const Text('LOBBY'),
                    if (state.members.isNotEmpty) ...[
                      const Gap(6),
                      _RoundBadge(
                        count: state.members.length,
                        color: ArenaTheme.accentBlue,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _RoundsTab(state: state, settings: settings),
              _ScoresTab(state: state),
              _LobbyTab(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.count, this.color = ArenaTheme.accent});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontFamily: 'SpaceMono', fontSize: 9, color: color),
      ),
    );
  }
}

// ─── Waiting View ─────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context) {
    final isCountdown = state.status == BattleStatus.countdown;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCountdown) ...[
            Text(
              '3',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: ArenaTheme.accent,
                    fontSize: 96,
                  ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeOut(duration: 900.ms)
                .then()
                .fadeIn(duration: 100.ms),
            const Gap(16),
          ],
          Text(
            isCountdown ? 'GET READY' : 'WAITING TO START',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: isCountdown
                      ? ArenaTheme.accentGold
                      : ArenaTheme.textMuted,
                ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeOut(duration: 1400.ms)
              .then()
              .fadeIn(duration: 1400.ms),
          const Gap(12),
          Text(
            isCountdown
                ? 'Battle begins momentarily...'
                : 'The host will start the battle',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─── Rounds Tab ───────────────────────────────────────────────────────────────

class _RoundsTab extends StatelessWidget {
  const _RoundsTab({required this.state, required this.settings});
  final BattleState state;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    if (state.rounds.isEmpty) {
      return const Center(
        child: Text('Rounds will appear here during battle'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.rounds.length,
      itemBuilder: (context, i) {
        return _RoundCard(
          round: state.rounds[i],
          settings: state.settings,
          showRawPayloads:
              settings?.debug.showRawPayloads ?? false,
          showTokens: settings?.debug.showTokenCounts ?? false,
          showLatency: settings?.debug.showLatencyMetrics ?? false,
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: i * 40))
            .slideY(begin: 0.04);
      },
    );
  }
}

// ─── Round Card ───────────────────────────────────────────────────────────────

class _RoundCard extends StatefulWidget {
  const _RoundCard({
    required this.round,
    required this.settings,
    required this.showRawPayloads,
    required this.showTokens,
    required this.showLatency,
  });
  final BattleRound round;
  final BattleSettings settings;
  final bool showRawPayloads;
  final bool showTokens;
  final bool showLatency;

  @override
  State<_RoundCard> createState() => _RoundCardState();
}

class _RoundCardState extends State<_RoundCard> {
  bool _expandedPayload = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.round;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ArenaTheme.surfaceElevated,
        border: Border.all(color: ArenaTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Round header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: const BoxDecoration(
              color: ArenaTheme.surface,
              border: Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ArenaTheme.accent.withOpacity(0.12),
                    border: Border.all(
                        color: ArenaTheme.accent.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '${r.roundNumber}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: ArenaTheme.accent,
                            fontSize: 12,
                          ),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    r.prompt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArenaTheme.textSecondary,
                          fontSize: 11,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                _RoundStatusChip(status: r.status),
              ],
            ),
          ),

          // ── Responses
          if (r.responseA.isNotEmpty || r.responseB.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ResponsePane(
                      label: 'A',
                      response: r.responseA,
                      color: ArenaTheme.fighterA,
                      score: r.scoreA,
                      tokens: widget.showTokens ? r.tokensA : null,
                      latencyMs: widget.showLatency ? r.latencyMsA : null,
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: ArenaTheme.surfaceBorder,
                  ),
                  Expanded(
                    child: _ResponsePane(
                      label: 'B',
                      response: r.responseB,
                      color: ArenaTheme.fighterB,
                      score: r.scoreB,
                      tokens: widget.showTokens ? r.tokensB : null,
                      latencyMs: widget.showLatency ? r.latencyMsB : null,
                    ),
                  ),
                ],
              ),
            ),

          // ── Vote tally
          if (r.votes.isNotEmpty)
            _VoteTally(votes: r.votes),

          // ── Judge verdict
          if (r.judgeVerdict != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ArenaTheme.accentGold.withOpacity(0.06),
                border: Border.all(
                    color: ArenaTheme.accentGold.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel_rounded,
                      color: ArenaTheme.accentGold, size: 14),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      r.judgeVerdict!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ArenaTheme.accentGold,
                            fontSize: 11,
                          ),
                    ),
                  ),
                  if (r.scoreA != null && r.scoreB != null)
                    Row(
                      children: [
                        _ScoreChip(
                            score: r.scoreA!, color: ArenaTheme.fighterA),
                        const Gap(4),
                        _ScoreChip(
                            score: r.scoreB!, color: ArenaTheme.fighterB),
                      ],
                    ),
                ],
              ),
            ),

          // ── Raw payload toggle (debug)
          if (widget.showRawPayloads &&
              (r.rawPayloadA != null || r.rawPayloadB != null))
            InkWell(
              onTap: () =>
                  setState(() => _expandedPayload = !_expandedPayload),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: ArenaTheme.surfaceBorder)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 12, color: ArenaTheme.accentGreen),
                    const Gap(6),
                    Text(
                      'RAW PAYLOAD',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ArenaTheme.accentGreen,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                    ),
                    const Spacer(),
                    Icon(
                      _expandedPayload
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 14,
                      color: ArenaTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          if (widget.showRawPayloads && _expandedPayload)
            Container(
              padding: const EdgeInsets.all(12),
              color: ArenaTheme.background,
              child: SelectableText(
                r.rawPayloadA ?? r.rawPayloadB ?? '',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: ArenaTheme.accentGreen,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResponsePane extends StatelessWidget {
  const _ResponsePane({
    required this.label,
    required this.response,
    required this.color,
    this.score,
    this.tokens,
    this.latencyMs,
  });

  final String label;
  final String response;
  final Color color;
  final double? score;
  final int? tokens;
  final int? latencyMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pane header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: color.withOpacity(0.15),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (score != null) ...[
              const Gap(6),
              Text(
                score!.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
            const Spacer(),
            if (tokens != null)
              Text(
                '${tokens}t',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: ArenaTheme.textMuted,
                ),
              ),
            if (latencyMs != null) ...[
              const Gap(6),
              Text(
                '${latencyMs}ms',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: ArenaTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
        const Gap(8),

        // Response content
        response.isEmpty
            ? Row(
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: color,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Thinking...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArenaTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              )
            : MarkdownBody(
                data: response,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.6,
                      ),
                  code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        backgroundColor: ArenaTheme.surface,
                        color: ArenaTheme.accentGreen,
                      ),
                  codeblockDecoration: BoxDecoration(
                    color: ArenaTheme.surface,
                    border: Border.all(color: ArenaTheme.surfaceBorder),
                  ),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: ArenaTheme.accentBlue, width: 3),
                    ),
                    color: Color(0x0A3C8EFF),
                  ),
                ),
              ),
      ],
    );
  }
}

class _VoteTally extends StatelessWidget {
  const _VoteTally({required this.votes});
  final Map<String, int> votes;

  @override
  Widget build(BuildContext context) {
    final totalVotes = votes.values.fold(0, (a, b) => a + b);
    if (totalVotes == 0) return const SizedBox.shrink();

    final aVotes = votes['a'] ?? 0;
    final bVotes = votes['b'] ?? 0;
    final drawVotes = votes['draw'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ArenaTheme.accentBlue.withOpacity(0.05),
        border: Border.all(color: ArenaTheme.accentBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote_outlined,
              size: 12, color: ArenaTheme.accentBlue),
          const Gap(8),
          Text(
            '$totalVotes votes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  color: ArenaTheme.accentBlue,
                ),
          ),
          const Gap(12),
          _VoteBar(label: 'A', count: aVotes, total: totalVotes, color: ArenaTheme.fighterA),
          const Gap(8),
          _VoteBar(label: 'B', count: bVotes, total: totalVotes, color: ArenaTheme.fighterB),
          if (drawVotes > 0) ...[
            const Gap(8),
            _VoteBar(label: '=', count: drawVotes, total: totalVotes, color: ArenaTheme.textSecondary),
          ],
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'SpaceMono', fontSize: 9, color: color)),
        const Gap(4),
        SizedBox(
          width: 40,
          height: 6,
          child: Stack(
            children: [
              Container(color: ArenaTheme.surfaceBorder),
              AnimatedFractionallySizedBox(
                duration: 600.ms,
                widthFactor: count / total,
                child: Container(color: color),
              ),
            ],
          ),
        ),
        const Gap(3),
        Text(
          '$pct%',
          style: TextStyle(
              fontFamily: 'SpaceMono', fontSize: 9, color: ArenaTheme.textMuted),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      color: color.withOpacity(0.15),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          color: color,
        ),
      ),
    );
  }
}

class _RoundStatusChip extends StatelessWidget {
  const _RoundStatusChip({required this.status});
  final BattleRoundStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      BattleRoundStatus.pending => (ArenaTheme.textMuted, 'PENDING'),
      BattleRoundStatus.inProgress => (ArenaTheme.accentGreen, 'LIVE'),
      BattleRoundStatus.judging => (ArenaTheme.accentGold, 'JUDGING'),
      BattleRoundStatus.voting => (ArenaTheme.accentBlue, 'VOTING'),
      BattleRoundStatus.complete => (ArenaTheme.textMuted, 'DONE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 9,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Scores Tab ───────────────────────────────────────────────────────────────

class _ScoresTab extends StatelessWidget {
  const _ScoresTab({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context) {
    final rounds =
        state.rounds.where((r) => r.scoreA != null || r.scoreB != null).toList();

    if (rounds.isEmpty) {
      return Center(
        child: Text('Scores appear after each judged round',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ArenaTheme.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total scores
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: ArenaTheme.surfaceElevated,
            border: Border.all(color: ArenaTheme.surfaceBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BigScore(
                label: state.fighterA.name,
                score: state.totalScoreA,
                color: ArenaTheme.fighterA,
                isWinner: state.winnerId == state.fighterA.id,
              ),
              Text('TOTAL',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ArenaTheme.textMuted)),
              _BigScore(
                label: state.fighterB.name,
                score: state.totalScoreB,
                color: ArenaTheme.fighterB,
                isWinner: state.winnerId == state.fighterB.id,
                reversed: true,
              ),
            ],
          ),
        ),

        // Per-round
        ...rounds.asMap().entries.map((e) {
          final r = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: ArenaTheme.surfaceElevated,
              border: Border.all(color: ArenaTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Text('R${r.roundNumber}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: ArenaTheme.textMuted,
                          fontSize: 11,
                        )),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.judgeVerdict != null)
                        Text(
                          r.judgeVerdict!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Gap(12),
                if (r.scoreA != null)
                  _ScoreChip(score: r.scoreA!, color: ArenaTheme.fighterA),
                const Gap(4),
                if (r.scoreB != null)
                  _ScoreChip(score: r.scoreB!, color: ArenaTheme.fighterB),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _BigScore extends StatelessWidget {
  const _BigScore({
    required this.label,
    required this.score,
    required this.color,
    required this.isWinner,
    this.reversed = false,
  });
  final String label;
  final double score;
  final Color color;
  final bool isWinner;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          reversed ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isWinner)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!reversed)
                const Icon(Icons.emoji_events_rounded,
                    color: ArenaTheme.accentGold, size: 12),
              Text(
                ' WINNER ',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ArenaTheme.accentGold, fontSize: 9),
              ),
              if (reversed)
                const Icon(Icons.emoji_events_rounded,
                    color: ArenaTheme.accentGold, size: 12),
            ],
          ),
        Text(
          score.toStringAsFixed(1),
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(color: color, fontSize: 36),
        ),
        Text(
          label.isEmpty ? '—' : label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ArenaTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

// ─── Lobby Tab ────────────────────────────────────────────────────────────────

class _LobbyTab extends ConsumerWidget {
  const _LobbyTab({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 32, color: ArenaTheme.textMuted),
            const Gap(12),
            Text(
              'LOCAL MATCH',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: ArenaTheme.textMuted),
            ),
            const Gap(4),
            Text('No lobby members — running locally',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.members.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: ArenaTheme.surfaceBorder),
      itemBuilder: (context, i) {
        final m = state.members[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 32,
            height: 32,
            color: _roleColor(m.role).withOpacity(0.12),
            child: Icon(_roleIcon(m.role),
                color: _roleColor(m.role), size: 14),
          ),
          title: Text(m.displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 13)),
          subtitle: m.commandingSide != null
              ? Text('Commanding side ${m.commandingSide!.name.toUpperCase()}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 10))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.isConnected
                      ? ArenaTheme.accentGreen
                      : ArenaTheme.textMuted,
                ),
              ),
              const Gap(8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _roleColor(m.role).withOpacity(0.1),
                  border: Border.all(
                      color: _roleColor(m.role).withOpacity(0.3)),
                ),
                child: Text(
                  m.role.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    color: _roleColor(m.role),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _roleColor(LobbyRole r) => switch (r) {
        LobbyRole.owner => ArenaTheme.accent,
        LobbyRole.moderator => ArenaTheme.accentGold,
        LobbyRole.commander => ArenaTheme.accentBlue,
        LobbyRole.spectator => ArenaTheme.textSecondary,
        LobbyRole.audience => ArenaTheme.textMuted,
      };

  IconData _roleIcon(LobbyRole r) => switch (r) {
        LobbyRole.owner => Icons.shield_rounded,
        LobbyRole.moderator => Icons.security_rounded,
        LobbyRole.commander => Icons.videogame_asset_rounded,
        LobbyRole.spectator => Icons.visibility_rounded,
        LobbyRole.audience => Icons.people_rounded,
      };
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.state, required this.settings});
  final BattleState state;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Victory bar
    if (state.status == BattleStatus.complete) {
      return _VictoryBar(state: state);
    }

    // Voting bar
    if (state.status == BattleStatus.voting) {
      return _VotingBar(
        state: state,
        onVote: (choice) =>
            ref.read(activeBattleNotifierProvider.notifier).vote(
                  state.currentRound,
                  'local',
                  choice,
                ),
      );
    }

    // Audience controls
    if (state.settings.audienceControlsEnabled) {
      return _AudienceBar(
        onInject: (text) => ref
            .read(activeBattleNotifierProvider.notifier)
            .injectPrompt(text),
      );
    }

    return const SizedBox.shrink();
  }
}

class _VotingBar extends StatelessWidget {
  const _VotingBar({required this.state, required this.onVote});
  final BattleState state;
  final void Function(String) onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: ArenaTheme.surfaceElevated,
        border: Border(
          top: BorderSide(color: ArenaTheme.accentBlue, width: 2),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CAST YOUR VOTE',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: ArenaTheme.accentBlue, fontSize: 11)),
              Text('Round ${state.currentRound}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Gap(20),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ArenaTheme.fighterA,
                  foregroundColor: Colors.white),
              onPressed: () => onVote('a'),
              child: Text(state.fighterA.displayName.toUpperCase()),
            ),
          ),
          const Gap(8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ArenaTheme.textMuted)),
            onPressed: () => onVote('draw'),
            child: const Text('DRAW'),
          ),
          const Gap(8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ArenaTheme.fighterB,
                  foregroundColor: Colors.white),
              onPressed: () => onVote('b'),
              child: Text(state.fighterB.displayName.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }
}

class _VictoryBar extends StatelessWidget {
  const _VictoryBar({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context) {
    final isDraw = state.winnerId == null;
    final isA = state.winnerId == state.fighterA.id;
    final winnerName = isDraw
        ? 'DRAW'
        : isA
            ? state.fighterA.displayName.toUpperCase()
            : state.fighterB.displayName.toUpperCase();
    final color = isDraw
        ? ArenaTheme.accentGold
        : isA
            ? ArenaTheme.fighterA
            : ArenaTheme.fighterB;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_rounded, color: ArenaTheme.accentGold, size: 20),
          const Gap(10),
          Text(
            isDraw ? 'DRAW' : '$winnerName WINS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontSize: 20,
                ),
          ),
          const Gap(10),
          const Icon(Icons.emoji_events_rounded, color: ArenaTheme.accentGold, size: 20),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
  }
}

class _AudienceBar extends StatelessWidget {
  const _AudienceBar({required this.onInject});
  final void Function(String) onInject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: ArenaTheme.surface,
        border: Border(top: BorderSide(color: ArenaTheme.surfaceBorder)),
      ),
      child: Row(
        children: [
          Text(
            'AUDIENCE',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ArenaTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
          ),
          const Gap(12),
          _AudienceBtn(
              icon: Icons.bolt_rounded,
              label: 'CHAOS',
              onTap: () {}),
          const Gap(6),
          _AudienceBtn(
              icon: Icons.local_fire_department_rounded,
              label: 'ROAST',
              onTap: () {}),
          const Gap(6),
          _AudienceBtn(
            icon: Icons.edit_note_rounded,
            label: 'INJECT',
            onTap: () => _showInjectDialog(context),
          ),
        ],
      ),
    );
  }

  void _showInjectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ArenaTheme.surfaceElevated,
        title: Text('INJECT PROMPT',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
        content: ArenaTextField(
          label: 'INJECTION',
          hint: 'Text to inject into the next round...',
          controller: ctrl,
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onInject(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('INJECT'),
          ),
        ],
      ),
    );
  }
}

class _AudienceBtn extends StatelessWidget {
  const _AudienceBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label,
          style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─── Debug Side Panel ─────────────────────────────────────────────────────────

class _DebugSidePanel extends ConsumerWidget {
  const _DebugSidePanel({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(debugLogNotifierProvider);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: ArenaTheme.surface,
        border: Border(left: BorderSide(color: ArenaTheme.surfaceBorder)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined,
                    color: ArenaTheme.accentGreen, size: 14),
                const Gap(6),
                Text(
                  'DEBUG',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ArenaTheme.accentGreen,
                        fontSize: 11,
                      ),
                ),
                const Spacer(),
                // State snapshot
                Text(
                  '${state.status.name.toUpperCase()} | R${state.currentRound}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: ArenaTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),

          // Score readout
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'A: ${state.totalScoreA.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: ArenaTheme.fighterA),
                ),
                const Spacer(),
                Text(
                  'B: ${state.totalScoreB.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: ArenaTheme.fighterB),
                ),
              ],
            ),
          ),

          // Event log
          Expanded(
            child: log.isEmpty
                ? Center(
                    child: Text('No events',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: ArenaTheme.textMuted)),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: log.length,
                    itemBuilder: (context, i) {
                      final entry = log[log.length - 1 - i];
                      final dirColor = switch (entry.direction) {
                        LogDirection.inbound => ArenaTheme.accentGreen,
                        LogDirection.outbound => ArenaTheme.accentBlue,
                        LogDirection.internal => ArenaTheme.accentGold,
                      };
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: ArenaTheme.surfaceBorder,
                                width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                                width: 4,
                                height: 4,
                                color: dirColor),
                            const Gap(6),
                            Expanded(
                              child: Text(
                                entry.label,
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 9,
                                  color: ArenaTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Battle Settings Sheet ────────────────────────────────────────────────────

class _BattleSettingsSheet extends ConsumerWidget {
  const _BattleSettingsSheet({required this.state});
  final BattleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final internalSettings =
        ref.watch(appSettingsNotifierProvider).valueOrNull?.internal;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              color: ArenaTheme.surfaceBorder,
            ),
          ),
          Text('MID-MATCH CONTROLS',
              style: Theme.of(context).textTheme.headlineMedium),
          const Gap(20),

          // Pause / resume
          ArenaSection(
            title: 'BATTLE CONTROL',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pause_rounded, size: 14),
                    label: const Text('PAUSE'),
                    onPressed: state.status == BattleStatus.inProgress
                        ? () {
                            ref
                                .read(activeBattleNotifierProvider.notifier)
                                .pause();
                            Navigator.pop(context);
                          }
                        : null,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 14),
                    label: const Text('RESUME'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: ArenaTheme.accentGreen),
                    onPressed: state.status == BattleStatus.paused
                        ? () {
                            ref
                                .read(activeBattleNotifierProvider.notifier)
                                .resume();
                            Navigator.pop(context);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Score override (internal)
          if (internalSettings?.allowScoreOverride == true) ...[
            const Gap(14),
            _ScoreOverrideSection(state: state),
          ],

          // Prompt inject (internal)
          if (internalSettings?.allowPromptInjection == true) ...[
            const Gap(14),
            _PromptInjectSection(),
          ],

          const Gap(32),
        ],
      ),
    );
  }
}

class _ScoreOverrideSection extends ConsumerStatefulWidget {
  const _ScoreOverrideSection({required this.state});
  final BattleState state;

  @override
  ConsumerState<_ScoreOverrideSection> createState() =>
      _ScoreOverrideSectionState();
}

class _ScoreOverrideSectionState extends ConsumerState<_ScoreOverrideSection> {
  late TextEditingController _aCtrl;
  late TextEditingController _bCtrl;

  @override
  void initState() {
    super.initState();
    _aCtrl = TextEditingController(
        text: widget.state.totalScoreA.toStringAsFixed(1));
    _bCtrl = TextEditingController(
        text: widget.state.totalScoreB.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArenaSection(
      title: 'SCORE OVERRIDE',
      titleColor: ArenaTheme.accent,
      child: Row(
        children: [
          Expanded(
            child: ArenaTextField(
              label: 'SCORE A',
              controller: _aCtrl,
            ),
          ),
          const Gap(8),
          Expanded(
            child: ArenaTextField(
              label: 'SCORE B',
              controller: _bCtrl,
            ),
          ),
          const Gap(8),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: ArenaTheme.accent),
            onPressed: () {
              final a = double.tryParse(_aCtrl.text) ?? 0;
              final b = double.tryParse(_bCtrl.text) ?? 0;
              ref
                  .read(activeBattleNotifierProvider.notifier)
                  .overrideScore(a: a, b: b);
              Navigator.pop(context);
            },
            child: const Text('SET'),
          ),
        ],
      ),
    );
  }
}

class _PromptInjectSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PromptInjectSection> createState() =>
      _PromptInjectSectionState();
}

class _PromptInjectSectionState extends ConsumerState<_PromptInjectSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArenaSection(
      title: 'PROMPT INJECTION',
      titleColor: ArenaTheme.accentGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaTextField(
            label: 'INJECT INTO NEXT ROUND',
            hint: 'Text to prepend to next round prompt...',
            controller: _ctrl,
            maxLines: 2,
          ),
          const Gap(8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ArenaTheme.accentGold,
                foregroundColor: Colors.black),
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty) {
                ref
                    .read(activeBattleNotifierProvider.notifier)
                    .injectPrompt(_ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('INJECT'),
          ),
        ],
      ),
    );
  }
}

// ─── No Active Battle ─────────────────────────────────────────────────────────

class _NoActiveBattle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: ArenaTheme.textMuted),
            const Gap(16),
            Text(
              'NO ACTIVE BATTLE',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: ArenaTheme.textMuted),
            ),
            const Gap(8),
            Text('Go back and start a new battle.',
                style: Theme.of(context).textTheme.bodyMedium),
            const Gap(24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('GO HOME'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tags ─────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 9,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _BattleTypeBadge extends StatelessWidget {
  const _BattleTypeBadge({required this.type});
  final BattleType type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      BattleType.classic => 'CLASSIC',
      BattleType.battlefield => 'BATTLEFIELD',
      BattleType.agenticSwarm => 'SWARM',
      BattleType.tournament => 'TOURNAMENT',
      BattleType.commander => 'COMMANDER',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: ArenaTheme.accent.withOpacity(0.12),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 9,
          color: ArenaTheme.accent,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
