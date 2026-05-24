import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/utils/pet_image_helper.dart';
import 'package:pocketfriend/domain/entities/evolution_type.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/presentation/widgets/pet_image_animation.dart';

void main() {
  group('getEvolutionImagePath', () {
    test('stage 1 (털뭉치)은 기본이미지 반환', () {
      expect(getEvolutionImagePath(EvolutionType.bird, 1), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(EvolutionType.snake, 1), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(EvolutionType.tiger, 1), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(EvolutionType.turtle, 1), 'assets/기본이미지.png');
    });

    test('evolutionType이 null이면 기본이미지 반환', () {
      expect(getEvolutionImagePath(null, 1), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(null, 2), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(null, 3), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(null, 4), 'assets/기본이미지.png');
    });

    test('stage 0 이하는 기본이미지 반환', () {
      expect(getEvolutionImagePath(EvolutionType.bird, 0), 'assets/기본이미지.png');
      expect(getEvolutionImagePath(EvolutionType.bird, -1), 'assets/기본이미지.png');
    });

    test('bird 타입 - stage별 올바른 경로 반환', () {
      expect(getEvolutionImagePath(EvolutionType.bird, 2), 'assets/bird1.png');
      expect(getEvolutionImagePath(EvolutionType.bird, 3), 'assets/bird2.png');
      expect(getEvolutionImagePath(EvolutionType.bird, 4), 'assets/bird3.png');
    });

    test('snake 타입 - dragon 이미지 사용', () {
      expect(getEvolutionImagePath(EvolutionType.snake, 2), 'assets/dragon1.png');
      expect(getEvolutionImagePath(EvolutionType.snake, 3), 'assets/dragon2.png');
      expect(getEvolutionImagePath(EvolutionType.snake, 4), 'assets/dragon3.png');
    });

    test('tiger 타입 - stage별 올바른 경로 반환', () {
      expect(getEvolutionImagePath(EvolutionType.tiger, 2), 'assets/tiger1.png');
      expect(getEvolutionImagePath(EvolutionType.tiger, 3), 'assets/tiger2.png');
      expect(getEvolutionImagePath(EvolutionType.tiger, 4), 'assets/tiger3.png');
    });

    test('turtle 타입 - stage별 올바른 경로 반환', () {
      expect(getEvolutionImagePath(EvolutionType.turtle, 2), 'assets/turtle1.png');
      expect(getEvolutionImagePath(EvolutionType.turtle, 3), 'assets/turtle2.png');
      expect(getEvolutionImagePath(EvolutionType.turtle, 4), 'assets/turtle3.png');
    });

    test('stage 5 이상은 stage 4와 동일 (clamp)', () {
      expect(getEvolutionImagePath(EvolutionType.bird, 5), 'assets/bird3.png');
      expect(getEvolutionImagePath(EvolutionType.snake, 10), 'assets/dragon3.png');
    });
  });

  group('getPetImageTypeFromMood', () {
    test('happy → happy', () {
      expect(getPetImageTypeFromMood(PetMood.happy), PetImageType.happy);
    });

    test('sleepy → sleep', () {
      expect(getPetImageTypeFromMood(PetMood.sleepy), PetImageType.sleep);
    });

    test('hungry → feed', () {
      expect(getPetImageTypeFromMood(PetMood.hungry), PetImageType.feed);
    });

    test('bored → bored', () {
      expect(getPetImageTypeFromMood(PetMood.bored), PetImageType.bored);
    });

    test('normal → exercise', () {
      expect(getPetImageTypeFromMood(PetMood.normal), PetImageType.exercise);
    });

    test('energetic → exercise', () {
      expect(getPetImageTypeFromMood(PetMood.energetic), PetImageType.exercise);
    });

    test('tired → sleep', () {
      expect(getPetImageTypeFromMood(PetMood.tired), PetImageType.sleep);
    });

    test('full → full', () {
      expect(getPetImageTypeFromMood(PetMood.full), PetImageType.full);
    });

    test('anxious → anxious', () {
      expect(getPetImageTypeFromMood(PetMood.anxious), PetImageType.anxious);
    });

    test('satisfied → full', () {
      expect(getPetImageTypeFromMood(PetMood.satisfied), PetImageType.full);
    });

    test('dead → sad', () {
      expect(getPetImageTypeFromMood(PetMood.dead), PetImageType.sad);
    });

    test('모든 PetMood 값이 매핑됨', () {
      for (final mood in PetMood.values) {
        expect(() => getPetImageTypeFromMood(mood), returnsNormally);
      }
    });
  });

  group('getEvolutionMoodImagePath', () {
    test('stage 1은 null 반환 (기본 mood 애니메이션 사용)', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.bird, 1, PetMood.hungry),
        isNull,
      );
    });

    test('evolutionType이 null이면 null', () {
      expect(getEvolutionMoodImagePath(null, 2, PetMood.hungry), isNull);
    });

    test('stage 2 (유아기) → 이미지 인덱스 1', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.bird, 2, PetMood.hungry),
        'assets/bird_hungry1.png',
      );
    });

    test('stage 3 (성장기) → 이미지 인덱스 2', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.bird, 3, PetMood.hungry),
        'assets/bird_hungry2.png',
      );
    });

    test('stage 4 (어른) → 이미지 인덱스 3', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.bird, 4, PetMood.hungry),
        'assets/bird_hungry3.png',
      );
    });

    test('stage 5+ → 3으로 clamp', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.tiger, 10, PetMood.happy),
        'assets/tiger_smile3.png',
      );
    });

    test('snake → dragon prefix 사용', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.snake, 3, PetMood.sleepy),
        'assets/dragon_sleepy2.png',
      );
    });

    test('happy → smile suffix', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.tiger, 4, PetMood.happy),
        'assets/tiger_smile3.png',
      );
    });

    test('tired → sleep suffix', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.turtle, 2, PetMood.tired),
        'assets/turtle_sleep1.png',
      );
    });

    test('normal → exercise suffix', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.bird, 2, PetMood.normal),
        'assets/bird_exercise1.png',
      );
    });

    test('bored → sad suffix', () {
      expect(
        getEvolutionMoodImagePath(EvolutionType.tiger, 3, PetMood.bored),
        'assets/tiger_sad2.png',
      );
    });

    test('모든 evolution type * mood 조합에서 정상 반환 (stage>=2)', () {
      for (final type in EvolutionType.values) {
        for (final mood in PetMood.values) {
          for (final stage in [2, 3, 4]) {
            final path = getEvolutionMoodImagePath(type, stage, mood);
            expect(path, isNotNull);
            expect(path, startsWith('assets/'));
            expect(path, endsWith('.png'));
          }
        }
      }
    });
  });

  group('getImageTypeString', () {
    test('모든 PetImageType에 대해 문자열 반환', () {
      for (final type in PetImageType.values) {
        expect(getImageTypeString(type), isNotEmpty);
      }
    });

    test('올바른 문자열 매핑', () {
      expect(getImageTypeString(PetImageType.feed), 'feed');
      expect(getImageTypeString(PetImageType.sleep), 'sleep');
      expect(getImageTypeString(PetImageType.exercise), 'exercise');
      expect(getImageTypeString(PetImageType.happy), 'happy');
      expect(getImageTypeString(PetImageType.bored), 'bored');
      expect(getImageTypeString(PetImageType.anxious), 'anxious');
      expect(getImageTypeString(PetImageType.full), 'full');
      expect(getImageTypeString(PetImageType.sad), 'sad');
    });
  });
}
