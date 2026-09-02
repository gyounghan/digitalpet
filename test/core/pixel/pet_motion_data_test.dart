import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/pixel/pet_motion_data.dart';
import 'package:pocketfriend/core/pixel/pet_pixel_data.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/presentation/widgets/pixel_motion_animation.dart';

bool _hasDarkDot(PixelSprite sprite, int x, int y) {
  return (sprite.dark[y] & (1 << x)) != 0;
}

void main() {
  const babyKeys = ['tiger1', 'bird1', 'turtle1', 'dragon1'];
  const juniorKeys = ['tiger2', 'bird2', 'turtle2', 'dragon2'];
  const matureKeys = ['tiger3', 'bird3', 'turtle3', 'dragon3'];
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
    test('털뭉치·유아기·성장기·성숙기가 존재하고, 모든 키는 9모션 × 3프레임을 가진다', () {
      expect(motionFrames.keys, contains('fluff'));
      expect(motionFrames.keys, containsAll(babyKeys));
      expect(motionFrames.keys, containsAll(juniorKeys));
      expect(motionFrames.keys, containsAll(matureKeys));
      for (final key in motionFrames.keys) {
        final motionMap = motionFrames[key]!;
        expect(motionMap.keys, containsAll(motions), reason: '$key 모션 누락');
        for (final m in motions) {
          expect(motionMap[m]!.length, 3, reason: '$key/$m 프레임 수');
        }
      }
    });

    test('프레임은 size·행수가 일치하고 5계조(dark/body/accent/2/3)가 겹치지 않는다', () {
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
              // 각 도트는 한 계조에만 속해야 한다 (레이어 간 비트 겹침 없음)
              final layers = [
                frame.dark[y],
                frame.body[y],
                frame.accent[y],
                y < frame.accent2.length ? frame.accent2[y] : 0,
                y < frame.accent3.length ? frame.accent3[y] : 0,
              ];
              for (var a = 0; a < layers.length; a++) {
                for (var b = a + 1; b < layers.length; b++) {
                  expect(layers[a] & layers[b], 0,
                      reason: '$key/$m[$i]: row $y layer$a∩layer$b');
                }
              }
            }
          }
        }
      }
    });

    test('영물 10종은 5색 팔레트를 가진다', () {
      for (final species in [
        'samjoko',
        'gumiho',
        'moonrabbit',
        'haetae',
        'dokkaebi',
        'hwangryong',
        'bear',
        'otter',
        'owl',
        'crane',
      ]) {
        final pal = hiddenPaletteForSpriteKey('${species}2');
        expect(pal, isNotNull, reason: '$species 팔레트 없음');
        expect(pal!.length, 5, reason: '$species 팔레트 5색 아님');
      }
      // 사신수는 팔레트 없음 (테마 재도색 유지)
      expect(hiddenPaletteForSpriteKey('tiger2'), isNull);
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

    test('그리드 크기: 털뭉치 40, 유아기 32, 성장기 36, 성숙기 56', () {
      int expectedSize(String key) {
        if (key == 'fluff') return 40;
        // '{종}2n'/'{종}3n' 일반종 라인도 스테이지 크기를 따른다
        final base = key.endsWith('n') ? key.substring(0, key.length - 1) : key;
        if (base.endsWith('1')) return 32; // 유아기
        if (base.endsWith('2')) return 36; // 성장기
        return 56; // 성숙기
      }

      for (final key in motionFrames.keys) {
        expect(motionFrames[key]!['walk']![0].size, expectedSize(key),
            reason: '$key: 그리드 크기');
      }
    });

    test('구미호 유아기 눈은 원본 눈 잔상을 지운 뒤 그린다', () {
      // 마커 기반 파이프라인(tool/dump_reference_art.py) 좌표:
      // 눈 rect (4,14,2,3)/(13,14,2,3), eye_clear (4,14,3,3)/(13,14,3,3).
      // 지움 영역 안에서는 그려진 눈 자리에만 dark 도트가 있어야 한다.
      final frame = motionFrames['gumiho1']!['walk']![1];

      bool isDrawnEye(int x, int y) {
        final inLeft = x >= 4 && x < 6 && y >= 14 && y < 17;
        final inRight = x >= 13 && x < 15 && y >= 14 && y < 17;
        return inLeft || inRight;
      }

      for (final clearArea in [
        (x: 4, y: 14, w: 3, h: 3),
        (x: 13, y: 14, w: 3, h: 3),
      ]) {
        for (var y = clearArea.y; y < clearArea.y + clearArea.h; y++) {
          for (var x = clearArea.x; x < clearArea.x + clearArea.w; x++) {
            expect(
              _hasDarkDot(frame, x, y),
              isDrawnEye(x, y),
              reason: 'gumiho1 눈 주변 잔상: ($x, $y)',
            );
          }
        }
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
      // dead는 긴 잠 컨셉 — 잠자는 모션
      expect(motionForMood(PetMood.dead), PixelMotion.sleep);
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
      // 성장기(stage 3)·성숙기(stage 4) 이미지도 모션 지원
      expect(motionSpriteKeyFromAssetPath('assets/dragon2.png'), 'dragon2');
      expect(motionSpriteKeyFromAssetPath('assets/turtle2.png'), 'turtle2');
      expect(motionSpriteKeyFromAssetPath('assets/dragon3.png'), 'dragon3');
      expect(motionSpriteKeyFromAssetPath('assets/bird3.png'), 'bird3');
    });

    test('진화 단계 → 모션 키 (14종 단일 디자인, 등급/n 분기 없음)', () {
      expect(motionSpriteKeyForStage(null, 1), 'fluff');
      expect(motionSpriteKeyForStage(EvolutionType.snake, 2), 'dragon1');
      // 등급과 무관하게 단일 라인 — 색만 변이로 달라진다
      expect(motionSpriteKeyForStage(EvolutionType.tiger, 3, 'superior'), 'tiger2');
      expect(motionSpriteKeyForStage(EvolutionType.tiger, 3, 'normal'), 'tiger2');
      expect(motionSpriteKeyForStage(EvolutionType.bird, 4, 'mythical'), 'bird3');
      expect(motionSpriteKeyForStage(EvolutionType.bird, 4, 'normal'), 'bird3');
      expect(motionSpriteKeyForStage(EvolutionType.turtle, 4), 'turtle3');
      // 동물 영물(2차 추가) — 실제 도트 키
      expect(motionSpriteKeyForStage(EvolutionType.bear, 2), 'bear1');
      expect(motionSpriteKeyForStage(EvolutionType.otter, 3), 'otter2');
      expect(motionSpriteKeyForStage(EvolutionType.owl, 4), 'owl3');
      expect(motionSpriteKeyForStage(EvolutionType.crane, 2), 'crane1');
      // 'n' 일반종 라인은 폐기 — 그런 키는 생성되지 않는다
      expect(motionFrames.keys.any((k) => k.endsWith('n')), isFalse);
      // 종 미결정 상태의 미래 단계는 null
      expect(motionSpriteKeyForStage(null, 2), isNull);
    });
  });
}
