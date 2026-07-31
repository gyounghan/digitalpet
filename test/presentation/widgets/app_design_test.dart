import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/theme/species_theme.dart';
import 'package:pocketfriend/presentation/widgets/app_design.dart';

void main() {
  group('AppPill', () {
    testWidgets('outline variant 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPill(
              text: '주간',
              theme: SpeciesTheme.defaultTheme,
            ),
          ),
        ),
      );
      expect(find.text('주간'), findsOneWidget);
    });

    testWidgets('icon이 함께 렌더링된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPill(
              text: '랭킹',
              theme: SpeciesTheme.tiger,
              icon: Icons.emoji_events,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.text('랭킹'), findsOneWidget);
    });
  });

  group('AppMeter', () {
    testWidgets('value가 max보다 크면 100%로 클램프', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AppMeter(
                value: 150,
                theme: SpeciesTheme.defaultTheme,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AppMeter), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      final fsb = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fsb.widthFactor, 1.0);
    });

    testWidgets('value 0일 때 widthFactor 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AppMeter(value: 0, theme: SpeciesTheme.defaultTheme),
            ),
          ),
        ),
      );
      final fsb = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fsb.widthFactor, 0.0);
    });

    testWidgets('value 50/100일 때 widthFactor 0.5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AppMeter(value: 50, theme: SpeciesTheme.defaultTheme),
            ),
          ),
        ),
      );
      final fsb = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fsb.widthFactor, 0.5);
    });
  });

  group('AppCard', () {
    testWidgets('child가 렌더링된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              theme: SpeciesTheme.tiger,
              child: Text('카드 내용'),
            ),
          ),
        ),
      );
      expect(find.text('카드 내용'), findsOneWidget);
    });

    testWidgets('onTap이 호출된다', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              theme: SpeciesTheme.tiger,
              onTap: () => tapped = true,
              child: const Text('탭'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('탭'));
      expect(tapped, true);
    });
  });

  group('ScreenTop', () {
    testWidgets('title과 onBack 버튼 렌더링', (tester) async {
      var back = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenTop(
              title: '랭킹',
              onBack: () => back = true,
            ),
          ),
        ),
      );
      expect(find.text('랭킹'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(back, true);
    });

    testWidgets('onBack이 null이면 뒤로가기 버튼 미표시', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenTop(title: '랭킹'),
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('trailing이 렌더링된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenTop(
              title: '랭킹',
              trailing: AppPill(
                text: '주간',
                theme: SpeciesTheme.defaultTheme,
              ),
            ),
          ),
        ),
      );
      expect(find.text('주간'), findsOneWidget);
    });
  });
}
