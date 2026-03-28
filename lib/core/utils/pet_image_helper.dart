import '../../domain/entities/pet.dart';
import '../../presentation/widgets/pet_image_animation.dart';

/// PetMood를 PetImageType으로 변환하는 헬퍼 함수
/// 
/// 펫의 기분 상태에 따라 적절한 이미지 타입을 반환
/// 
/// 매핑 규칙:
/// - hungry → feed
/// - sleepy/tired → sleep
/// - bored → bored
/// - anxious → anxious
/// - full/satisfied → full
/// - happy → happy
/// - energetic → exercise
/// - normal → exercise
PetImageType getPetImageTypeFromMood(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return PetImageType.happy;
    case PetMood.sleepy:
      return PetImageType.sleep;
    case PetMood.hungry:
      return PetImageType.feed;
    case PetMood.bored:
      return PetImageType.bored;
    case PetMood.normal:
      return PetImageType.exercise;
    case PetMood.energetic:
      return PetImageType.exercise;
    case PetMood.tired:
      return PetImageType.sleep;
    case PetMood.full:
      return PetImageType.full;
    case PetMood.anxious:
      return PetImageType.anxious;
    case PetMood.satisfied:
      return PetImageType.full;
    case PetMood.dead:
      return PetImageType.sad;
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
  }
}

/// PetMood를 문자열로 변환 (이미 PetMood.name이 있지만 일관성을 위해)
String getMoodString(PetMood mood) {
  return mood.name;
}
