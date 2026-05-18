import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../core/services/litellm_service.dart';
import '../../shared/theme/arena_theme.dart';
import '../../shared/widgets/arena_section.dart';
import '../../shared/widgets/arena_toggle.dart';
import '../../shared/widgets/arena_text_field.dart';

enum SettingsTab { game, debug, internal }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialTab = SettingsTab.game});
  final SettingsTab initialTab;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
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
        title: const Text('SETTINGS'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: ArenaTheme.textPrimary,
          unselectedLabelColor: ArenaTheme.textMuted,
          indicatorColor: ArenaTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'GAME'),
            Tab(text: 'DEBUG'),
            Tab(text: 'INTERNAL'),
          ],
        ),
      ),
      body: ref.watch(appSettingsNotifierProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (settings) => TabBarView(
              controller: _tabs,
              children: [
                _GameSettingsTab(settings: settings.battle),
                _DebugSettingsTab(settings: settings.debug),
                _InternalSettingsTab(settings: settings.internal),
              ],
            ),
          ),
    );
  }
}

// ─── Game Settings ────────────────────────────────────────────────────────────

class _GameSettingsTab extends ConsumerWidget {
  const _GameSettingsTab({required this.settings});
  final BattleSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(BattleSettings s) =>
        ref.read(appSettingsNotifierProvider.notifier).updateBattle(s);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Battle type
        ArenaSection(
          title: 'BATTLE TYPE',
          child: Column(
            children: BattleType.values.map((type) {
              return RadioListTile<BattleType>(
                value: type,
                groupValue: settings.battleType,
                activeColor: ArenaTheme.accent,
                title: Text(
                  _battleTypeLabel(type),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(
                  _battleTypeDesc(type),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onChanged: (v) => update(settings.copyWith(battleType: v!)),
              );
            }).toList(),
          ),
        ),
        const Gap(16),

        // Core round settings
        ArenaSection(
          title: 'MATCH RULES',
          child: Column(
            children: [
              _SliderRow(
                label: 'ROUNDS',
                value: settings.roundCount.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                displayValue: '${settings.roundCount}',
                onChanged: (v) => update(settings.copyWith(roundCount: v.round())),
              ),
              const Gap(12),
              _SliderRow(
                label: 'TIME LIMIT (sec)',
                value: settings.timeLimitSeconds.toDouble(),
                min: 0,
                max: 300,
                divisions: 30,
                displayValue: settings.timeLimitSeconds == 0
                    ? '∞'
                    : '${settings.timeLimitSeconds}s',
                onChanged: (v) =>
                    update(settings.copyWith(timeLimitSeconds: v.round())),
              ),
              const Gap(12),
              _SliderRow(
                label: 'TOKEN LIMIT',
                value: settings.tokenLimitPerTurn.toDouble(),
                min: 0,
                max: 8000,
                divisions: 80,
                displayValue: settings.tokenLimitPerTurn == 0
                    ? '∞'
                    : '${settings.tokenLimitPerTurn}',
                onChanged: (v) =>
                    update(settings.copyWith(tokenLimitPerTurn: v.round())),
              ),
              const Gap(12),
              ArenaToggle(
                label: 'BLIND MODE',
                subtitle: 'Hide model identities until match ends',
                value: settings.blindMode,
                onChanged: (v) => update(settings.copyWith(blindMode: v)),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Judge
        ArenaSection(
          title: 'JUDGE',
          trailing: ArenaToggle(
            label: '',
            value: settings.judgeEnabled,
            onChanged: (v) => update(settings.copyWith(judgeEnabled: v)),
            compact: true,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: settings.judgeEnabled
                ? Column(
                    children: [
                      ArenaTextField(
                        label: 'JUDGE MODEL ID',
                        hint: 'e.g. gpt-4o',
                        value: settings.judgeModelId ?? '',
                        onChanged: (v) => update(settings.copyWith(
                          judgeModelId: v.isEmpty ? null : v,
                        )),
                      ),
                      const Gap(12),
                      ArenaTextField(
                        label: 'SCORING CRITERIA',
                        hint: 'Describe how to score each response...',
                        value: settings.judgeCriteria,
                        maxLines: 3,
                        onChanged: (v) =>
                            update(settings.copyWith(judgeCriteria: v)),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Gap(16),

        // Scoreboard
        ArenaSection(
          title: 'SCOREBOARD',
          trailing: ArenaToggle(
            label: '',
            value: settings.scoreboardEnabled,
            onChanged: (v) => update(settings.copyWith(scoreboardEnabled: v)),
            compact: true,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: settings.scoreboardEnabled
                ? Column(
                    children: [
                      _SliderRow(
                        label: 'POINTS PER WIN',
                        value: settings.pointsPerRoundWin.toDouble(),
                        min: 1,
                        max: 50,
                        displayValue: '${settings.pointsPerRoundWin}',
                        onChanged: (v) => update(
                            settings.copyWith(pointsPerRoundWin: v.round())),
                      ),
                      const Gap(8),
                      _SliderRow(
                        label: 'POINTS PER DRAW',
                        value: settings.pointsPerRoundDraw.toDouble(),
                        min: 0,
                        max: 25,
                        displayValue: '${settings.pointsPerRoundDraw}',
                        onChanged: (v) => update(
                            settings.copyWith(pointsPerRoundDraw: v.round())),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Gap(16),

        // Voting
        ArenaSection(
          title: 'VOTING',
          trailing: ArenaToggle(
            label: '',
            value: settings.votingEnabled,
            onChanged: (v) => update(settings.copyWith(votingEnabled: v)),
            compact: true,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: settings.votingEnabled
                ? Column(
                    children: [
                      Row(
                        children: VotingTiming.values.map((t) {
                          return Expanded(
                            child: RadioListTile<VotingTiming>(
                              value: t,
                              groupValue: settings.votingTiming,
                              activeColor: ArenaTheme.accentBlue,
                              dense: true,
                              title: Text(
                                t == VotingTiming.perRound
                                    ? 'PER ROUND'
                                    : 'END OF MATCH',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 11),
                              ),
                              onChanged: (v) =>
                                  update(settings.copyWith(votingTiming: v!)),
                            ),
                          );
                        }).toList(),
                      ),
                      const Gap(8),
                      _SliderRow(
                        label: 'AUDIENCE WEIGHT',
                        value: settings.audienceVoteWeight,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        displayValue:
                            '${(settings.audienceVoteWeight * 100).round()}%',
                        onChanged: (v) =>
                            update(settings.copyWith(audienceVoteWeight: v)),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Gap(16),

        // Spectators & Audience
        ArenaSection(
          title: 'SPECTATORS & AUDIENCE',
          child: Column(
            children: [
              ArenaToggle(
                label: 'ALLOW SPECTATORS',
                value: settings.spectatorsAllowed,
                onChanged: (v) =>
                    update(settings.copyWith(spectatorsAllowed: v)),
              ),
              ArenaToggle(
                label: 'AUDIENCE CONTROLS',
                subtitle: 'Power-ups and prompt injections from audience',
                value: settings.audienceControlsEnabled,
                onChanged: (v) =>
                    update(settings.copyWith(audienceControlsEnabled: v)),
              ),
              ArenaToggle(
                label: 'CROWD CHANTS',
                subtitle: 'Audience can send chants that affect the battle',
                value: settings.crowdChantsEnabled,
                onChanged: (v) =>
                    update(settings.copyWith(crowdChantsEnabled: v)),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Apocalypse Mode
        ArenaSection(
          title: 'APOCALYPSE MODE',
          titleColor: ArenaTheme.accent,
          trailing: ArenaToggle(
            label: '',
            value: settings.apocalypseMode,
            onChanged: (v) => update(settings.copyWith(apocalypseMode: v)),
            compact: true,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: settings.apocalypseMode
                ? ArenaTextField(
                    label: 'ESCALATION PROMPT',
                    hint: 'How should pressure escalate each round?',
                    value: settings.apocalypsePrompt,
                    maxLines: 2,
                    onChanged: (v) =>
                        update(settings.copyWith(apocalypsePrompt: v)),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Gap(16),

        // Agentic
        ArenaSection(
          title: 'AGENTIC SWARM',
          child: Column(
            children: [
              _SliderRow(
                label: 'AGENTS PER SIDE',
                value: settings.agentsPerSide.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                displayValue: '${settings.agentsPerSide}',
                onChanged: (v) =>
                    update(settings.copyWith(agentsPerSide: v.round())),
              ),
              const Gap(12),
              Text('ALLOWED TOOLS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: ArenaTheme.textSecondary,
                      )),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AgentTool.values.map((tool) {
                  final enabled = settings.allowedTools.contains(tool);
                  return FilterChip(
                    label: Text(tool.name.toUpperCase()),
                    selected: enabled,
                    selectedColor: ArenaTheme.accentBlue.withOpacity(0.2),
                    checkmarkColor: ArenaTheme.accentBlue,
                    onSelected: (v) {
                      final tools = [...settings.allowedTools];
                      v ? tools.add(tool) : tools.remove(tool);
                      update(settings.copyWith(allowedTools: tools));
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Multiplayer
        ArenaSection(
          title: 'MULTIPLAYER',
          child: Column(
            children: [
              ArenaToggle(
                label: 'ENABLE MULTIPLAYER',
                value: settings.multiplayerEnabled,
                onChanged: (v) =>
                    update(settings.copyWith(multiplayerEnabled: v)),
              ),
              if (settings.multiplayerEnabled) ...[
                const Gap(8),
                Column(
                  children: MatchVisibility.values.map((vis) {
                    return RadioListTile<MatchVisibility>(
                      value: vis,
                      groupValue: settings.matchVisibility,
                      activeColor: ArenaTheme.accentBlue,
                      dense: true,
                      title: Text(
                        vis.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onChanged: (v) =>
                          update(settings.copyWith(matchVisibility: v!)),
                    );
                  }).toList(),
                ),
                ArenaToggle(
                  label: 'RANKED MATCH',
                  value: settings.rankedMatch,
                  onChanged: (v) => update(settings.copyWith(rankedMatch: v)),
                ),
              ],
            ],
          ),
        ),
        const Gap(32),
      ],
    );
  }

  String _battleTypeLabel(BattleType t) => switch (t) {
        BattleType.classic => 'Classic',
        BattleType.battlefield => 'Battlefield',
        BattleType.agenticSwarm => 'Agentic Swarm',
        BattleType.tournament => 'Tournament',
        BattleType.commander => 'Commander',
      };

  String _battleTypeDesc(BattleType t) => switch (t) {
        BattleType.classic => 'Same prompt, one round, vote the winner',
        BattleType.battlefield =>
          'Multi-round — models respond to each other\'s output',
        BattleType.agenticSwarm =>
          'Multi-agent teams with tool use and sub-agents',
        BattleType.tournament =>
          'Bracket system with ELO ratings and leaderboard',
        BattleType.commander =>
          'Human controls system prompt in real time during battle',
      };
}

// ─── Debug Settings ───────────────────────────────────────────────────────────

class _DebugSettingsTab extends ConsumerWidget {
  const _DebugSettingsTab({required this.settings});
  final DebugSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(DebugSettings s) =>
        ref.read(appSettingsNotifierProvider.notifier).updateDebug(s);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ArenaSection(
          title: 'OBSERVABILITY',
          child: Column(
            children: [
              ArenaToggle(
                label: 'VERBOSE LOGGING',
                subtitle: 'Full trace of engine and relay events',
                value: settings.verboseLogging,
                onChanged: (v) => update(settings.copyWith(verboseLogging: v)),
              ),
              ArenaToggle(
                label: 'SHOW RAW PAYLOADS',
                subtitle: 'Display raw API request/response JSON',
                value: settings.showRawPayloads,
                onChanged: (v) =>
                    update(settings.copyWith(showRawPayloads: v)),
              ),
              ArenaToggle(
                label: 'SHOW TOKEN COUNTS',
                subtitle: 'Per-turn input and output token counts',
                value: settings.showTokenCounts,
                onChanged: (v) =>
                    update(settings.copyWith(showTokenCounts: v)),
              ),
              ArenaToggle(
                label: 'SHOW LATENCY METRICS',
                subtitle: 'Response time per model per round',
                value: settings.showLatencyMetrics,
                onChanged: (v) =>
                    update(settings.copyWith(showLatencyMetrics: v)),
              ),
              ArenaToggle(
                label: 'WEBSOCKET INSPECTOR',
                subtitle: 'Log all relay WebSocket events',
                value: settings.wsEventInspector,
                onChanged: (v) =>
                    update(settings.copyWith(wsEventInspector: v)),
              ),
              ArenaToggle(
                label: 'LITELLM STATUS PANEL',
                subtitle: 'Show LiteLLM health and model list in sidebar',
                value: settings.showLiteLLMStatus,
                onChanged: (v) =>
                    update(settings.copyWith(showLiteLLMStatus: v)),
              ),
            ],
          ),
        ),
        const Gap(16),
        ArenaSection(
          title: 'TESTING',
          child: Column(
            children: [
              ArenaToggle(
                label: 'FORCE ERROR STATES',
                subtitle: 'Simulate model failures and network errors',
                value: settings.forceErrorStates,
                onChanged: (v) =>
                    update(settings.copyWith(forceErrorStates: v)),
              ),
              ArenaToggle(
                label: 'STEP-THROUGH MODE',
                subtitle: 'Pause battle after every round for inspection',
                value: settings.stepThroughMode,
                onChanged: (v) =>
                    update(settings.copyWith(stepThroughMode: v)),
              ),
            ],
          ),
        ),
        const Gap(16),
        ArenaSection(
          title: 'ACTIONS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('CLEAR DEBUG LOG'),
                onPressed: () =>
                    ref.read(debugLogNotifierProvider.notifier).clear(),
              ),
            ],
          ),
        ),
        const Gap(32),
      ],
    );
  }
}

// ─── Internal Settings ────────────────────────────────────────────────────────

class _InternalSettingsTab extends ConsumerStatefulWidget {
  const _InternalSettingsTab({required this.settings});
  final InternalSettings settings;

  @override
  ConsumerState<_InternalSettingsTab> createState() =>
      _InternalSettingsTabState();
}

class _InternalSettingsTabState extends ConsumerState<_InternalSettingsTab> {
  late TextEditingController _liteLLMUrlController;
  late TextEditingController _relayUrlController;
  late TextEditingController _relayTokenController;
  late TextEditingController _configYamlController;

  @override
  void initState() {
    super.initState();
    _liteLLMUrlController =
        TextEditingController(text: widget.settings.liteLLMUrl);
    _relayUrlController =
        TextEditingController(text: widget.settings.relayUrl);
    _relayTokenController =
        TextEditingController(text: widget.settings.relayAuthToken);
    _configYamlController =
        TextEditingController(text: widget.settings.liteLLMConfigYaml);
  }

  @override
  void dispose() {
    _liteLLMUrlController.dispose();
    _relayUrlController.dispose();
    _relayTokenController.dispose();
    _configYamlController.dispose();
    super.dispose();
  }

  void _update(InternalSettings s) =>
      ref.read(appSettingsNotifierProvider.notifier).updateInternal(s);

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final liteLLMStatus = ref.watch(liteLLMStatusNotifierProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // LiteLLM
        ArenaSection(
          title: 'LITELLM SIDECAR',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusIndicator(
                    status: liteLLMStatus == LiteLLMStatus.healthy,
                    label: liteLLMStatus.name.toUpperCase(),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('RESTART'),
                    onPressed: () => ref
                        .read(liteLLMStatusNotifierProvider.notifier)
                        .restart(),
                  ),
                ],
              ),
              const Gap(12),
              ArenaToggle(
                label: 'AUTO-START ON LAUNCH',
                value: s.autoStartLiteLLM,
                onChanged: (v) => _update(s.copyWith(autoStartLiteLLM: v)),
              ),
              const Gap(8),
              ArenaTextField(
                label: 'LITELLM URL',
                hint: 'http://localhost:4000',
                controller: _liteLLMUrlController,
                onSubmitted: (v) => _update(s.copyWith(liteLLMUrl: v)),
              ),
              const Gap(8),
              _SliderRow(
                label: 'PORT',
                value: s.liteLLMPort.toDouble(),
                min: 1024,
                max: 65535,
                displayValue: '${s.liteLLMPort}',
                onChanged: (v) => _update(s.copyWith(liteLLMPort: v.round())),
              ),
            ],
          ),
        ),
        const Gap(16),

        // LiteLLM config editor
        ArenaSection(
          title: 'LITELLM CONFIG (YAML)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ArenaTheme.surface,
                  border: Border.all(color: ArenaTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _configYamlController,
                  maxLines: 16,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        color: ArenaTheme.accentGreen,
                      ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loadConfig,
                      child: const Text('LOAD FROM DISK'),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      child: const Text('SAVE & APPLY'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(16),

        // Relay
        ArenaSection(
          title: 'RELAY SERVER',
          child: Column(
            children: [
              ArenaTextField(
                label: 'RELAY URL',
                hint: 'ws://localhost:8080',
                controller: _relayUrlController,
                onSubmitted: (v) => _update(s.copyWith(relayUrl: v)),
              ),
              const Gap(8),
              ArenaTextField(
                label: 'AUTH TOKEN',
                hint: 'Optional — leave empty for no auth',
                controller: _relayTokenController,
                obscureText: true,
                onSubmitted: (v) => _update(s.copyWith(relayAuthToken: v)),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(relayConnectionNotifierProvider.notifier)
                          .connect(),
                      child: const Text('CONNECT'),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(relayConnectionNotifierProvider.notifier)
                          .disconnect(),
                      child: const Text('DISCONNECT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(16),

        // Dangerous internal overrides
        ArenaSection(
          title: 'INTERNAL OVERRIDES',
          titleColor: ArenaTheme.accent,
          child: Column(
            children: [
              ArenaToggle(
                label: 'ALLOW MID-MATCH MODEL SWAP',
                subtitle: 'Swap a fighter\'s model while battle is running',
                value: s.allowMidMatchModelSwap,
                onChanged: (v) =>
                    _update(s.copyWith(allowMidMatchModelSwap: v)),
              ),
              ArenaToggle(
                label: 'ALLOW STATE OVERRIDE',
                subtitle: 'Directly edit battle state mid-match',
                value: s.allowStateOverride,
                onChanged: (v) => _update(s.copyWith(allowStateOverride: v)),
              ),
              ArenaToggle(
                label: 'ALLOW SCORE OVERRIDE',
                subtitle: 'Manually set scores for any round',
                value: s.allowScoreOverride,
                onChanged: (v) => _update(s.copyWith(allowScoreOverride: v)),
              ),
              ArenaToggle(
                label: 'ALLOW PROMPT INJECTION',
                subtitle:
                    'Inject arbitrary text into the next round\'s prompt',
                value: s.allowPromptInjection,
                onChanged: (v) =>
                    _update(s.copyWith(allowPromptInjection: v)),
              ),
            ],
          ),
        ),
        const Gap(32),
      ],
    );
  }

  Future<void> _loadConfig() async {
    try {
      final yaml = await LiteLLMService.instance.readConfig();
      _configYamlController.text = yaml;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  Future<void> _saveConfig() async {
    try {
      final yaml = _configYamlController.text;
      await LiteLLMService.instance.writeConfig(yaml);
      _update(widget.settings.copyWith(liteLLMConfigYaml: yaml));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Config saved. Restart LiteLLM to apply.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }
}

// ─── Shared Sub-Widgets ───────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ArenaTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            displayValue,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ArenaTheme.accentBlue,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status, required this.label});
  final bool status;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status ? ArenaTheme.accentGreen : ArenaTheme.accent,
            boxShadow: [
              BoxShadow(
                color: (status ? ArenaTheme.accentGreen : ArenaTheme.accent)
                    .withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const Gap(8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
