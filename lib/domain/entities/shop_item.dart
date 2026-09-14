/// 상점 아이템 효과 종류 (소비형 — 즉시 적용)
enum ShopItemEffect {
  /// 간식 — 포만감·행복 회복
  snack,

  /// 에너지 드링크 — 기력 회복
  energy,

  /// 추가 대전권 — 오늘 AI 대전 가능 횟수 +1
  battleTicket,

  /// 부활의 물 — 긴 잠(사망)에 빠진 펫을 완전 회복
  revive,
}

/// 상점 판매 아이템 (코인 소비형)
class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final ShopItemEffect effect;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.effect,
  });
}

/// 상점 카탈로그 — 코인으로 살 수 있는 소비 아이템 목록.
/// 효과는 모두 기존 펫 수치/필드에 매핑되어 새 아트 없이 동작한다.
const List<ShopItem> shopCatalog = [
  ShopItem(
    id: 'snack',
    name: '간식',
    description: '포만감 +30, 행복 +10',
    price: 30,
    effect: ShopItemEffect.snack,
  ),
  ShopItem(
    id: 'energy',
    name: '에너지 드링크',
    description: '기력 +40',
    price: 40,
    effect: ShopItemEffect.energy,
  ),
  ShopItem(
    id: 'battle_ticket',
    name: '추가 대전권',
    description: '오늘 AI 대전 +1회',
    price: 50,
    effect: ShopItemEffect.battleTicket,
  ),
  ShopItem(
    id: 'revive',
    name: '부활의 물',
    description: '긴 잠에 빠진 펫을 완전 회복',
    price: 120,
    effect: ShopItemEffect.revive,
  ),
];
