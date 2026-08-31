import 'package:flutter/foundation.dart';

import '../../core/theme/species_theme.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/wild_encounter.dart';
import '../../domain/usecases/species_reveal_narrator.dart';
import '../../domain/usecases/wild_encounter_spawner.dart';
import '../datasources/wild_encounter_datasource.dart';
import 'notification_service.dart';

/// 야생 조우 오케스트레이션 — 스폰 판정 + 저장 + 알림
///
/// 포그라운드 틱(5분)·앱 전환·백그라운드 워커(15분) 어디서 불려도
/// 안전하도록 멱등하게 동작한다: 하루 1회만 굴리고, 대기 조우가 있으면
/// 그대로 반환한다.
class WildEncounterService {
  final WildEncounterDatasource datasource;
  final NotificationService notificationService;

  WildEncounterService({
    WildEncounterDatasource? datasource,
    NotificationService? notificationService,
  })  : datasource = datasource ?? WildEncounterDatasource(),
        notificationService = notificationService ?? NotificationService();

  /// 조우 스폰 시도 — 새로 등장했을 때만 WildEncounter 반환 (알림 발송)
  ///
  /// 이미 대기 중이거나 오늘 굴림을 소진했으면 null.
  Future<WildEncounter?> maybeSpawn(Pet pet, {bool notify = true}) async {
    try {
      final pending = await datasource.getPending();
      if (pending != null) return null; // 이미 기다리는 중

      if (!WildEncounterSpawner.isEligible(pet)) return null;

      final today = pet.todayDateString;
      if (await datasource.getLastRollDate() == today) return null;

      // 결과와 무관하게 오늘 굴림 소진 (등장 실패 = 오늘은 못 만남)
      await datasource.setLastRollDate(today);

      final encounter = WildEncounterSpawner.roll(pet);
      if (encounter == null) return null;

      await datasource.savePending(encounter);

      if (notify) {
        final label = SpeciesTheme.labelFor(encounter.species);
        final particle = SpeciesRevealNarrator.objectParticle(label);
        await notificationService.showNotification(
          title: '부스럭... 야생의 기척!',
          body: '산책하다 야생의 $label$particle 만났어! 나랑 같이 겨뤄볼래?',
        );
      }
      return encounter;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WildEncounterService.maybeSpawn failed: $e');
      }
      return null;
    }
  }
}
