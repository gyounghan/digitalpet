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

    testWidgets('종 결정 + stage 2/3은 도트 모션 프레임 렌더', (tester) async {
      for (final stage in [2, 3]) {
        await pump(
          tester,
          PetMotionThumb(type: EvolutionType.snake, stage: stage, size: 40),
        );
        expect(find.byType(PixelSpriteView), findsOneWidget,
            reason: 'stage $stage');
      }
    });

    testWidgets('stage 4 (사신수)는 정적 도트 이미지 폴백', (tester) async {
      await pump(
        tester,
        const PetMotionThumb(type: EvolutionType.tiger, stage: 4, size: 40),
      );
      // 모션 데이터가 없으므로 PixelPetImage 경로
      expect(find.byType(PixelPetImage), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });
  });

  group('PetMotionThumb.motionKey', () {
    test('단계 → 스프라이트 키 매핑', () {
      expect(PetMotionThumb.motionKey(null, 1), 'fluff');
      expect(PetMotionThumb.motionKey(EvolutionType.snake, 2), 'dragon1');
      expect(PetMotionThumb.motionKey(EvolutionType.tiger, 3), 'tiger2');
      expect(PetMotionThumb.motionKey(EvolutionType.bird, 4), isNull);
      expect(PetMotionThumb.motionKey(null, 2), isNull);
    });
  });
}
