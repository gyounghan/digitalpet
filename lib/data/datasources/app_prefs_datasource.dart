import 'package:shared_preferences/shared_preferences.dart';

/// 가벼운 앱 플래그 저장소 (SharedPreferences)
///
/// 펫 데이터(Hive)와 달리 "이 기기에서 이 화면을 봤는가" 성격의
/// 1회성 플래그만 보관한다. 펫을 새로 키워도 유지되는 것이 맞는 값들.
class AppPrefsDatasource {
  static const String _keyOnboardingDone = 'onboarding_done';
  static const String _keySpeciesRevealShown = 'species_reveal_shown';

  /// 온보딩(이름 짓기 → 권한 → 첫 목표 → 위젯 유도) 완료 여부
  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingDone) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, true);
  }

  /// 종 결정(2단계 진화) 풀스크린 연출을 이미 보여줬는지 여부
  Future<bool> isSpeciesRevealShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySpeciesRevealShown) ?? false;
  }

  Future<void> setSpeciesRevealShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeciesRevealShown, true);
  }
}
