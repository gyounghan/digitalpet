import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/pixel/pet_motion_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart';

void main() {
  const babyKeys = ['tiger1', 'bird1', 'turtle1', 'dragon1'];
  const juniorKeys = ['tiger2', 'bird2', 'turtle2', 'dragon2'];
  const motions = [
    'walk',
    'eat',
    'sleep',
    'attack',
    'dodge',
    'hurt',
    'angry',
    'joy',
    'hungry',
  ];

  group('motionFrames 데이터 무결성', () {
    test('털뭉치·유아기·성장기가 존재하고, 모든 키는 8모션 × 3프레임을 가진다', () {
      expect(motionFrames.keys, contains('fluff'));
      expect(motionFrames.keys, containsAll(babyKeys));
      expect(motionFrames.keys, containsAll(juniorKeys));
      for (final key in motionFrames.keys) {
        final motionMap = motionFrames[key]!;
        expect(motionMap.keys, containsAll(motions), reason: '$key 모션 누락');
        for (final m in motions) {
          expect(motionMap[m]!.length, 3, reason: '$key/$m 프레임 수');
        }
      }
    });

    test('프레임은 size와 행 수가 일치하고 dark/body/accent가 겹치지 않는다', () {
      for (final key in motionFrames.keys) {
        for (final m in motions) {
          final frames = motionFrames[key]![m]!;
          for (var i = 0; i < frames.length; i++) {
            final frame = frames[i];
            final n = frame.size;
            expect(n, greaterThanOrEqualTo(16), reason: '$key/$m[$i]: size');
            expect(frame.dark.length, n, reason: '$key/$m[$i]: dark rows');
            expect(frame.body.length, n, reason: '$key/$m[$i]: body rows');
            expect(frame.accent.length, n, reason: '$key/$m[$i]: accent rows');
            for (var y = 0; y < n; y++) {
              expect(frame.dark[y] & frame.body[y], 0,
                  reason: '$key/$m[$i]: row $y dark∩body');
              expect(frame.dark[y] & frame.accent[y], 0,
                  reason: '$key/$m[$i]: row $y dark∩accent');
              expect(frame.body[y] & frame.accent[y], 0,
                  reason: '$key/$m[$i]: row $y body∩accent');
            }
          }
        }
      }
    });

    test('같은 스프라이트 키의 모든 프레임은 같은 size를 가진다', () {
      for (final key in motionFrames.keys) {
        final sizes = <int>{};
        for (final m in motions) {
          for (final frame in motionFrames[key]![m]!) {
            sizes.add(frame.size);
          }
        }
        expect(sizes.length, 1, reason: '$key: size 혼재 $sizes');
      }
    });

    test('그리드 크기: 털뭉치 36, 유아기 32, 성장기 36', () {
      int expectedSize(String key) {
        if (key == 'fluff') return 36;
        return key.endsWith('1') ? 32 : 36; // 유아기 32 / 성장기 36
      }

      for (final key in motionFrames.keys) {
        expect(motionFrames[key]!['walk']![0].size, expectedSize(key),
            reason: '$key: 그리드 크기');
      }
    });

    test('모든 프레임은 최소 1개 도트를 가진다', () {
      for (final key in motionFrames.keys) {
        for (final m in motions) {
          final frames = motionFrames[key]![m]!;
          for (var i = 0; i < frames.length; i++) {
            final hasDot = frames[i].dark.any((row) => row != 0) ||
                frames[i].body.any((row) => row != 0);
            expect(hasDot, isTrue, reason: '$key/$m[$i]: 빈 프레임');
          }
        }
      }
    });

    test('모션 프레임끼리는 서로 다르다 (움직임이 있다)', () {
      for (final key in motionFrames.keys) {
        for (final m in motions) {
          final frames = motionFrames[key]![m]!;
          bool sameFrames(int a, int b) {
            for (var y = 0; y < frames[a].size; y++) {
              if (frames[a].dark[y] != frames[b].dark[y]) return false;
              if (frames[a].body[y] != frames[b].body[y]) return false;
            }
            return true;
          }

          expect(sameFrames(0, 1), isFalse, reason: '$key/$m: f1==f2');
          expect(sameFrames(1, 2), isFalse, reason: '$key/$m: f2==f3');
        }
      }
    });
  });

  group('motionForMood 매핑', () {
    test('mood 6종 + dead → 모션 매핑', () {
      expect(motionForMood(PetMood.happy), PixelMotion.joy);
      expect(motionForMood(PetMood.normal), PixelMotion.walk);
      expect(motionForMood(PetMood.hungry), PixelMotion.hungry);
      expect(motionForMood(PetMood.sleepy), PixelMotion.sleep);
      expect(motionForMood(PetMood.tired), PixelMotion.sleep);
      expect(motionForMood(PetMood.sad), PixelMotion.hurt);
      expect(motionForMood(PetMood.dead), PixelMotion.hurt);
    });
  });

  group('motionFramesFor / motionSpriteKeyFromAssetPath', () {
    test('유효한 스프라이트 키/모션 조회', () {
      expect(motionFramesFor('dragon1', PixelMotion.walk), isNotNull);
      expect(motionFramesFor('없는키', PixelMotion.walk), isNull);
    });

    test('에셋 경로에서 모션 스프라이트 키 추출', () {
      // 털뭉치(stage 1)는 '기본이미지' → 'fluff'
      expect(motionSpriteKeyFromAssetPath('assets/기본이미지.png'), 'fluff');
      expect(motionSpriteKeyFromAssetPath('assets/dragon1.png'), 'dragon1');
      expect(motionSpriteKeyFromAssetPath('assets/tiger1.png'), 'tiger1');
      // 성장기(stage 3) 이미지도 모션 지원
      expect(motionSpriteKeyFromAssetPath('assets/dragon2.png'), 'dragon2');
      expect(motionSpriteKeyFromAssetPath('assets/turtle2.png'), 'turtle2');
      // 신수(stage 4) 이미지는 모션 미지원
      expect(motionSpriteKeyFromAssetPath('assets/dragon3.png'), isNull);
    });
  });
}
