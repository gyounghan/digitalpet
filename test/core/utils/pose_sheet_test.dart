import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/utils/pose_sheet.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';

void main() {
  group('poseSheetAssetFor', () {
    test('포즈시트 보유 종·단계는 assets/pets 경로 반환', () {
      expect(
        poseSheetAssetFor(EvolutionType.gumiho, 2),
        'assets/pets/gumiho_2.png',
      );
      expect(
        poseSheetAssetFor(EvolutionType.tiger, 4),
        'assets/pets/tiger_4.png',
      );
    });

    test('stage 1(털뭉치)은 종 공통이라 포즈시트 없음', () {
      expect(poseSheetAssetFor(EvolutionType.gumiho, 1), isNull);
    });

    test('종 미결정이면 null', () {
      expect(poseSheetAssetFor(null, 2), isNull);
    });

    test('포즈시트 없는 종(도깨비)은 null → 도트 폴백', () {
      expect(poseSheetAssetFor(EvolutionType.dokkaebi, 2), isNull);
    });
  });
}
