import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/presentation/widgets/frame_pet_animation.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart'
    show PixelMotion;

void main() {
  group('animKeyForOrFallback', () {
    test('정확한 프레임이 있으면 그대로 반환', () {
      expect(
        animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.walk),
        'toad_2_walk',
      );
    });

    test('두꺼비 유아기는 sleep·attack 프레임을 갖춰 정확 반환', () {
      // pixellab로 두꺼비_유아기_자기/포효 생성 후 실제 프레임 존재
      expect(
        animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.sleep),
        'toad_2_sleep',
      );
      expect(
        animKeyForOrFallback(EvolutionType.toad, 2, PixelMotion.attack),
        'toad_2_attack',
      );
    });

    test('프레임이 없는 모션은 유사 모션으로 대체 (bird 유아기 sleep → drowsy)', () {
      // bird_2_sleep 프레임은 없지만 bird_2_drowsy는 있음
      expect(
        animKeyForOrFallback(EvolutionType.bird, 2, PixelMotion.sleep),
        'bird_2_drowsy',
      );
    });

    test('성장기 두꺼비도 전 모션 정확 반환', () {
      expect(
        animKeyForOrFallback(EvolutionType.toad, 3, PixelMotion.attack),
        'toad_3_attack',
      );
    });

    test('프레임이 아예 없는 종은 null', () {
      expect(
        animKeyForOrFallback(EvolutionType.dokkaebi, 2, PixelMotion.walk),
        isNull,
      );
    });
  });
}
