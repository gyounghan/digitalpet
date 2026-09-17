import 'skill_effect_data.dart' show skillNameToEffect;

/// 이펙트 키 → 부드러운 투사체 이미지 경로 (도트 대신).
/// 등록되지 않은 키는 기존 도트 스프라이트로 폴백한다.
const Map<String, String> _projectileImages = {
  'strike': 'assets/effects/energy_orb.png',
  'slash': 'assets/effects/claw_slash.png',
  'fire': 'assets/effects/ghost_flame.png',
  'slam': 'assets/effects/boulder.png',
  'water': 'assets/effects/water_blast.png',
  'gust': 'assets/effects/wind_blade.png',
  'moon': 'assets/effects/full_moon.png',
  'mochi': 'assets/effects/mochi.png',
  'club': 'assets/effects/spiked_club.png',
  'horn': 'assets/effects/horn_charge.png',
};

/// 스킬 이름 → 투사체 이미지 경로 (없으면 null → 도트 폴백)
String? skillProjectileImageForSkillName(String skillName) {
  final key = skillNameToEffect[skillName];
  return key == null ? null : _projectileImages[key];
}
