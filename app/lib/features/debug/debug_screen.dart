import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/config/providers.dart';
import '../../core/services/litellm_service.dart';
import '../../shared/theme/arena_theme.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DebugLogEntry? _selectedEntry;

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
        title: const Text('DEBUG CONSOLE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, size: 18),
            tooltip: 'Clear log',
            onPressed: () =>
                ref.read(debugLogNotifierProvider.notifier).clear(),
          ),
          const Gap(8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: ArenaTheme.accentGreen,
          unselectedLabelColor: ArenaTheme.textMuted,
          indicatorColor: ArenaTheme.accentGreen,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'EVENT LOG'),
            Tab(text: 'LITELLM'),
            Tab(text: 'BATTLE STATE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildEventLog(context),
          _buildLiteLLMTab(context),
          _buildBattleStateTab(context),
        ],
      ),
    );
  }

  // ─── Event Log ────────────────────────────────────────────────────────────

  Widget _buildEventLog(BuildContext context) {
    final log = ref.watch(debugLogNotifierProvider);

    if (log.isEmpty) {
      return Center(
        child: Text(
          'NO EVENTS YET',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ArenaTheme.textMuted,
                letterSpacing: 2,
              ),
        ),
      );
    }

    return Row(
      children: [
        // Event list
        Expanded(
          flex: 2,
          child: ListView.builder(
            reverse: true, // newest first
            itemCount: log.length,
            itemBuilder: (context, i) {
              final entry = log[log.length - 1 - i];
              final isSelected = _selectedEntry == entry;
              return InkWell(
                onTap: () => setState(() => _selectedEntry = entry),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ArenaTheme.accentGreen.withOpacity(0.08)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected
                            ? ArenaTheme.accentGreen
                            : Colors.transparent,
                        width: 2,
                      ),
                      bottom:
                          const BorderSide(color: ArenaTheme.surfaceBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Direction indicator
                      _DirectionIcon(direction: entry.direction),
                      const Gap(8),
                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        color: _sourceColor(entry.source).withOpacity(0.15),
                        child: Text(
                          entry.source,
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: _sourceColor(entry.source),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: 'SpaceMono',
                                fontSize: 11,
                                color: isSelected
                                    ? ArenaTheme.accentGreen
                                    : ArenaTheme.textPrimary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(entry.timestamp),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 9,
                              fontFamily: 'SpaceMono',
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Payload inspector
        if (_selectedEntry != null)
          Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: _PayloadInspector(entry: _selectedEntry!),
          ),
      ],
    );
  }

  // ─── LiteLLM Tab ─────────────────────────────────────────────────────────

  Widget _buildLiteLLMTab(BuildContext context) {
    final status = ref.watch(liteLLMStatusNotifierProvider);
    final models = ref.watch(availableModelsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Status
        _DebugCard(
          title: 'SIDECAR STATUS',
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status == LiteLLMStatus.healthy
                      ? ArenaTheme.accentGreen
                      : ArenaTheme.accent,
                ),
              ),
              const Gap(10),
              Text(
                status.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: status == LiteLLMStatus.healthy
                          ? ArenaTheme.accentGreen
                          : ArenaTheme.accent,
                    ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () =>
                    ref.read(liteLLMStatusNotifierProvider.notifier).restart(),
                child: const Text('RESTART'),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Available models
        _DebugCard(
          title: 'AVAILABLE MODELS',
          child: models.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(color: ArenaTheme.accent),
            ),
            data: (modelList) => modelList.isEmpty
                ? Text(
                    'No models found. Check LiteLLM config.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArenaTheme.textMuted,
                        ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: modelList
                        .map((m) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: ArenaTheme.accentGreen,
                                  ),
                                  const Gap(8),
                                  Text(
                                    m,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontFamily: 'SpaceMono',
                                          fontSize: 11,
                                        ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 12),
                                    color: ArenaTheme.textMuted,
                                    onPressed: () =>
                                        Clipboard.setData(ClipboardData(text: m)),
                                    tooltip: 'Copy model ID',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ),
        const Gap(16),

        // Health check
        _DebugCard(
          title: 'HEALTH CHECK',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final ok = await LiteLLMService.instance.healthCheck();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(ok ? '✓ Healthy' : '✗ Unreachable'),
                        backgroundColor:
                            ok ? ArenaTheme.accentGreen : ArenaTheme.accent,
                      ),
                    );
                  }
                },
                child: const Text('RUN HEALTH CHECK'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Battle State Tab ─────────────────────────────────────────────────────

  Widget _buildBattleStateTab(BuildContext context) {
    final battle = ref.watch(activeBattleNotifierProvider);

    if (battle == null) {
      return Center(
        child: Text(
          'NO ACTIVE BATTLE',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ArenaTheme.textMuted, letterSpacing: 2),
        ),
      );
    }

    final stateJson = const JsonEncoder.withIndent('  ').convert(
      battle.toJson(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Chip(
                label: Text(battle.status.name.toUpperCase()),
                backgroundColor: ArenaTheme.accent.withOpacity(0.15),
              ),
              const Gap(8),
              Text(
                'ROUND ${battle.currentRound}/${battle.settings.roundCount}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: stateJson)),
                tooltip: 'Copy state JSON',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              stateJson,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: ArenaTheme.accentGreen,
                    height: 1.5,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Color _sourceColor(String source) => switch (source) {
        'RELAY' => ArenaTheme.accentBlue,
        'ENGINE' => ArenaTheme.accentGreen,
        'LITELLM' => ArenaTheme.accentGold,
        _ => ArenaTheme.textSecondary,
      };

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _DirectionIcon extends StatelessWidget {
  const _DirectionIcon({required this.direction});
  final LogDirection direction;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (direction) {
      LogDirection.inbound => (Icons.arrow_downward, ArenaTheme.accentGreen),
      LogDirection.outbound => (Icons.arrow_upward, ArenaTheme.accentBlue),
      LogDirection.internal => (Icons.settings, ArenaTheme.accentGold),
    };
    return Icon(icon, size: 12, color: color);
  }
}

class _PayloadInspector extends StatelessWidget {
  const _PayloadInspector({required this.entry});
  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final json = const JsonEncoder.withIndent('  ').convert(entry.payload);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ArenaTheme.accentGreen,
                        fontSize: 11,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 14),
                color: ArenaTheme.textMuted,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: json)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              json,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    color: ArenaTheme.accentGreen,
                    height: 1.5,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArenaTheme.surfaceElevated,
        border: Border.all(color: ArenaTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    color: ArenaTheme.accentGreen,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
