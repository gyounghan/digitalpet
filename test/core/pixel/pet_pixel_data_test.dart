import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/pixel/pet_pixel_data.dart';
import 'package:pocketfriend/presentation/widgets/pixel_pet_image.dart';

void main() {
  group('pixelKeyFromAssetPath', () {
    test('assets 경로에서 파일명 키 추출', () {
      expect(pixelKeyFromAssetPath('assets/dragon2.png'), 'dragon2');
      expect(pixelKeyFromAssetPath('assets/기본이미지.png'), '기본이미지');
      expect(
          pixelKeyFromAssetPath('assets/tiger_smile1.png'), 'tiger_smile1');
    });

    test('경로 구분자 없는 파일명도 처리', () {
      expect(pixelKeyFromAssetPath('dragon2.png'), 'dragon2');
    });

    test('확장자 없는 키는 그대로 반환', () {
      expect(pixelKeyFromAssetPath('dragon2'), 'dragon2');
    });
  });

  group('petPixelSprites 데이터 무결성', () {
    test('스프라이트가 존재한다', () {
      expect(petPixelSprites, isNotEmpty);
    });

    test('모든 스프라이트는 64x64 그리드 (dark/body/accent)', () {
      for (final entry in petPixelSprites.entries) {
        final sprite = entry.value;
        expect(sprite.size, 64, reason: '${entry.key}: size');
        expect(sprite.dark.length, 64, reason: '${entry.key}: dark rows');
        expect(sprite.body.length, 64, reason: '${entry.key}: body rows');
        expect(sprite.accent.length, 64, reason: '${entry.key}: accent rows');
      }
    });

    // 참고: 64그리드는 행 마스크가 64비트 전체를 쓰므로 최상위 비트(x=63)가
    // 켜진 행은 Dart에서 음수로 해석된다. 비트 연산(&, |)만 쓰므로 무해하며
    // 수치 범위 검사는 하지 않는다.

    test('dark/body/accent 도트는 서로 겹치지 않는다', () {
      for (final entry in petPixelSprites.entries) {
        final s = entry.value;
        for (var y = 0; y < s.size; y++) {
          expect(s.dark[y] & s.body[y], 0,
              reason: '${entry.key}: row $y dark∩body');
          expect(s.dark[y] & s.accent[y], 0,
              reason: '${entry.key}: row $y dark∩accent');
          expect(s.body[y] & s.accent[y], 0,
              reason: '${entry.key}: row $y body∩accent');
        }
      }
    });

    test('모든 스프라이트는 최소 1개 도트를 가진다', () {
      for (final entry in petPixelSprites.entries) {
        final hasDot = entry.value.dark.any((row) => row != 0) ||
            entry.value.body.any((row) => row != 0);
        expect(hasDot, isTrue, reason: '${entry.key}: 빈 스프라이트');
      }
    });
  });

  group('핵심 에셋 스프라이트 존재 확인', () {
    test('진화 대표 이미지 (getEvolutionImagePath 대상)', () {
      // stage 1 털뭉치
      expect(petPixelSprites['기본이미지'], isNotNull);
      // stage 2~4 각 종
      for (final prefix in ['tiger', 'bird', 'turtle', 'dragon']) {
        for (var i = 1; i <= 3; i++) {
          expect(petPixelSprites['$prefix$i'], isNotNull,
              reason: '$prefix$i 누락');
        }
      }
    });

    test('사신수 mood 이미지 (getEvolutionMoodImagePath 대상)', () {
      const moods = ['smile', 'exercise', 'hungry', 'sleepy', 'sleep', 'sad'];
      for (final prefix in ['tiger', 'bird', 'turtle', 'dragon']) {
        for (final mood in moods) {
          for (var i = 1; i <= 3; i++) {
            expect(petPixelSprites['${prefix}_$mood$i'], isNotNull,
                reason: '${prefix}_$mood$i 누락');
          }
        }
      }
    });

    test('스테이지1 mood 애니메이션 프레임 (PetImageAnimation 대상)', () {
      const frameSets = {
        'sleep': 3,
        'feed': 4,
        'exercise': 3,
        'happy': 3,
        'bored': 3,
        'anxious': 3,
        'full': 3,
        'sad': 3,
        'hungry': 4,
      };
      frameSets.forEach((name, count) {
        for (var i = 1; i <= count; i++) {
          expect(petPixelSprites['${name}_$i'], isNotNull,
              reason: '${name}_$i 누락');
        }
      });
    });

    test('pixelSpriteForAsset은 에셋 경로로 스프라이트를 찾는다', () {
      expect(pixelSpriteForAsset('assets/dragon2.png'), isNotNull);
      expect(pixelSpriteForAsset('assets/없는파일.png'), isNull);
    });
  });
}
