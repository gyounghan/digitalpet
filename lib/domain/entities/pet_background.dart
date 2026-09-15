/// 홈 펫 무대에 까는 배경 테마 (꾸미기).
class PetBackground {
  final String id;
  final String name;
  final String assetPath;

  const PetBackground({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

/// 기본(그라데이션) 배경 id — [Pet.equippedBackground]가 이 값이거나 비면 기본.
const String kDefaultBackgroundId = '';

/// 선택 가능한 배경 목록. 첫 항목은 기본(에셋 없음).
const List<PetBackground> backgroundCatalog = [
  PetBackground(id: kDefaultBackgroundId, name: '기본', assetPath: ''),
  PetBackground(
    id: 'forest_pond',
    name: '숲속 연못',
    assetPath: 'assets/backgrounds/forest_pond.png',
  ),
  PetBackground(
    id: 'cozy_room',
    name: '아늑한 방',
    assetPath: 'assets/backgrounds/cozy_room.png',
  ),
];

/// id로 배경 조회 (없으면 기본). 에셋 경로가 비면 기본 그라데이션.
PetBackground backgroundForId(String? id) {
  for (final bg in backgroundCatalog) {
    if (bg.id == id) return bg;
  }
  return backgroundCatalog.first;
}
