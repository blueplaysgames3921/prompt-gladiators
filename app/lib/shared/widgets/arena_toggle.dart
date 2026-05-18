import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../theme/arena_theme.dart';

class ArenaToggle extends StatelessWidget {
  const ArenaToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.compact = false,
  });

  final String label;
  final bool value;
  final void Function(bool) onChanged;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Switch(value: value, onChanged: onChanged);
    }

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 14,
                          color: value
                              ? ArenaTheme.textPrimary
                              : ArenaTheme.textSecondary,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const Gap(2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
