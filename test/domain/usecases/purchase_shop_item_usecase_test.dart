import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/entities/shop_item.dart';
import 'package:pocketfriend/domain/usecases/purchase_shop_item_usecase.dart';

Pet _pet({int coins = 100, bool isDead = false, int hunger = 40, int stamina = 40}) {
  return Pet(
    id: 'p',
    name: '테스트',
    hunger: hunger,
    happiness: 40,
    stamina: stamina,
    exp: 0,
    level: 5,
    evolutionStage: 2,
    lastUpdated: 0,
    lastStatusDecayUpdated: 0,
    coins: coins,
    isDead: isDead,
  );
}

ShopItem _item(String id) => shopCatalog.firstWhere((e) => e.id == id);

void main() {
  const usecase = PurchaseShopItemUseCase();

  test('코인이 충분하면 구매 성공 + 가격만큼 차감', () {
    final r = usecase(_pet(coins: 100), _item('snack'));
    expect(r.success, isTrue);
    expect(r.pet!.coins, 100 - 30);
  });

  test('코인이 부족하면 실패 + 사유', () {
    final r = usecase(_pet(coins: 10), _item('snack'));
    expect(r.success, isFalse);
    expect(r.failureReason, isNotNull);
  });

  test('간식은 포만감 +30, 행복 +10 (상한 100)', () {
    final r = usecase(_pet(coins: 100, hunger: 40), _item('snack'));
    expect(r.pet!.hunger, 70);
    expect(r.pet!.happiness, 50);
  });

  test('에너지 드링크는 기력 +40', () {
    final r = usecase(_pet(coins: 100, stamina: 40), _item('energy'));
    expect(r.pet!.stamina, 80);
  });

  test('추가 대전권은 todayBattleAdBonus +1', () {
    final r = usecase(_pet(coins: 100), _item('battle_ticket'));
    expect(r.pet!.todayBattleAdBonus, 1);
  });

  test('부활의 물은 사망 상태에서만 가능', () {
    final alive = usecase(_pet(coins: 200, isDead: false), _item('revive'));
    expect(alive.success, isFalse);

    final dead = usecase(_pet(coins: 200, isDead: true), _item('revive'));
    expect(dead.success, isTrue);
    expect(dead.pet!.isDead, isFalse);
    expect(dead.pet!.coins, 200 - 120);
  });

  test('사망 상태에서는 회복 아이템을 살 수 없다 (부활 먼저)', () {
    final r = usecase(_pet(coins: 100, isDead: true), _item('snack'));
    expect(r.success, isFalse);
  });
}
