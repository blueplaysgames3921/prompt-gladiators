import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../core/services/relay_service.dart';
import '../../shared/theme/arena_theme.dart';
import '../../shared/extensions/extensions.dart';

/// Overlay panel for Commanders to control a fighter's system prompt live.
/// Shown as a side panel inside the battle screen when role == commander.
class CommanderPanel extends ConsumerStatefulWidget {
  const CommanderPanel({
    super.key,
    required this.commandingSide,
    required this.currentSystemPrompt,
    required this.onSystemPromptChanged,
  });

  final FighterSide commandingSide;
  final String currentSystemPrompt;
  final void Function(String) onSystemPromptChanged;

  @override
  ConsumerState<CommanderPanel> createState() => _CommanderPanelState();
}

class _CommanderPanelState extends ConsumerState<CommanderPanel> {
  late TextEditingController _promptCtrl;
  bool _isDirty = false;
  String? _lastSent;

  Color get _color => widget.commandingSide == FighterSide.a
      ? ArenaTheme.fighterA
      : ArenaTheme.fighterB;

  String get _sideLabel =>
      widget.commandingSide == FighterSide.a ? 'FIGHTER A' : 'FIGHTER B';

  @override
  void initState() {
    super.initState();
    _promptCtrl = TextEditingController(text: widget.currentSystemPrompt);
    _lastSent = widget.currentSystemPrompt;
  }

  @override
  void didUpdateWidget(CommanderPanel old) {
    super.didUpdateWidget(old);
    if (old.currentSystemPrompt != widget.currentSystemPrompt &&
        !_isDirty) {
      _promptCtrl.text = widget.currentSystemPrompt;
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _promptCtrl.text.trim();
    if (text == _lastSent) return;

    widget.onSystemPromptChanged(text);
    RelayService.instance.updateSystemPrompt(widget.commandingSide, text);

    setState(() {
      _isDirty = false;
      _lastSent = text;
    });

    context.showSnack('System prompt updated for $_sideLabel');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: ArenaTheme.surface,
        border: Border(
          left: BorderSide(color: _color.withOpacity(0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ArenaTheme.surfaceElevated,
              border: Border(
                  bottom: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, color: _color),
                const Gap(8),
                Text(
                  'COMMANDER — $_sideLabel',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _color,
                        fontSize: 10,
                      ),
                ),
                const Spacer(),
                if (_isDirty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    color: ArenaTheme.accentGold.withOpacity(0.15),
                    child: Text(
                      'UNSAVED',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ArenaTheme.accentGold,
                            fontSize: 8,
                            letterSpacing: 1.5,
                          ),
                    ),
                  ),
              ],
            ),
          ),

          // ── System prompt editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM PROMPT',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: ArenaTheme.textMuted,
                        ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: ArenaTheme.background,
                        border: Border.all(
                          color: _isDirty
                              ? _color.withOpacity(0.5)
                              : ArenaTheme.surfaceBorder,
                        ),
                      ),
                      child: TextField(
                        controller: _promptCtrl,
                        maxLines: null,
                        expands: true,
                        onChanged: (v) {
                          setState(() => _isDirty = v.trim() != _lastSent);
                        },
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontFamily: 'SpaceMono',
                              fontSize: 11,
                              height: 1.6,
                              color: _color.withOpacity(0.9),
                            ),
                        decoration: InputDecoration(
                          hintText: 'Enter your fighter\'s persona and strategy...',
                          hintStyle:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ArenaTheme.textMuted,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 11,
                                  ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                  const Gap(10),

                  // ── Quick strategy chips
                  Text(
                    'QUICK STRATEGIES',
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
                    children: _strategies
                        .map((s) => _StrategyChip(
                              label: s.label,
                              color: _color,
                              onTap: () {
                                _promptCtrl.text = s.prompt;
                                setState(() => _isDirty =
                                    s.prompt.trim() != _lastSent);
                              },
                            ))
                        .toList(),
                  ),
                  const Gap(12),

                  // ── Send button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: Text(_isDirty ? 'SEND UPDATE' : 'DEPLOYED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDirty ? _color : ArenaTheme.surfaceElevated,
                        foregroundColor: _isDirty
                            ? Colors.white
                            : ArenaTheme.textMuted,
                      ),
                      onPressed: _isDirty ? _send : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── History strip
          if (_lastSent != null && _lastSent!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: ArenaTheme.surfaceBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAST DEPLOYED',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 8,
                          letterSpacing: 2,
                          color: ArenaTheme.textMuted,
                        ),
                  ),
                  const Gap(4),
                  Text(
                    _lastSent!.truncate(80),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          color: ArenaTheme.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.05);
  }
}

// ─── Strategy presets ─────────────────────────────────────────────────────────

class _Strategy {
  const _Strategy({required this.label, required this.prompt});
  final String label;
  final String prompt;
}

const _strategies = [
  _Strategy(
    label: 'AGGRESSIVE',
    prompt:
        'Be extremely direct and assertive. Challenge every weak point in your opponent\'s argument. Go for the jugular — no mercy.',
  ),
  _Strategy(
    label: 'SOCRATIC',
    prompt:
        'Ask probing questions that expose contradictions in your opponent\'s reasoning. Let them defeat themselves.',
  ),
  _Strategy(
    label: 'ACADEMIC',
    prompt:
        'Cite evidence, data, and historical precedent. Be rigorous, measured, and authoritative. Win on the facts.',
  ),
  _Strategy(
    label: 'HUMOROUS',
    prompt:
        'Use wit, satire, and well-placed humor to make your points land harder. Be clever, not cruel.',
  ),
  _Strategy(
    label: 'STEELMAN',
    prompt:
        'Acknowledge the strongest version of your opponent\'s argument, then systematically dismantle it with even stronger counter-evidence.',
  ),
  _Strategy(
    label: 'CONTRARIAN',
    prompt:
        'Take the most provocative defensible position. Reject conventional wisdom and make people think twice.',
  ),
];

class _StrategyChip extends StatelessWidget {
  const _StrategyChip({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 9,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
