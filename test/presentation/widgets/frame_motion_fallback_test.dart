import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/presentation/widgets/frame_pet_animation.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart'
    show PixelMotion;

void main() {
  group('animKeyForOrFallback', () {
    test('정확한 프레임이 있으면 그대로 반환', () {
      // 두꺼비 유아기는 walk 프레임 보유
      expect(
        animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.walk),
        'toad_2_walk',
      );
    });

    test('유아기 두꺼비 sleep 누락 → drowsy 프레임으로 대체', () {
      // toad_2_sleep은 없지만 toad_2_drowsy는 있음
      expect(
        animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.sleep),
        'toad_2_drowsy',
      );
    });

    test('유아기 두꺼비 attack 누락 → joy/walk 프레임으로 대체', () {
      // toad_2_attack 없음 → 유사 모션(joy 우선, 없으면 walk)
      final key = animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.attack);
      expect(key, anyOf('toad_2_joy', 'toad_2_walk'));
    });

    test('성장기 두꺼비는 전 모션 보유 — 대체 없이 정확 반환', () {
      expect(
        animKeyForOrFallback(EvolutionType.toad, 3, PixelMotion.attack),
        'toad_3_attack',
      );
      expect(
        animKeyForOrFallback(EvolutionType.toad, 3, PixelMotion.sleep),
        'toad_3_sleep',
      );
    });

    test('프레임이 아예 없는 종은 null', () {
      // 도깨비는 프레임 에셋 없음
      expect(
        animKeyForOrFallback(EvolutionType.dokkaebi, 2, PixelMotion.walk),
        isNull,
      );
    });
  });
}
