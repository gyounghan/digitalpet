import '../entities/pet.dart';

/// 놀아주기 유스케이스 — 순수 함수.
///
/// 미니게임(하트 탭) 점수를 행복도로 환산해 적용한다. 행복은 100 상한이라
/// 자연 상한이 걸려 별도 일일 제한이 없어도 무한 farming이 되지 않는다.
/// 저장/위젯 동기화는 호출부(PetNotifier)가 `_updateAndEvolve`로 처리.
class PlayWithPetUseCase {
  const PlayWithPetUseCase();

  /// 탭당 행복 환산량
  static const int happinessPerHit = 2;

  /// [hits]번 맞힌 결과를 행복도에 반영한 새 Pet 반환.
  /// 사망(긴 잠) 상태에서는 변화 없음.
  Pet call(Pet pet, int hits) {
    if (pet.isDead || hits <= 0) return pet;
    final gain = hits * happinessPerHit;
    return pet.copyWith(happiness: (pet.happiness + gain).clamp(0, 100));
  }
}
