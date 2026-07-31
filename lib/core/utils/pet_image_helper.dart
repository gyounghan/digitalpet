import '../../domain/entities/pet.dart';
import '../../domain/entities/evolution_type.dart';
import '../../presentation/widgets/pet_image_animation.dart';

/// EvolutionType을 이미지 파일 접두어로 변환
/// snake 계열은 dragon 이미지를 사용 (뱀→이무기→청룡)
const Map<EvolutionType, String> _evolutionImagePrefix = {
  EvolutionType.bird: 'bird',
  EvolutionType.snake: 'dragon',
  EvolutionType.tiger: 'tiger',
  EvolutionType.turtle: 'turtle',
};

/// EvolutionType의 이미지 파일 접두어(종 키) 반환
///
/// 도트 모션 데이터(motionFrames)의 스프라이트 키 접두어와 동일하다.
/// snake → 'dragon' (뱀→이무기→청룡 이미지 공유)
String? evolutionSpeciesImagePrefix(EvolutionType? type) {
  if (type == null) return null;
  return _evolutionImagePrefix[type];
}

/// 진화 타입과 단계에 따른 정적 대표 이미지 경로 반환
///
/// stage 1 → 기본이미지.png (털뭉치)
/// stage 2 → type1.png (아기 형태)
/// stage 3 → type2.png (일반/상위)
/// stage 4 → type3.png (신수)
///
/// 주의: stage 2+ 에서 mood 기반 애니메이션을 사용하려면
/// [getEvolutionMoodImagePaths] 를 사용한다. 이 함수는 fallback / 대표 썸네일용.
String? getEvolutionImagePath(EvolutionType? type, int evolutionStage) {
  // stage 1은 항상 털뭉치 이미지
  if (evolutionStage <= 1) return 'assets/기본이미지.png';
  if (type == null) return 'assets/기본이미지.png';
  final prefix = _evolutionImagePrefix[type];
  if (prefix == null) return 'assets/기본이미지.png';
  // stage 2→1, stage 3→2, stage 4→3
  final imageIndex = (evolutionStage - 1).clamp(1, 3);
  return 'assets/$prefix$imageIndex.png';
}

/// 진화 타입과 mood에 따른 정적 mood 이미지 경로 반환
///
/// stage 2 이상에서 종족별 mood 이미지 1장(정적)을 사용한다.
/// 이미지 인덱스는 진화 단계와 1:1 대응:
///   - stage 2 (유아기) → {prefix}_{mood}1.png
///   - stage 3 (성장기) → {prefix}_{mood}2.png
///   - stage 4 (어른)   → {prefix}_{mood}3.png
///   - stage 5+ → 3으로 clamp
///
/// stage 1에서는 null을 반환하여 기본 mood 애니메이션으로 폴백한다.
///
/// 매핑 규칙 (mood 6종):
/// - happy → smile
/// - normal → exercise
/// - hungry → hungry
/// - sleepy → sleepy
/// - tired → sleep
/// - sad → sad, dead(긴 잠) → sleep
String? getEvolutionMoodImagePath(
  EvolutionType? type,
  int evolutionStage,
  PetMood mood,
) {
  if (evolutionStage <= 1) return null;
  if (type == null) return null;
  final prefix = _evolutionImagePrefix[type];
  if (prefix == null) return null;

  final moodSuffix = _getMoodImageSuffix(mood);
  // stage 2 → 1, stage 3 → 2, stage 4 → 3, 5+ → 3
  final stageIndex = (evolutionStage - 1).clamp(1, 3);
  return 'assets/${prefix}_$moodSuffix$stageIndex.png';
}

/// PetMood를 이미지 파일 mood suffix로 변환
///
/// 자산 파일명 규칙: {prefix}_{moodSuffix}{1|2|3}.png
String _getMoodImageSuffix(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return 'smile';
    case PetMood.normal:
      return 'exercise';
    case PetMood.hungry:
      return 'hungry';
    case PetMood.sleepy:
      return 'sleepy';
    case PetMood.tired:
      return 'sleep';
    case PetMood.sad:
      return 'sad';
    case PetMood.dead:
      // 긴 잠 컨셉 — 잠자는 모습으로 표현
      return 'sleep';
  }
}

/// PetMood를 PetImageType으로 변환하는 헬퍼 함수
///
/// 펫의 기분 상태에 따라 적절한 이미지 타입을 반환
///
/// 매핑 규칙 (mood 6종):
/// - happy → happy
/// - normal → exercise
/// - hungry → hungry (배고파하는 전용 프레임)
/// - sleepy/tired → sleep
/// - sad → sad, dead(긴 잠) → sleep
PetImageType getPetImageTypeFromMood(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return PetImageType.happy;
    case PetMood.normal:
      return PetImageType.exercise;
    case PetMood.hungry:
      return PetImageType.hungry;
    case PetMood.sleepy:
      return PetImageType.sleep;
    case PetMood.tired:
      return PetImageType.sleep;
    case PetMood.sad:
      return PetImageType.sad;
    case PetMood.dead:
      // 긴 잠 컨셉 — 잠자는 모습으로 표현
      return PetImageType.sleep;
  }
}

/// PetImageType을 문자열로 변환
///
/// 위젯 서비스에서 사용하기 위한 변환 함수
String getImageTypeString(PetImageType imageType) {
  switch (imageType) {
    case PetImageType.feed:
      return 'feed';
    case PetImageType.sleep:
      return 'sleep';
    case PetImageType.exercise:
      return 'exercise';
    case PetImageType.happy:
      return 'happy';
    case PetImageType.bored:
      return 'bored';
    case PetImageType.anxious:
      return 'anxious';
    case PetImageType.full:
      return 'full';
    case PetImageType.sad:
      return 'sad';
    case PetImageType.hungry:
      return 'hungry';
  }
}

/// PetMood를 문자열로 변환 (이미 PetMood.name이 있지만 일관성을 위해)
String getMoodString(PetMood mood) {
  return mood.name;
}
