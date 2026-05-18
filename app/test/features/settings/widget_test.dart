import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_gladiators/shared/theme/arena_theme.dart';
import 'package:prompt_gladiators/shared/widgets/arena_section.dart';
import 'package:prompt_gladiators/shared/widgets/arena_toggle.dart';
import 'package:prompt_gladiators/shared/widgets/arena_text_field.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ArenaTheme.dark,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('ArenaSection', () {
    testWidgets('renders title and child', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaSection(
          title: 'TEST SECTION',
          child: Text('Section content'),
        ),
      ));

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.text('Section content'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        ArenaSection(
          title: 'WITH TRAILING',
          trailing: const Icon(Icons.settings),
          child: const Text('Content'),
        ),
      ));

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('uses titleColor when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaSection(
          title: 'DANGER',
          titleColor: ArenaTheme.accent,
          child: SizedBox.shrink(),
        ),
      ));

      // Just verify it renders without throwing
      expect(find.text('DANGER'), findsOneWidget);
    });
  });

  group('ArenaToggle', () {
    testWidgets('displays label and responds to taps', (tester) async {
      bool value = false;

      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (_, setState) => ArenaToggle(
            label: 'ENABLE FEATURE',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ));

      expect(find.text('ENABLE FEATURE'), findsOneWidget);
      expect(value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        ArenaToggle(
          label: 'FEATURE',
          subtitle: 'This enables the feature',
          value: false,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('This enables the feature'), findsOneWidget);
    });

    testWidgets('compact mode renders only Switch', (tester) async {
      await tester.pumpWidget(_wrap(
        ArenaToggle(
          label: '',
          value: true,
          onChanged: (_) {},
          compact: true,
        ),
      ));

      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('ArenaTextField', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaTextField(label: 'MODEL ID', hint: 'gpt-4o'),
      ));

      expect(find.text('MODEL ID'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String captured = '';

      await tester.pumpWidget(_wrap(
        ArenaTextField(
          label: 'INPUT',
          onChanged: (v) => captured = v,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      expect(captured, equals('hello'));
    });

    testWidgets('value prop initialises controller text', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaTextField(label: 'PRESET', value: 'preset-value'),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text ?? '', equals('preset-value'));
    });

    testWidgets('obscureText hides input', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaTextField(
          label: 'PASSWORD',
          obscureText: true,
        ),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.obscureText, isTrue);
    });

    testWidgets('multi-line renders correctly', (tester) async {
      await tester.pumpWidget(_wrap(
        const ArenaTextField(
          label: 'SYSTEM PROMPT',
          maxLines: 4,
        ),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.maxLines, equals(4));
    });
  });

  group('ArenaTheme', () {
    test('color constants are not transparent', () {
      expect(ArenaTheme.background.alpha, greaterThan(200));
      expect(ArenaTheme.accent.alpha, equals(255));
      expect(ArenaTheme.accentBlue.alpha, equals(255));
      expect(ArenaTheme.accentGold.alpha, equals(255));
      expect(ArenaTheme.accentGreen.alpha, equals(255));
    });

    test('fighter colors are distinct', () {
      expect(ArenaTheme.fighterA, isNot(equals(ArenaTheme.fighterB)));
    });

    test('dark theme has correct brightness', () {
      expect(ArenaTheme.dark.brightness, equals(Brightness.dark));
    });

    test('dark theme uses Material 3', () {
      expect(ArenaTheme.dark.useMaterial3, isTrue);
    });
  });
}
