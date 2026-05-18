import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/providers.dart';
import '../../core/models/models.dart';
import '../../core/services/relay_service.dart';
import '../../core/utils/utils.dart';
import '../../shared/extensions/extensions.dart';
import '../../shared/theme/arena_theme.dart';
import '../../shared/widgets/arena_section.dart';
import '../../shared/widgets/arena_text_field.dart';
import '../battle/modes/battle_mode_config.dart';
import '../battle/widgets/battle_widgets.dart';

const _uuid = Uuid();

enum LobbyMode { create, join }

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.mode, this.lobbyId});
  final LobbyMode mode;
  final String? lobbyId;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  // Fighter state — mutable directly
  late FighterConfig _fighterA;
  late FighterConfig _fighterB;

  final _promptCtrl = TextEditingController();
  final _lobbyCodeCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController(text: 'Player');

  bool _multiplayerMode = false;
  bool _starting = false;
  String? _createdLobbyId;

  late AnimationController _headerCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: 600.ms);
    _headerCtrl.forward();

    if (widget.lobbyId != null) _lobbyCodeCtrl.text = widget.lobbyId!;

    _fighterA = FighterConfig.create(
      name: 'Fighter A',
      modelId: '',
      side: FighterSide.a,
    );
    _fighterB = FighterConfig.create(
      name: 'Fighter B',
      modelId: '',
      side: FighterSide.b,
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _lobbyCodeCtrl.dispose();
    _displayNameCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
    final battleSettings = settings?.battle ?? const BattleSettings();
    final isWide = context.isWide;

    return Scaffold(
      backgroundColor: ArenaTheme.background,
      appBar: _buildAppBar(context),
      body: widget.mode == LobbyMode.join
          ? _buildJoinBody(context)
          : _buildCreateBody(context, battleSettings, isWide),
    );
  }

  // ─── App bar ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        widget.mode == LobbyMode.create ? 'NEW BATTLE' : 'JOIN MATCH',
      ),
      bottom: widget.mode == LobbyMode.create
          ? PreferredSize(
              preferredSize: const Size.fromHeight(36),
              child: _ModeToggle(
                multiplayerMode: _multiplayerMode,
                onChanged: (v) => setState(() => _multiplayerMode = v),
              ),
            )
          : null,
    );
  }

  // ─── Create body ─────────────────────────────────────────────────────────

  Widget _buildCreateBody(
      BuildContext context, BattleSettings battleSettings, bool isWide) {
    final modeConfig = BattleModes.forType(battleSettings.battleType);

    return isWide
        ? _buildWideCreate(context, battleSettings, modeConfig)
        : _buildNarrowCreate(context, battleSettings, modeConfig);
  }

  Widget _buildWideCreate(
    BuildContext context,
    BattleSettings battleSettings,
    BattleModeConfig modeConfig,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — fighters + prompt
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildFighterRow(battleSettings),
              const Gap(16),
              PromptInputCard(
                controller: _promptCtrl,
                battleType: battleSettings.battleType,
              ).animate().fadeIn(delay: 200.ms),
              if (_multiplayerMode) ...[
                const Gap(16),
                _buildPlayerNameField(),
              ],
              const Gap(24),
              _buildLaunchButton(context, battleSettings),
              if (_createdLobbyId != null) ...[
                const Gap(16),
                _LobbyCodeCard(lobbyId: _createdLobbyId!),
              ],
              const Gap(32),
            ],
          ),
        ),
        // Right column — settings summary
        SizedBox(
          width: 300,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: ArenaTheme.surfaceBorder)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'MATCH CONFIG',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ArenaTheme.textMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                ),
                const Gap(12),
                SettingsSummaryChips(settings: battleSettings),
                const Gap(16),
                _ModeInfoCard(config: modeConfig),
                const Gap(16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('EDIT SETTINGS'),
                  onPressed: () => context.push('/settings/game'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowCreate(
    BuildContext context,
    BattleSettings battleSettings,
    BattleModeConfig modeConfig,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFighterRow(battleSettings),
        const Gap(12),
        PromptInputCard(
          controller: _promptCtrl,
          battleType: battleSettings.battleType,
        ).animate().fadeIn(delay: 150.ms),
        const Gap(12),
        SettingsSummaryChips(settings: battleSettings)
            .animate()
            .fadeIn(delay: 200.ms),
        const Gap(4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.tune_rounded, size: 12),
            label: const Text('Edit settings'),
            style: TextButton.styleFrom(
              foregroundColor: ArenaTheme.textMuted,
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: () => context.push('/settings/game'),
          ),
        ),
        if (_multiplayerMode) ...[
          const Gap(8),
          _buildPlayerNameField(),
        ],
        const Gap(16),
        _buildLaunchButton(context, battleSettings),
        if (_createdLobbyId != null) ...[
          const Gap(12),
          _LobbyCodeCard(lobbyId: _createdLobbyId!),
        ],
        const Gap(32),
      ],
    );
  }

  Widget _buildFighterRow(BattleSettings settings) {
    final isWide = context.isWide;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FighterCard(
              side: FighterSide.a,
              config: _fighterA,
              onChanged: (c) => setState(() => _fighterA = c),
            ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.03),
          ),
          const Gap(12),
          _VsDivider(),
          const Gap(12),
          Expanded(
            child: FighterCard(
              side: FighterSide.b,
              config: _fighterB,
              onChanged: (c) => setState(() => _fighterB = c),
            ).animate().fadeIn(delay: 120.ms).slideX(begin: 0.03),
          ),
        ],
      );
    }

    return Column(
      children: [
        FighterCard(
          side: FighterSide.a,
          config: _fighterA,
          onChanged: (c) => setState(() => _fighterA = c),
        ).animate().fadeIn(delay: 80.ms),
        const Gap(8),
        Center(
          child: Text(
            'VS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: ArenaTheme.textMuted,
                  fontSize: 16,
                ),
          ),
        ),
        const Gap(8),
        FighterCard(
          side: FighterSide.b,
          config: _fighterB,
          onChanged: (c) => setState(() => _fighterB = c),
        ).animate().fadeIn(delay: 120.ms),
      ],
    );
  }

  Widget _buildPlayerNameField() {
    return ArenaSection(
      title: 'YOUR DISPLAY NAME',
      child: ArenaTextField(
        label: 'NAME',
        hint: 'How you appear to other players',
        controller: _displayNameCtrl,
      ),
    ).animate().fadeIn();
  }

  Widget _buildLaunchButton(BuildContext context, BattleSettings settings) {
    final canLaunch =
        _fighterA.modelId.isNotEmpty && _fighterB.modelId.isNotEmpty;

    return AnimatedOpacity(
      duration: 200.ms,
      opacity: canLaunch ? 1.0 : 0.5,
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          icon: _starting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.flash_on_rounded, size: 18),
          label: Text(
            _starting
                ? 'STARTING...'
                : _multiplayerMode
                    ? 'CREATE LOBBY'
                    : 'LAUNCH BATTLE',
          ),
          onPressed: _starting || !canLaunch ? null : _launch,
        ),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ─── Join body ────────────────────────────────────────────────────────────

  Widget _buildJoinBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaSection(
            title: 'LOBBY CODE OR URL',
            child: Column(
              children: [
                ArenaTextField(
                  label: 'CODE / URL',
                  hint: 'Paste lobby code or share URL...',
                  controller: _lobbyCodeCtrl,
                ),
                const Gap(10),
                ArenaTextField(
                  label: 'YOUR DISPLAY NAME',
                  hint: 'How you appear to other players',
                  controller: _displayNameCtrl,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
          const Gap(24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _starting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded, size: 18),
              label: Text(_starting ? 'JOINING...' : 'JOIN LOBBY'),
              onPressed: _starting ? null : _join,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _launch() async {
    final prompt = _promptCtrl.text.trim();
    final nameError = Validators.displayName(_displayNameCtrl.text);

    if (_fighterA.modelId.isEmpty || _fighterB.modelId.isEmpty) {
      context.showSnack('Both fighters need a model ID.', isError: true);
      return;
    }
    if (prompt.isEmpty) {
      context.showSnack('Enter a battle prompt.', isError: true);
      return;
    }

    setState(() => _starting = true);
    try {
      final settings = await ref.read(appSettingsNotifierProvider.future);

      // Wire model config defaults from BattleModes
      final modeConfig = BattleModes.forType(settings.battle.battleType);
      final aWithDefaults = _fighterA.systemPrompt.isEmpty
          ? _fighterA.copyWith(systemPrompt: modeConfig.systemPromptA)
          : _fighterA;
      final bWithDefaults = _fighterB.systemPrompt.isEmpty
          ? _fighterB.copyWith(systemPrompt: modeConfig.systemPromptB)
          : _fighterB;

      final finalA = aWithDefaults.copyWith(
          endpointUrl: settings.internal.liteLLMUrl);
      final finalB = bWithDefaults.copyWith(
          endpointUrl: settings.internal.liteLLMUrl);

      ref.read(activeBattleNotifierProvider.notifier).createBattle(
            settings: settings.battle,
            fighterA: finalA,
            fighterB: finalB,
          );

      if (_multiplayerMode) {
        final lobbyId = await RelayService.instance.createLobby(
          displayName: _displayNameCtrl.text.trim(),
          settings: settings.battle,
        );
        if (mounted) setState(() => _createdLobbyId = lobbyId);
        return; // show lobby code card before navigating
      }

      if (mounted) {
        final battleId =
            ref.read(activeBattleNotifierProvider)?.id ?? _uuid.v4();
        context.push('/battle/$battleId');

        await Future.delayed(400.ms);
        await ref
            .read(activeBattleNotifierProvider.notifier)
            .start(prompt);
      }
    } catch (e) {
      if (mounted) context.showSnack('Failed to start: $e', isError: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _join() async {
    final code = _lobbyCodeCtrl.text.trim();
    if (code.isEmpty) {
      context.showSnack('Enter a lobby code.', isError: true);
      return;
    }

    setState(() => _starting = true);
    try {
      final lobbyId = LobbyCodeUtil.extractId(code);
      await RelayService.instance.joinLobby(
        lobbyId,
        displayName: _displayNameCtrl.text.trim(),
        requestedRole: LobbyRole.spectator,
      );
      if (mounted) context.push('/battle/$lobbyId');
    } catch (e) {
      if (mounted) context.showSnack('Failed to join: $e', isError: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.multiplayerMode,
    required this.onChanged,
  });

  final bool multiplayerMode;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ArenaTheme.surfaceBorder)),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'LOCAL',
            icon: Icons.computer_rounded,
            selected: !multiplayerMode,
            onTap: () => onChanged(false),
          ),
          _Tab(
            label: 'MULTIPLAYER',
            icon: Icons.wifi_rounded,
            selected: multiplayerMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? ArenaTheme.accentBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? ArenaTheme.accentBlue : ArenaTheme.textMuted,
            ),
            const Gap(6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    color: selected
                        ? ArenaTheme.accentBlue
                        : ArenaTheme.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 1, height: 40, color: ArenaTheme.surfaceBorder),
        const Gap(8),
        Text(
          'VS',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ArenaTheme.textMuted,
                fontSize: 14,
              ),
        ),
        const Gap(8),
        Container(width: 1, height: 40, color: ArenaTheme.surfaceBorder),
      ],
    );
  }
}

class _ModeInfoCard extends StatelessWidget {
  const _ModeInfoCard({required this.config});
  final BattleModeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArenaTheme.surface,
        border: Border.all(color: ArenaTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: ArenaTheme.textMuted),
              const Gap(6),
              Text(
                config.displayName.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 10,
                      color: ArenaTheme.textSecondary,
                    ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            config.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  height: 1.6,
                ),
          ),
          const Gap(8),
          Row(
            children: [
              _InfoChip(
                  label:
                      '${config.defaultRounds} rounds default'),
              const Gap(6),
              if (config.supportsJudge)
                const _InfoChip(label: 'Judge ✓'),
              if (config.requiresAgents) ...[
                const Gap(6),
                const _InfoChip(label: 'Agents', color: ArenaTheme.accentGreen),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.color = ArenaTheme.textMuted,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        color: color.withOpacity(0.06),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 9,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LobbyCodeCard extends StatelessWidget {
  const _LobbyCodeCard({required this.lobbyId});
  final String lobbyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArenaTheme.accentGreen.withOpacity(0.06),
        border: Border.all(color: ArenaTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: ArenaTheme.accentGreen, size: 14),
              const Gap(6),
              Text(
                'LOBBY CREATED',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: ArenaTheme.accentGreen,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            'Share this code with others:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(8),

          // Code display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: ArenaTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    lobbyId,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: ArenaTheme.accentGreen,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  color: ArenaTheme.accentGreen,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lobbyId));
                    context.showSnack('Lobby code copied!');
                  },
                ),
              ],
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('ENTER LOBBY'),
              onPressed: () => context.push('/battle/$lobbyId'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }
}
