import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/theme/species_theme.dart';
import 'package:pocketfriend/presentation/widgets/app_design.dart';

/// CareScreen 자체는 Riverpod + Hive가 필요해서 통합 테스트로 검증되어야 한다.
/// 여기서는 케어 화면이 따르는 디자인 패턴(섹션 3개 구조)을 보장하는 가벼운 smoke test만 둔다.
void main() {
  group('CareScreen 디자인 패턴 - 3섹션 구조', () {
    testWidgets('SectionTitle 3개로 섹션을 명확히 나눈다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SectionTitle(title: '대체 케어'),
                  SectionTitle(title: '자동 감지'),
                  SectionTitle(title: '진화 트리'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('대체 케어'), findsOneWidget);
      expect(find.text('자동 감지'), findsOneWidget);
      expect(find.text('진화 트리'), findsOneWidget);
    });

    testWidgets('AppListRow 가 케어 항목 표시 형식을 따른다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppListRow(
              theme: SpeciesTheme.tiger,
              leading:
                  const Icon(Icons.local_dining, color: Colors.black, size: 20),
              title: '간편 급식',
              subtitle: '식사 시간대 · 오늘 0/3회 사용',
              trailing: const AppPill(
                text: '시작',
                theme: SpeciesTheme.tiger,
                variant: AppPillVariant.solid,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('간편 급식'), findsOneWidget);
      expect(find.text('식사 시간대 · 오늘 0/3회 사용'), findsOneWidget);
      expect(find.text('시작'), findsOneWidget);
      expect(find.byIcon(Icons.local_dining), findsOneWidget);
    });
  });
}
