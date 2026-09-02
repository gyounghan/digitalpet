import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/app_prefs_datasource.dart';

/// 첫 번째(기본) 펫 ID — 온보딩·백그라운드가 쓰는 기존 값.
const String kDefaultPetId = 'default-pet';

/// 두 번째 펫 ID (2마리 키우기 v1).
const String kSecondPetId = 'pet-2';

/// 최대 동시 육성 펫 수 (v1: 2, 이후 확장 여지).
const int kMaxPets = 2;

/// 슬롯 순서 — 도감 수집 그리드가 이 순서로 펫/빈칸을 그린다.
const List<String> kPetSlotIds = [kDefaultPetId, kSecondPetId];

/// 앞화면(홈·케어·배틀·도감)이 현재 보여주는 활성 펫 ID.
///
/// prefs에 저장돼 앱 재시작 후에도 유지된다. 최초 프레임은 [kDefaultPetId]로
/// 시작하고, prefs 로드가 끝나면 저장된 값으로 갱신된다(있으면).
/// 위젯/백그라운드/서버 동기화는 이 활성 펫 기준으로 동작한다(v1 — 백그라운드
/// 능동 처리는 활성 펫 1마리).
class ActivePetNotifier extends StateNotifier<String> {
  final AppPrefsDatasource _prefs;

  ActivePetNotifier(this._prefs) : super(kDefaultPetId) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _prefs.getActivePetId();
    if (saved != null && saved.isNotEmpty && saved != state) {
      state = saved;
    }
  }

  /// 활성 펫 전환 (도감 수집 그리드에서 호출) — 즉시 반영 + prefs 저장.
  Future<void> setActive(String petId) async {
    if (petId == state) return;
    state = petId;
    await _prefs.setActivePetId(petId);
  }
}

final activePetIdProvider =
    StateNotifierProvider<ActivePetNotifier, String>((ref) {
  return ActivePetNotifier(AppPrefsDatasource());
});
