import '../../domain/entities/pet.dart';
import '../../presentation/widgets/pet_image_animation.dart';

/// PetMood를 PetImageType으로 변환하는 헬퍼 함수
/// 
/// 펫의 기분 상태에 따라 적절한 이미지 타입을 반환
/// 
/// 매핑 규칙:
/// - happy → normal (기쁜 애니메이션, 추후 추가 가능)
/// - sleepy → sleeping
/// - hungry → hungry
/// - bored → normal (지루한 애니메이션, 추후 추가 가능)
/// - normal → normal
/// - energetic → normal (활기참 애니메이션, 추후 추가 가능)
/// - tired → sleeping (피곤함은 수면 이미지 사용)
/// - full → normal (배부름은 normal 이미지 사용)
/// - anxious → normal (불안함은 normal 이미지 사용)
/// - satisfied → normal (만족함은 normal 이미지 사용)
PetImageType getPetImageTypeFromMood(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return PetImageType.normal;
    case PetMood.sleepy:
      return PetImageType.sleeping;
    case PetMood.hungry:
      return PetImageType.hungry;
    case PetMood.bored:
      return PetImageType.normal;
    case PetMood.normal:
      return PetImageType.normal;
    case PetMood.energetic:
      return PetImageType.normal;
    case PetMood.tired:
      return PetImageType.sleeping;
    case PetMood.full:
      return PetImageType.normal;
    case PetMood.anxious:
      return PetImageType.normal;
    case PetMood.satisfied:
      return PetImageType.normal;
  }
}

/// PetImageType을 문자열로 변환
/// 
/// 위젯 서비스에서 사용하기 위한 변환 함수
String getImageTypeString(PetImageType imageType) {
  switch (imageType) {
    case PetImageType.normal:
      return 'normal';
    case PetImageType.sleeping:
      return 'sleeping';
    case PetImageType.hungry:
      return 'hungry';
  }
}

/// PetMood를 문자열로 변환 (이미 PetMood.name이 있지만 일관성을 위해)
String getMoodString(PetMood mood) {
  return mood.name;
}
