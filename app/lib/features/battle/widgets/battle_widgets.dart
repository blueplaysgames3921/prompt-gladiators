import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/config/providers.dart';
import '../../../core/models/models.dart';
import '../../../shared/theme/arena_theme.dart';
import '../../../shared/widgets/arena_text_field.dart';

// ─── Model Selector ───────────────────────────────────────────────────────────

/// Dropdown + free-text field for picking a model from available LiteLLM models.
/// Falls back gracefully if LiteLLM is offline.
class ModelSelector extends ConsumerStatefulWidget {
  const ModelSelector({
    super.key,
    required this.label,
    required this.accentColor,
    this.initialValue = '',
    this.onChanged,
  });

  final String label;
  final Color accentColor;
  final String initialValue;
  final void Function(String modelId)? onChanged;

  @override
  ConsumerState<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends ConsumerState<ModelSelector> {
  late TextEditingController _ctrl;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(availableModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input row
        Row(
          children: [
            Expanded(
              child: ArenaTextField(
                label: widget.label,
                hint: 'e.g. gpt-4o, gemini-2.0-flash',
                controller: _ctrl,
                onChanged: (v) => widget.onChanged?.call(v),
              ),
            ),
            const Gap(8),
            // Dropdown toggle
            modelsAsync.when(
              loading: () => const SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ArenaTheme.textMuted,
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (models) => models.isEmpty
                  ? const SizedBox.shrink()
                  : AnimatedContainer(
                      duration: 150.ms,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showDropdown
                            ? widget.accentColor.withOpacity(0.15)
                            : ArenaTheme.surfaceElevated,
                        border: Border.all(
                          color: _showDropdown
                              ? widget.accentColor.withOpacity(0.5)
                              : ArenaTheme.surfaceBorder,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _showDropdown
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: _showDropdown
                              ? widget.accentColor
                              : ArenaTheme.textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _showDropdown = !_showDropdown),
                      ),
                    ),
            ),
          ],
        ),

        // Dropdown list
        modelsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (models) => AnimatedSize(
            duration: 200.ms,
            curve: Curves.easeOut,
            child: _showDropdown && models.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: ArenaTheme.surface,
                      border: Border.all(color: ArenaTheme.surfaceBorder),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: models.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: ArenaTheme.surfaceBorder,
                      ),
                      itemBuilder: (context, i) {
                        final model = models[i];
                        final isSelected = _ctrl.text == model;
                        return InkWell(
                          onTap: () {
                            _ctrl.text = model;
                            widget.onChanged?.call(model);
                            setState(() => _showDropdown = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? widget.accentColor.withOpacity(0.08)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: widget.accentColor,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    model,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontFamily: 'SpaceMono',
                                          fontSize: 11,
                                          color: isSelected
                                              ? widget.accentColor
                                              : ArenaTheme.textPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ─── Fighter Card ─────────────────────────────────────────────────────────────

/// Full fighter configuration card used in lobby setup.
class FighterCard extends StatefulWidget {
  const FighterCard({
    super.key,
    required this.side,
    required this.config,
    required this.onChanged,
  });

  final FighterSide side;
  final FighterConfig config;
  final void Function(FighterConfig updated) onChanged;

  @override
  State<FighterCard> createState() => _FighterCardState();
}

class _FighterCardState extends State<FighterCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sysPromptCtrl;
  bool _sysPromptExpanded = false;

  Color get _color =>
      widget.side == FighterSide.a ? ArenaTheme.fighterA : ArenaTheme.fighterB;

  String get _sideLabel =>
      widget.side == FighterSide.a ? 'FIGHTER A' : 'FIGHTER B';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.config.name);
    _sysPromptCtrl = TextEditingController(text: widget.config.systemPrompt);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sysPromptCtrl.dispose();
    super.dispose();
  }

  void _update({
    String? name,
    String? modelId,
    String? systemPrompt,
    int? agentCount,
    List<AgentTool>? allowedTools,
  }) {
    widget.onChanged(widget.config.copyWith(
      name: name ?? widget.config.name,
      modelId: modelId ?? widget.config.modelId,
      systemPrompt: systemPrompt ?? widget.config.systemPrompt,
      agentCount: agentCount ?? widget.config.agentCount,
      allowedTools: allowedTools ?? widget.config.allowedTools,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArenaTheme.surfaceElevated,
        border: Border(
          left: BorderSide(color: _color, width: 3),
          top: const BorderSide(color: ArenaTheme.surfaceBorder),
          right: const BorderSide(color: ArenaTheme.surfaceBorder),
          bottom: const BorderSide(color: ArenaTheme.surfaceBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: ArenaTheme.surface,
              border: Border(
                  bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: _color,
                ),
                const Gap(8),
                Text(
                  _sideLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _color,
                        fontSize: 11,
                      ),
                ),
                if (widget.config.modelId.isNotEmpty) ...[
                  const Gap(10),
                  Expanded(
                    child: Text(
                      widget.config.modelId,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            color: ArenaTheme.textMuted,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Name + model side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    SizedBox(
                      width: 130,
                      child: ArenaTextField(
                        label: 'NAME',
                        hint: _sideLabel,
                        controller: _nameCtrl,
                        onChanged: (v) => _update(name: v),
                      ),
                    ),
                    const Gap(10),
                    // Model selector
                    Expanded(
                      child: ModelSelector(
                        label: 'MODEL ID',
                        accentColor: _color,
                        initialValue: widget.config.modelId,
                        onChanged: (v) => _update(modelId: v),
                      ),
                    ),
                  ],
                ),
                const Gap(10),

                // System prompt toggle
                InkWell(
                  onTap: () =>
                      setState(() => _sysPromptExpanded = !_sysPromptExpanded),
                  borderRadius: BorderRadius.circular(2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 13,
                          color: _sysPromptExpanded
                              ? _color
                              : ArenaTheme.textMuted,
                        ),
                        const Gap(6),
                        Text(
                          'SYSTEM PROMPT',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: _sysPromptExpanded
                                    ? _color
                                    : ArenaTheme.textMuted,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                        ),
                        if (widget.config.systemPrompt.isNotEmpty) ...[
                          const Gap(6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _color,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          _sysPromptExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 14,
                          color: ArenaTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: 200.ms,
                  curve: Curves.easeOut,
                  child: _sysPromptExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ArenaTextField(
                            label: 'SYSTEM PROMPT',
                            hint: 'How should this fighter behave? Leave blank for default.',
                            controller: _sysPromptCtrl,
                            maxLines: 4,
                            onChanged: (v) => _update(systemPrompt: v),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Prompt Input Card ────────────────────────────────────────────────────────

/// The opening battle prompt input with suggestions.
class PromptInputCard extends StatefulWidget {
  const PromptInputCard({
    super.key,
    required this.controller,
    required this.battleType,
    this.onChanged,
  });

  final TextEditingController controller;
  final BattleType battleType;
  final void Function(String)? onChanged;

  @override
  State<PromptInputCard> createState() => _PromptInputCardState();
}

class _PromptInputCardState extends State<PromptInputCard> {
  static const _suggestions = {
    BattleType.classic: [
      'Which programming language is best for beginners?',
      'Explain quantum entanglement to a 10-year-old.',
      'Write a haiku about artificial intelligence.',
      'Is remote work better than office work?',
      'What will transport look like in 2050?',
    ],
    BattleType.battlefield: [
      'Argue for or against universal basic income.',
      'Is open source software better than proprietary?',
      'Nuclear energy: necessary or too risky?',
      'Should social media be regulated by governments?',
      'Is mathematics discovered or invented?',
    ],
    BattleType.agenticSwarm: [
      'Research and summarise the latest breakthroughs in fusion energy.',
      'Write and test a Python implementation of A* pathfinding.',
      'Compare the top 5 LLMs on reasoning benchmarks as of this year.',
      'Find the 3 most underrated sci-fi novels of the last decade.',
      'Design a REST API for a real-time collaborative editor.',
    ],
    BattleType.tournament: [
      'Explain the trolley problem and your view on it.',
      'Prove or disprove: consciousness is substrate-independent.',
      'Write the most compelling one-paragraph pitch for a startup idea.',
    ],
    BattleType.commander: [
      'Debate the merits of stoicism vs. existentialism.',
      'Argue your case: cats vs. dogs.',
      'Which came first, the chicken or the egg?',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final suggestions =
        _suggestions[widget.battleType] ?? _suggestions[BattleType.classic]!;

    return Container(
      decoration: BoxDecoration(
        color: ArenaTheme.surfaceElevated,
        border: Border.all(color: ArenaTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: ArenaTheme.surface,
              border: Border(
                  bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    size: 14, color: ArenaTheme.accentBlue),
                const Gap(8),
                Text(
                  'BATTLE PROMPT',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ArenaTheme.accentBlue,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main input
                TextField(
                  controller: widget.controller,
                  maxLines: 4,
                  onChanged: widget.onChanged,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        height: 1.6,
                      ),
                  decoration: InputDecoration(
                    hintText: _hintFor(widget.battleType),
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArenaTheme.textMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const Gap(12),

                // Suggestions
                Text(
                  'SUGGESTIONS',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: ArenaTheme.textMuted,
                      ),
                ),
                const Gap(6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: suggestions.map((s) {
                    return InkWell(
                      onTap: () {
                        widget.controller.text = s;
                        widget.onChanged?.call(s);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ArenaTheme.accentBlue.withOpacity(0.07),
                          border: Border.all(
                              color: ArenaTheme.accentBlue.withOpacity(0.2)),
                        ),
                        child: Text(
                          s,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 10,
                                color: ArenaTheme.accentBlue,
                              ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hintFor(BattleType type) => switch (type) {
        BattleType.classic =>
          'Enter a question, topic, or task for both models...',
        BattleType.battlefield =>
          'Enter a debate topic. Models will argue back and forth...',
        BattleType.agenticSwarm =>
          'Enter a complex task. Each team of agents will tackle it...',
        BattleType.tournament =>
          'Enter the prompt all tournament models will face...',
        BattleType.commander =>
          'Enter the base prompt. Commanders will direct their model\'s strategy...',
      };
}

// ─── Settings Summary Chip Row ─────────────────────────────────────────────────

class SettingsSummaryChips extends StatelessWidget {
  const SettingsSummaryChips({super.key, required this.settings});
  final BattleSettings settings;

  @override
  Widget build(BuildContext context) {
    final chips = <_ChipData>[
      _ChipData(
          label: settings.battleType.name.toUpperCase(),
          color: ArenaTheme.accent),
      _ChipData(
          label: '${settings.roundCount} ROUNDS',
          color: ArenaTheme.textSecondary),
      if (settings.judgeEnabled)
        _ChipData(label: 'JUDGE', color: ArenaTheme.accentGold),
      if (settings.votingEnabled)
        _ChipData(label: 'VOTING', color: ArenaTheme.accentBlue),
      if (settings.scoreboardEnabled)
        _ChipData(label: 'SCOREBOARD', color: ArenaTheme.accentGreen),
      if (settings.apocalypseMode)
        _ChipData(label: '🔥 APOCALYPSE', color: ArenaTheme.accent),
      if (settings.agentsPerSide > 1)
        _ChipData(
            label: '${settings.agentsPerSide}× AGENTS',
            color: ArenaTheme.accentGreen),
      if (settings.blindMode)
        _ChipData(label: 'BLIND', color: ArenaTheme.accentGold),
      if (settings.multiplayerEnabled)
        _ChipData(
            label: settings.rankedMatch ? 'RANKED' : 'UNRANKED',
            color: ArenaTheme.accentBlue),
      if (settings.audienceControlsEnabled)
        _ChipData(label: 'AUDIENCE CTL', color: ArenaTheme.textSecondary),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaTheme.surface,
        border: Border.all(color: ArenaTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 11, color: ArenaTheme.textMuted),
              const Gap(6),
              Text(
                'MATCH CONFIG',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: ArenaTheme.textMuted,
                    ),
              ),
            ],
          ),
          const Gap(8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips
                .map((c) => _Chip(label: c.label, color: c.color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChipData {
  const _ChipData({required this.label, required this.color});
  final String label;
  final Color color;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Countdown Overlay ────────────────────────────────────────────────────────

class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 800.ms);
    _scale = Tween<double>(begin: 1.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _tick();
  }

  void _tick() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _count = i);
      _ctrl.forward(from: 0);
      await Future.delayed(900.ms);
    }
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Text(
          '$_count',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 120,
                color: ArenaTheme.accent,
                fontFamily: 'SpaceMono',
              ),
        ),
      ),
    );
  }
}
