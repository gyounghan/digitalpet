import '../entities/pet.dart';
import 'create_default_pet_usecase.dart';

/// 펫 초기화(새로 키우기) 유스케이스
/// 기존 펫 데이터를 기본값으로 덮어써 처음부터 다시 키운다. (광고 시청 후 호출)
///
/// 동작:
/// - 기존 펫의 레벨/진화/누적 기록을 모두 버리고 1단계 털뭉치 기본 펫으로 교체
/// - 기본 펫 생성 로직은 [CreateDefaultPetUseCase]를 재사용해 중복을 방지
class ResetPetUseCase {
  final CreateDefaultPetUseCase createDefaultPetUseCase;

  ResetPetUseCase(this.createDefaultPetUseCase);

  /// 펫을 기본값으로 초기화
  ///
  /// [petId] 초기화할 반려동물 ID
  ///
  /// 반환: 새로 생성된 기본 Pet 엔티티
  Future<Pet> call(String petId) => createDefaultPetUseCase(petId);
}
