// arena_section.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../theme/arena_theme.dart';

class ArenaSection extends StatelessWidget {
  const ArenaSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.titleColor,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? titleColor;

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
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ArenaTheme.surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 12, color: titleColor ?? ArenaTheme.accentBlue),
                const Gap(8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: titleColor ?? ArenaTheme.textSecondary,
                          fontSize: 11,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
