import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/providers.dart';
import '../../core/services/litellm_service.dart';
import '../../core/services/relay_service.dart';
import '../../shared/theme/arena_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      body: Stack(
        children: [
          const _GridBackground(),
          const _ScanlineOverlay(),
          SafeArea(
            child: isWide ? _WideLayout() : _NarrowLayout(),
          ),
        ],
      ),
    );
  }
}

// ─── Wide Layout (desktop) ────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 380, child: _BrandingPanel()),
        Container(
          width: 1,
          color: ArenaTheme.surfaceBorder,
          margin: const EdgeInsets.symmetric(vertical: 40),
        ),
        Expanded(child: _MenuPanel()),
      ],
    );
  }
}

// ─── Narrow Layout (mobile) ───────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactHeader(),
        Expanded(child: _MenuPanel()),
        _StatusFooter(),
      ],
    );
  }
}

// ─── Branding Panel ───────────────────────────────────────────────────────────

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoMark()
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8)),

          const Gap(44),

          // Stacked title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROMPT',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: ArenaTheme.accent,
                      fontSize: 72,
                      height: 0.85,
                    ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
              Text(
                'GLADIATORS',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 52,
                      height: 0.95,
                    ),
              ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15),
            ],
          ),

          const Gap(28),

          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: ArenaTheme.accent, width: 2)),
            ),
            child: Text(
              'PIT MODELS AGAINST EACH OTHER.\nLET THE BEST MIND WIN.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ArenaTheme.textSecondary,
                    letterSpacing: 1.2,
                    height: 1.9,
                  ),
            ),
          ).animate().fadeIn(delay: 500.ms),

          const Spacer(),

          _StatusFooter(),
        ],
      ),
    );
  }
}

// ─── Compact Header (narrow) ──────────────────────────────────────────────────

class _CompactHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoMark(size: 36)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.7, 0.7)),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROMPT GLADIATORS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            letterSpacing: 2.5,
                            fontSize: 18,
                          ),
                    ),
                    Text(
                      'PIT MODELS AGAINST EACH OTHER',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: ArenaTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.04),
          const Gap(20),
          const Divider(thickness: 1),
        ],
      ),
    );
  }
}

// ─── Menu Panel ───────────────────────────────────────────────────────────────

class _MenuPanel extends StatelessWidget {
  static const _items = [
    _MenuItemData(
      label: 'NEW BATTLE',
      sublabel: 'Create a local or multiplayer match',
      icon: Icons.flash_on_rounded,
      color: ArenaTheme.accent,
      route: '/lobby/new',
      shortcut: '⌘N',
    ),
    _MenuItemData(
      label: 'JOIN MATCH',
      sublabel: 'Enter a lobby code or URL to join',
      icon: Icons.link_rounded,
      color: ArenaTheme.accentBlue,
      route: '/lobby/join',
      shortcut: '⌘J',
    ),
    _MenuItemData(
      label: 'TOURNAMENT',
      sublabel: 'Bracket system with ELO rankings',
      icon: Icons.emoji_events_rounded,
      color: ArenaTheme.accentGold,
      route: '/tournament',
      shortcut: '⌘T',
    ),
    _MenuItemData(
      label: 'SETTINGS',
      sublabel: 'Game, debug, and internal configuration',
      icon: Icons.tune_rounded,
      color: ArenaTheme.textSecondary,
      route: '/settings',
      shortcut: '⌘,',
    ),
    _MenuItemData(
      label: 'DEBUG CONSOLE',
      sublabel: 'Events, payloads, LiteLLM status',
      icon: Icons.terminal_rounded,
      color: ArenaTheme.accentGreen,
      route: '/debug',
      shortcut: '⌘D',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 24,
        vertical: isWide ? 60 : 20,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _MenuItem(data: _items[i], index: i),
    );
  }
}

// ─── Menu Item ────────────────────────────────────────────────────────────────

class _MenuItemData {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final String route;
  final String shortcut;

  const _MenuItemData({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.route,
    required this.shortcut,
  });
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({required this.data, required this.index});
  final _MenuItemData data;
  final int index;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          context.push(d.route);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          transform: Matrix4.identity()
            ..scale(_pressed ? 0.995 : 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? d.color.withOpacity(0.06)
                : ArenaTheme.surface,
            border: Border(
              left: BorderSide(
                color: _hovered ? d.color : Colors.transparent,
                width: 3,
              ),
              top: const BorderSide(color: ArenaTheme.surfaceBorder),
              bottom: const BorderSide(color: ArenaTheme.surfaceBorder),
              right: const BorderSide(color: ArenaTheme.surfaceBorder),
            ),
          ),
          child: Row(
            children: [
              // Icon box
              AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _hovered
                      ? d.color.withOpacity(0.14)
                      : ArenaTheme.surfaceElevated,
                  border: Border.all(
                    color: _hovered
                        ? d.color.withOpacity(0.4)
                        : ArenaTheme.surfaceBorder,
                  ),
                ),
                child: Icon(
                  d.icon,
                  color: _hovered ? d.color : ArenaTheme.textSecondary,
                  size: 18,
                ),
              ),
              const Gap(16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _hovered ? d.color : ArenaTheme.textPrimary,
                            fontSize: 13,
                          ),
                    ),
                    const Gap(3),
                    Text(
                      d.sublabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: ArenaTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              // Shortcut badge (desktop)
              if (isWide)
                AnimatedOpacity(
                  opacity: _hovered ? 0.7 : 0.2,
                  duration: const Duration(milliseconds: 110),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: ArenaTheme.textMuted),
                    ),
                    child: Text(
                      d.shortcut,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            color: ArenaTheme.textSecondary,
                          ),
                    ),
                  ),
                ),
              const Gap(12),

              // Arrow
              AnimatedSlide(
                offset:
                    _hovered ? Offset.zero : const Offset(-0.25, 0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0.15,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: d.color,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 300 + widget.index * 60))
        .slideX(
          begin: 0.04,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
  }
}

// ─── Status Footer ────────────────────────────────────────────────────────────

class _StatusFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liteLLM = ref.watch(liteLLMStatusNotifierProvider);
    final relay = ref.watch(relayConnectionNotifierProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _StatusPill(
            label: 'LITELLM',
            healthy: liteLLM == LiteLLMStatus.healthy,
            loading: liteLLM == LiteLLMStatus.starting ||
                liteLLM == LiteLLMStatus.unknown,
          ),
          const Gap(6),
          _StatusPill(
            label: 'RELAY',
            healthy: relay == RelayConnectionStatus.connected,
            loading: relay == RelayConnectionStatus.connecting,
          ),
          const Spacer(),
          Text(
            'v0.1.0-alpha',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: ArenaTheme.textMuted,
                  letterSpacing: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatefulWidget {
  const _StatusPill({
    required this.label,
    required this.healthy,
    required this.loading,
  });
  final String label;
  final bool healthy;
  final bool loading;

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.loading
        ? ArenaTheme.accentGold
        : widget.healthy
            ? ArenaTheme.accentGreen
            : ArenaTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(
                  (widget.healthy || widget.loading)
                      ? 0.5 + _pulse.value * 0.5
                      : 0.5,
                ),
                boxShadow: (widget.healthy || widget.loading)
                    ? [
                        BoxShadow(
                          color: color.withOpacity(_pulse.value * 0.7),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
            ),
          ),
          const Gap(6),
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Logo ────────────────────────────────────────────────────────────

class _LogoMark extends StatefulWidget {
  const _LogoMark({this.size = 56});
  final double size;

  @override
  State<_LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<_LogoMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _LogoPainter(progress: _ctrl.value),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double progress;
  const _LogoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;
    final innerR = r * 0.62;

    // Outer ring — dim
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = ArenaTheme.surfaceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Inner ring — dimmer
    canvas.drawCircle(
      Offset(cx, cy),
      innerR,
      Paint()
        ..color = ArenaTheme.textMuted.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Arc A — blue, outer ring, rotating
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2 + progress * 2 * math.pi,
      math.pi * 0.65,
      false,
      Paint()
        ..color = ArenaTheme.fighterA
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Arc B — red, inner ring, counter-rotating
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
      math.pi / 2 - progress * 2 * math.pi,
      math.pi * 0.65,
      false,
      Paint()
        ..color = ArenaTheme.fighterB
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Crosshair
    final crossPaint = Paint()
      ..color = ArenaTheme.textMuted.withOpacity(0.5)
      ..strokeWidth = 0.75;
    final cLen = size.width * 0.16;
    canvas.drawLine(Offset(cx - cLen, cy), Offset(cx + cLen, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - cLen), Offset(cx, cy + cLen), crossPaint);

    // Center glow dot
    final dotRadius = 3.0 + math.sin(progress * 2 * math.pi) * 0.8;
    canvas.drawCircle(
      Offset(cx, cy),
      dotRadius + 4,
      Paint()
        ..color = ArenaTheme.accent.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      dotRadius,
      Paint()..color = ArenaTheme.accent,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}

// ─── Grid Background ──────────────────────────────────────────────────────────

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = ArenaTheme.surfaceBorder.withOpacity(0.3)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Top-left accent glow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topLeft,
          radius: 1.1,
          colors: [
            ArenaTheme.accent.withOpacity(0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Bottom-right blue glow
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.bottomRight,
          radius: 1.0,
          colors: [
            ArenaTheme.accentBlue.withOpacity(0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Scanline overlay ─────────────────────────────────────────────────────────

class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanlinePainter(),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.035)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
