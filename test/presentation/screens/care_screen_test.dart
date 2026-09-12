import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/presentation/widgets/mock_ui_widgets.dart';

void main() {
  group('간소화된 케어 화면 공통 요소', () {
    testWidgets('더보기 버튼은 제목과 요약을 보여주고 펼침 상태를 전달한다', (tester) async {
      var expanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MockDisclosureButton(
                title: '진행 중인 퀘스트',
                subtitle: '나머지 2개',
                expanded: expanded,
                onTap: () => setState(() => expanded = !expanded),
              ),
            ),
          ),
        ),
      );

      expect(find.text('진행 중인 퀘스트'), findsOneWidget);
      expect(find.text('나머지 2개'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.byType(MockDisclosureButton));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    });

    testWidgets('업적 배지는 이름 대신 메달과 접근성 라벨을 보여준다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockAchievementBadge(
              semanticLabel: '7일 연속 접속 배지',
              icon: Icons.star_rounded,
              color: Colors.amber,
              selected: true,
              locked: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('7일 연속 접속 배지'), findsOneWidget);
      expect(find.text('7일 연속 접속'), findsNothing);
    });
  });
}
