import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart';

void main() {
  group('대기 모션 시나리오 (idleMotionPool / pickIdleMotion)', () {
    test('모든 mood×시간대에 풀이 있고 가중치 합이 100이다', () {
      for (final mood in PetMood.values) {
        for (final hour in [3, 10, 23]) {
          final pool = idleMotionPool(mood, hour);
          expect(pool, isNotEmpty, reason: '$mood/$hour');
          final total = pool.fold(0, (s, e) => s + e.$2);
          expect(total, 100, reason: '$mood/$hour 가중치 합');
        }
      }
    });

    test('대표 모션이 풀에서 가장 큰 비중을 차지한다', () {
      (PixelMotion, int) top(PetMood m, int h) {
        final pool = idleMotionPool(m, h);
        pool.sort((a, b) => b.$2.compareTo(a.$2));
        return pool.first;
      }

      expect(top(PetMood.hungry, 10).$1, PixelMotion.hungry);
      expect(top(PetMood.sad, 10).$1, PixelMotion.sad, reason: '신규 시무룩 모션');
      expect(top(PetMood.sleepy, 10).$1, PixelMotion.drowsy,
          reason: '신규 졸림 모션');
      expect(top(PetMood.happy, 10).$1, PixelMotion.joy);
      expect(top(PetMood.normal, 10).$1, PixelMotion.walk);
    });

    test('밤에는 어떤 평시 기분이든 잠 비중이 가장 크다', () {
      for (final mood in [PetMood.happy, PetMood.normal]) {
        final pool = idleMotionPool(mood, 23);
        pool.sort((a, b) => b.$2.compareTo(a.$2));
        expect(pool.first.$1, PixelMotion.sleep, reason: '$mood 밤');
      }
    });

    test('긴 잠(dead)은 항상 sleep', () {
      for (var roll = 0; roll < 100; roll += 7) {
        expect(pickIdleMotion(PetMood.dead, 12, roll), PixelMotion.sleep);
      }
    });

    test('pickIdleMotion — roll 전 구간이 풀 안의 모션만 반환한다', () {
      for (final mood in PetMood.values) {
        final pool = idleMotionPool(mood, 10).map((e) => e.$1).toSet();
        for (var roll = 0; roll < 100; roll++) {
          expect(pool.contains(pickIdleMotion(mood, 10, roll)), isTrue);
        }
      }
    });

    test('normal 낮 풀에는 걷기 외 교감 모션이 절반 이상 섞인다', () {
      final pool = idleMotionPool(PetMood.normal, 10);
      final walkWeight = pool
          .where((e) => e.$1 == PixelMotion.walk)
          .fold(0, (s, e) => s + e.$2);
      expect(walkWeight, lessThanOrEqualTo(50));
    });
  });
}
