import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/presentation/widgets/pet_motion_thumb.dart';
import 'package:pocketfriend/presentation/widgets/pixel_pet_image.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  group('PetMotionThumb', () {
    testWidgets('종 미결정 + stage 2 이상이면 ? 표시', (tester) async {
      await pump(
        tester,
        const PetMotionThumb(type: null, stage: 2, size: 40),
      );
      expect(find.text('?'), findsOneWidget);
      expect(find.byType(PixelSpriteView), findsNothing);
    });

    testWidgets('stage 1 (털뭉치)은 종 미결정이어도 도트 프레임 렌더', (tester) async {
      await pump(
        tester,
        const PetMotionThumb(type: null, stage: 1, size: 40),
      );
      expect(find.byType(PixelSpriteView), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('프레임 보유 종(청룡) stage 2/3은 프레임 이미지 렌더', (tester) async {
      for (final stage in [2, 3]) {
        await pump(
          tester,
          PetMotionThumb(type: EvolutionType.snake, stage: stage, size: 40),
        );
        expect(find.byType(Image), findsOneWidget, reason: 'stage $stage');
      }
    });

    testWidgets('프레임 보유 종(백호) 성숙기도 프레임 이미지 렌더', (tester) async {
      await pump(
        tester,
        const PetMotionThumb(type: EvolutionType.tiger, stage: 4, size: 40),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('프레임 없는 종(도깨비)은 도트 스프라이트로 폴백', (tester) async {
      await pump(
        tester,
        const PetMotionThumb(type: EvolutionType.dokkaebi, stage: 2, size: 40),
      );
      expect(find.byType(PixelSpriteView), findsOneWidget);
    });
  });
}
