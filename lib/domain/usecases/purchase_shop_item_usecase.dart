import '../entities/pet.dart';
import '../entities/shop_item.dart';

/// 상점 구매 결과
class PurchaseResult {
  final bool success;

  /// 실패 사유 (성공 시 null) — UI 스낵바 메시지로 사용
  final String? failureReason;

  /// 성공 시 코인 차감·효과가 적용된 새 Pet (저장은 호출부가 담당)
  final Pet? pet;

  const PurchaseResult({
    required this.success,
    this.failureReason,
    this.pet,
  });
}

/// 상점 아이템 구매 유스케이스 — 순수 함수.
///
/// 저장/위젯 동기화는 호출부(PetNotifier)가 `_updateAndEvolve`로 처리한다.
/// 여기서는 코인 검증·차감·효과 적용만 담당해 테스트가 쉽다.
class PurchaseShopItemUseCase {
  const PurchaseShopItemUseCase();

  PurchaseResult call(Pet pet, ShopItem item) {
    if (pet.coins < item.price) {
      return const PurchaseResult(success: false, failureReason: '코인이 부족해요');
    }
    // 부활은 사망 상태에서만 의미가 있다
    if (item.effect == ShopItemEffect.revive && !pet.isDead) {
      return const PurchaseResult(
          success: false, failureReason: '펫이 건강해요');
    }
    // 소비형(회복) 아이템은 사망 상태에서 쓸 수 없다 (부활 먼저)
    if (item.effect != ShopItemEffect.revive && pet.isDead) {
      return const PurchaseResult(
          success: false, failureReason: '긴 잠에 빠진 펫에겐 쓸 수 없어요');
    }

    final applied = _applyEffect(pet, item).copyWith(coins: pet.coins - item.price);
    return PurchaseResult(success: true, pet: applied);
  }

  Pet _applyEffect(Pet pet, ShopItem item) {
    switch (item.effect) {
      case ShopItemEffect.snack:
        return pet.copyWith(
          hunger: (pet.hunger + 30).clamp(0, 100),
          happiness: (pet.happiness + 10).clamp(0, 100),
        );
      case ShopItemEffect.energy:
        return pet.copyWith(stamina: (pet.stamina + 40).clamp(0, 100));
      case ShopItemEffect.battleTicket:
        return pet.copyWith(todayBattleAdBonus: pet.todayBattleAdBonus + 1);
      case ShopItemEffect.revive:
        return pet.wakeUp(fullRecovery: true);
    }
  }
}
