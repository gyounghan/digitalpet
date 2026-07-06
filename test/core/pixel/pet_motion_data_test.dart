import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/pixel/pet_motion_data.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart';

void main() {
  const species = ['tiger', 'bird', 'turtle', 'dragon'];
  const motions = [
    'walk',
    'eat',
    'sleep',
    'attack',
    'dodge',
    'hurt',
    'angry',
    'joy',
  ];

  group('babyMotionFrames 데이터 무결성', () {
    test('4종 × 8모션 × 3프레임이 모두 존재', () {
      expect(babyMotionFrames.keys, containsAll(species));
      for (final s in species) {
        final motionMap = babyMotionFrames[s]!;
        expect(motionMap.keys, containsAll(motions), reason: '$s 모션 누락');
        for (final m in motions) {
          expect(motionMap[m]!.length, 3, reason: '$s/$m 프레임 수');
        }
      }
    });

    test('모든 프레임은 16x16(수제 도트)이고 dark/body가 겹치지 않는다', () {
      for (final s in species) {
        for (final m in motions) {
          final frames = babyMotionFrames[s]![m]!;
          for (var i = 0; i < frames.length; i++) {
            final frame = frames[i];
            expect(frame.size, 16, reason: '$s/$m[$i]: size');
            expect(frame.dark.length, 16, reason: '$s/$m[$i]: dark rows');
            expect(frame.body.length, 16, reason: '$s/$m[$i]: body rows');
            for (var y = 0; y < 16; y++) {
              expect(frame.dark[y] & frame.body[y], 0,
                  reason: '$s/$m[$i]: row $y 겹침');
            }
          }
        }
      }
    });

    test('모든 프레임은 최소 1개 도트를 가진다', () {
      for (final s in species) {
        for (final m in motions) {
          final frames = babyMotionFrames[s]![m]!;
          for (var i = 0; i < frames.length; i++) {
            final hasDot = frames[i].dark.any((row) => row != 0) ||
                frames[i].body.any((row) => row != 0);
            expect(hasDot, isTrue, reason: '$s/$m[$i]: 빈 프레임');
          }
        }
      }
    });

    test('모션 프레임끼리는 서로 다르다 (움직임이 있다)', () {
      for (final s in species) {
        for (final m in motions) {
          final frames = babyMotionFrames[s]![m]!;
          bool sameFrames(int a, int b) {
            for (var y = 0; y < 16; y++) {
              if (frames[a].dark[y] != frames[b].dark[y]) return false;
              if (frames[a].body[y] != frames[b].body[y]) return false;
            }
            return true;
          }

          expect(sameFrames(0, 1), isFalse, reason: '$s/$m: f1==f2');
          expect(sameFrames(1, 2), isFalse, reason: '$s/$m: f2==f3');
        }
      }
    });
  });

  group('motionForMood 매핑', () {
    test('mood 6종 + dead → 모션 매핑', () {
      expect(motionForMood(PetMood.happy), PixelMotion.joy);
      expect(motionForMood(PetMood.normal), PixelMotion.walk);
      expect(motionForMood(PetMood.hungry), PixelMotion.angry);
      expect(motionForMood(PetMood.sleepy), PixelMotion.sleep);
      expect(motionForMood(PetMood.tired), PixelMotion.sleep);
      expect(motionForMood(PetMood.sad), PixelMotion.hurt);
      expect(motionForMood(PetMood.dead), PixelMotion.hurt);
    });
  });

  group('motionFramesFor / babySpeciesFromAssetPath', () {
    test('유효한 종/모션 조회', () {
      expect(motionFramesFor('dragon', PixelMotion.walk), isNotNull);
      expect(motionFramesFor('없는종', PixelMotion.walk), isNull);
    });

    test('베이비 스프라이트 경로에서 종 키 추출', () {
      expect(babySpeciesFromAssetPath('assets/dragon1.png'), 'dragon');
      expect(babySpeciesFromAssetPath('assets/tiger1.png'), 'tiger');
      // stage 3/4 이미지는 베이비가 아니다
      expect(babySpeciesFromAssetPath('assets/dragon2.png'), isNull);
      expect(babySpeciesFromAssetPath('assets/dragon3.png'), isNull);
      // 털뭉치(기본이미지)도 아니다
      expect(babySpeciesFromAssetPath('assets/기본이미지.png'), isNull);
    });
  });
}
