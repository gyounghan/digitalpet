import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pet.dart';
import '../../domain/repositories/pet_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/update_pet_state_usecase.dart';
import '../../domain/usecases/feed_pet_usecase.dart';
import '../../domain/usecases/sleep_pet_usecase.dart';
import '../../domain/usecases/create_default_pet_usecase.dart';
import '../../domain/usecases/evolve_pet_usecase.dart';
import '../../domain/usecases/check_notification_usecase.dart';
import '../../data/repository/pet_repository_impl.dart';
import '../../data/repository/notification_repository_impl.dart';
import '../../data/datasource/pet_local_datasource.dart';
import '../../data/datasource/notification_local_datasource.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/widget_service.dart';
import '../../domain/services/pet_state_service.dart';
import '../../domain/repositories/phone_usage_repository.dart';
import '../../domain/usecases/auto_sleep_pet_usecase.dart';
import '../../domain/usecases/detect_phone_idle_usecase.dart';
import '../../domain/usecases/update_pet_from_activity_usecase.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../data/repositories/phone_usage_repository_impl.dart';
import '../../data/datasources/phone_usage_datasource.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../data/datasources/health_datasource.dart';
import '../../data/datasources/step_sensor_datasource.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart';
import '../../domain/usecases/award_battle_reward_usecase.dart';
import '../../domain/usecases/can_feed_pet_usecase.dart';
import '../../domain/repositories/battle_history_repository.dart';
import '../../data/repositories/battle_history_repository_impl.dart';
import '../../data/datasources/battle_history_datasource.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../domain/usecases/apply_daily_goals_score_usecase.dart';
import '../../domain/usecases/update_pet_name_usecase.dart';
import '../../domain/usecases/alternative_feed_pet_usecase.dart';
import '../../domain/usecases/alternative_sleep_pet_usecase.dart';
import '../../domain/usecases/shake_step_bonus_usecase.dart';
import '../../domain/usecases/check_pet_death_usecase.dart';
import '../../domain/usecases/resurrect_pet_usecase.dart';
import '../../domain/usecases/reset_pet_usecase.dart';
import '../../domain/usecases/login_bonus_usecase.dart';
import '../../domain/usecases/sync_pet_usecase.dart';
import '../../domain/repositories/pet_remote_repository.dart';
import '../../data/repositories/pet_remote_repository_impl.dart';
import '../../data/datasources/pet_remote_datasource.dart';
import '../../data/datasources/device_id_datasource.dart';
import '../../data/datasources/ranking_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// PetLocalDataSource Provider
/// Hive 데이터소스 인스턴스를 제공
final petLocalDataSourceProvider = Provider<PetLocalDataSource>((ref) {
  return PetLocalDataSource();
});

/// PetRepository Provider
/// Repository 인스턴스를 제공
final petRepositoryProvider = Provider<PetRepository>((ref) {
  final dataSource = ref.watch(petLocalDataSourceProvider);
  return PetRepositoryImpl(dataSource);
});

/// UpdatePetStateUseCase Provider
/// 상태 업데이트 유스케이스 인스턴스를 제공
final updatePetStateUseCaseProvider = Provider<UpdatePetStateUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return UpdatePetStateUseCase(repository);
});

/// FeedPetUseCase Provider
/// 먹이 주기 유스케이스 인스턴스를 제공
final feedPetUseCaseProvider = Provider<FeedPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return FeedPetUseCase(repository);
});

/// SleepPetUseCase Provider
/// 재우기 유스케이스 인스턴스를 제공
final sleepPetUseCaseProvider = Provider<SleepPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return SleepPetUseCase(repository);
});

/// CreateDefaultPetUseCase Provider
/// 기본 Pet 생성 유스케이스 인스턴스를 제공
final createDefaultPetUseCaseProvider = Provider<CreateDefaultPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return CreateDefaultPetUseCase(repository);
});

/// EvolvePetUseCase Provider
/// 진화 유스케이스 인스턴스를 제공
final evolvePetUseCaseProvider = Provider<EvolvePetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return EvolvePetUseCase(repository);
});

/// NotificationLocalDataSource Provider
/// 알림 데이터소스 인스턴스를 제공
final notificationLocalDataSourceProvider = Provider<NotificationLocalDataSource>((ref) {
  return NotificationLocalDataSource();
});

/// NotificationRepository Provider
/// 알림 저장소 인스턴스를 제공
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationLocalDataSourceProvider);
  return NotificationRepositoryImpl(dataSource);
});

/// CheckNotificationUseCase Provider
/// 알림 체크 유스케이스 인스턴스를 제공
final checkNotificationUseCaseProvider = Provider<CheckNotificationUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return CheckNotificationUseCase(
    petRepository: petRepository,
    notificationRepository: notificationRepository,
  );
});

/// NotificationService Provider
/// 알림 서비스 인스턴스를 제공
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// PetStateService Provider
/// 펫 상태 서비스 인스턴스를 제공
final petStateServiceProvider = Provider<PetStateService>((ref) {
  final useCase = ref.watch(updatePetStateUseCaseProvider);
  return PetStateService(useCase);
});

/// WidgetService Provider
/// 홈 화면 위젯 서비스 인스턴스를 제공
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService();
});

/// PhoneUsageDataSource Provider
/// 폰 사용 상태 데이터소스 인스턴스를 제공
final phoneUsageDataSourceProvider = Provider<PhoneUsageDataSource>((ref) {
  return PhoneUsageDataSource();
});

/// PhoneUsageRepository Provider
/// 폰 사용 상태 저장소 인스턴스를 제공
final phoneUsageRepositoryProvider = Provider<PhoneUsageRepository>((ref) {
  final dataSource = ref.watch(phoneUsageDataSourceProvider);
  return PhoneUsageRepositoryImpl(dataSource);
});

/// DetectPhoneIdleUseCase Provider
/// 폰 미사용 감지 유스케이스 인스턴스를 제공
final detectPhoneIdleUseCaseProvider = Provider<DetectPhoneIdleUseCase>((ref) {
  final repository = ref.watch(phoneUsageRepositoryProvider);
  return DetectPhoneIdleUseCase(repository);
});

/// AutoSleepPetUseCase Provider
/// 자동 펫 재우기 유스케이스 인스턴스를 제공
final autoSleepPetUseCaseProvider = Provider<AutoSleepPetUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final phoneUsageRepository = ref.watch(phoneUsageRepositoryProvider);
  return AutoSleepPetUseCase(
    petRepository: petRepository,
    phoneUsageRepository: phoneUsageRepository,
  );
});

/// HealthDataSource Provider
/// 헬스케어 데이터소스 인스턴스를 제공
final healthDataSourceProvider = Provider<HealthDataSource>((ref) {
  return HealthDataSource();
});

/// StepSensorDatasource Provider
/// Android 내장 걸음수 센서 인스턴스를 제공
final stepSensorDatasourceProvider = Provider<StepSensorDatasource>((ref) {
  return StepSensorDatasource();
});

/// ActivityRepository Provider
/// 걸음수: 내장 센서 우선 → Health Connect 폴백
/// 운동 데이터: Health Connect에서만 조회
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final healthDataSource = ref.watch(healthDataSourceProvider);
  final stepSensorDatasource = ref.watch(stepSensorDatasourceProvider);
  return ActivityRepositoryImpl(
    healthDataSource: healthDataSource,
    stepSensorDatasource: stepSensorDatasource,
  );
});

/// DeviceIdDatasource Provider
final deviceIdDatasourceProvider = Provider<DeviceIdDatasource>((ref) {
  return DeviceIdDatasource();
});

/// PetRemoteDatasource Provider
final petRemoteDatasourceProvider = Provider<PetRemoteDatasource>((ref) {
  return PetRemoteDatasource();
});

/// PetRemoteRepository Provider
final petRemoteRepositoryProvider = Provider<PetRemoteRepository>((ref) {
  final remoteDatasource = ref.watch(petRemoteDatasourceProvider);
  final deviceIdDatasource = ref.watch(deviceIdDatasourceProvider);
  return PetRemoteRepositoryImpl(
    remoteDatasource: remoteDatasource,
    deviceIdDatasource: deviceIdDatasource,
  );
});

/// RankingRemoteDatasource Provider
final rankingRemoteDatasourceProvider = Provider<RankingRemoteDatasource>((ref) {
  return RankingRemoteDatasource();
});

/// SyncPetUseCase Provider
final syncPetUseCaseProvider = Provider<SyncPetUseCase>((ref) {
  final localRepository = ref.watch(petRepositoryProvider);
  final remoteRepository = ref.watch(petRemoteRepositoryProvider);
  return SyncPetUseCase(
    localRepository: localRepository,
    remoteRepository: remoteRepository,
  );
});

/// UpdatePetFromActivityUseCase Provider
/// 활동 데이터 기반 펫 상태 업데이트 유스케이스 인스턴스를 제공
final updatePetFromActivityUseCaseProvider = Provider<UpdatePetFromActivityUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final activityRepository = ref.watch(activityRepositoryProvider);
  return UpdatePetFromActivityUseCase(
    petRepository: petRepository,
    activityRepository: activityRepository,
  );
});

/// BattleHistoryDataSource Provider
/// 대결 전적 데이터소스 인스턴스를 제공
final battleHistoryDataSourceProvider = Provider<BattleHistoryDataSource>((ref) {
  return BattleHistoryDataSource();
});

/// BattleHistoryRepository Provider
/// 대결 전적 저장소 인스턴스를 제공
final battleHistoryRepositoryProvider = Provider<BattleHistoryRepository>((ref) {
  final dataSource = ref.watch(battleHistoryDataSourceProvider);
  return BattleHistoryRepositoryImpl(dataSource);
});

/// BattleWithActivityUseCase Provider
/// 활동 기반 대결 유스케이스 인스턴스를 제공
final battleWithActivityUseCaseProvider = Provider<BattleWithActivityUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final activityRepository = ref.watch(activityRepositoryProvider);
  final battleHistoryRepository = ref.watch(battleHistoryRepositoryProvider);
  return BattleWithActivityUseCase(
    petRepository: petRepository,
    activityRepository: activityRepository,
    battleHistoryRepository: battleHistoryRepository,
  );
});

/// AwardBattleRewardUseCase Provider
/// 온라인 배틀 보상 로컬 지급 유스케이스 인스턴스를 제공
final awardBattleRewardUseCaseProvider = Provider<AwardBattleRewardUseCase>((ref) {
  return AwardBattleRewardUseCase(
    petRepository: ref.watch(petRepositoryProvider),
    battleHistoryRepository: ref.watch(battleHistoryRepositoryProvider),
  );
});

/// CanFeedPetUseCase Provider
/// Feed 가능 여부 체크 유스케이스 인스턴스를 제공
final canFeedPetUseCaseProvider = Provider<CanFeedPetUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  return CanFeedPetUseCase(petRepository);
});

/// CalculateDailyGoalsScoreUseCase Provider
/// 일일 목표 점수 계산 유스케이스 인스턴스를 제공
final calculateDailyGoalsScoreUseCaseProvider = Provider<CalculateDailyGoalsScoreUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final activityRepository = ref.watch(activityRepositoryProvider);
  return CalculateDailyGoalsScoreUseCase(
    petRepository: petRepository,
    activityRepository: activityRepository,
  );
});

/// ApplyDailyGoalsScoreUseCase Provider
/// 일일 목표 점수 적용 유스케이스 인스턴스를 제공
final applyDailyGoalsScoreUseCaseProvider = Provider<ApplyDailyGoalsScoreUseCase>((ref) {
  final petRepository = ref.watch(petRepositoryProvider);
  final calculateScoreUseCase = ref.watch(calculateDailyGoalsScoreUseCaseProvider);
  return ApplyDailyGoalsScoreUseCase(
    petRepository: petRepository,
    calculateScoreUseCase: calculateScoreUseCase,
  );
});

/// UpdatePetNameUseCase Provider
/// 펫 이름 변경 유스케이스 인스턴스를 제공
final updatePetNameUseCaseProvider = Provider<UpdatePetNameUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return UpdatePetNameUseCase(repository);
});

/// AlternativeFeedPetUseCase Provider
/// 대체 급식 유스케이스 인스턴스를 제공
final alternativeFeedPetUseCaseProvider = Provider<AlternativeFeedPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return AlternativeFeedPetUseCase(repository);
});

/// AlternativeSleepPetUseCase Provider
/// 대체 수면 유스케이스 인스턴스를 제공
final alternativeSleepPetUseCaseProvider = Provider<AlternativeSleepPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return AlternativeSleepPetUseCase(repository);
});

/// ShakeStepBonusUseCase Provider
/// 폰 흔들기 → 걸음 보너스 유스케이스 인스턴스를 제공
final shakeStepBonusUseCaseProvider = Provider<ShakeStepBonusUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return ShakeStepBonusUseCase(repository);
});

/// LoginBonusUseCase Provider
final loginBonusUseCaseProvider = Provider<LoginBonusUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return LoginBonusUseCase(repository);
});

/// CheckPetDeathUseCase Provider
/// 펫 사망 체크 유스케이스 인스턴스를 제공
final checkPetDeathUseCaseProvider = Provider<CheckPetDeathUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return CheckPetDeathUseCase(repository);
});

/// ResurrectPetUseCase Provider
/// 펫 부활 유스케이스 인스턴스를 제공
final resurrectPetUseCaseProvider = Provider<ResurrectPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return ResurrectPetUseCase(repository);
});

/// ResetPetUseCase Provider
/// 펫 초기화(새로 키우기) 유스케이스 인스턴스를 제공
final resetPetUseCaseProvider = Provider<ResetPetUseCase>((ref) {
  final createDefaultPetUseCase = ref.watch(createDefaultPetUseCaseProvider);
  return ResetPetUseCase(createDefaultPetUseCase);
});

/// Pet Provider
/// 특정 ID의 Pet을 조회하는 FutureProvider
/// 
/// [petId] 조회할 반려동물 ID (기본값: 'default-pet')
final petProvider = FutureProvider.family<Pet, String>((ref, petId) async {
  final repository = ref.watch(petRepositoryProvider);
  return await repository.getPet(petId);
});

/// Pet State Notifier
/// Pet 상태를 관리하는 StateNotifier
/// 
/// 앱 실행 시 자동으로 상태를 업데이트하고,
/// Feed/Play/Sleep 액션을 처리
class PetNotifier extends StateNotifier<AsyncValue<Pet>> {
  final PetRepository repository;
  final UpdatePetStateUseCase updatePetStateUseCase;
  final FeedPetUseCase feedPetUseCase;
  final SleepPetUseCase sleepPetUseCase;
  final CreateDefaultPetUseCase createDefaultPetUseCase;
  final EvolvePetUseCase evolvePetUseCase;
  final CheckNotificationUseCase checkNotificationUseCase;
  final NotificationService notificationService;
  final WidgetService widgetService;
  final PhoneUsageRepository phoneUsageRepository;
  final AutoSleepPetUseCase autoSleepPetUseCase;
  final DetectPhoneIdleUseCase detectPhoneIdleUseCase;
  final UpdatePetFromActivityUseCase updatePetFromActivityUseCase;
  final ApplyDailyGoalsScoreUseCase applyDailyGoalsScoreUseCase;
  final UpdatePetNameUseCase updatePetNameUseCase;
  final AlternativeFeedPetUseCase alternativeFeedPetUseCase;
  final AlternativeSleepPetUseCase alternativeSleepPetUseCase;
  final AwardBattleRewardUseCase awardBattleRewardUseCase;
  final ShakeStepBonusUseCase shakeStepBonusUseCase;
  final CheckPetDeathUseCase checkPetDeathUseCase;
  final ResurrectPetUseCase resurrectPetUseCase;
  final ResetPetUseCase resetPetUseCase;
  final LoginBonusUseCase loginBonusUseCase;
  final SyncPetUseCase syncPetUseCase;
  final String petId;

  PetNotifier({
    required this.repository,
    required this.updatePetStateUseCase,
    required this.feedPetUseCase,
    required this.sleepPetUseCase,
    required this.createDefaultPetUseCase,
    required this.evolvePetUseCase,
    required this.checkNotificationUseCase,
    required this.notificationService,
    required this.widgetService,
    required this.phoneUsageRepository,
    required this.autoSleepPetUseCase,
    required this.detectPhoneIdleUseCase,
    required this.updatePetFromActivityUseCase,
    required this.applyDailyGoalsScoreUseCase,
    required this.updatePetNameUseCase,
    required this.alternativeFeedPetUseCase,
    required this.alternativeSleepPetUseCase,
    required this.awardBattleRewardUseCase,
    required this.shakeStepBonusUseCase,
    required this.checkPetDeathUseCase,
    required this.resurrectPetUseCase,
    required this.resetPetUseCase,
    required this.loginBonusUseCase,
    required this.syncPetUseCase,
    required this.petId,
  }) : super(const AsyncValue.loading()) {
    _loadPet();
  }
  
  /// Pet 로드 및 상태 업데이트
  /// 
  /// 앱 실행 시 호출하여:
  /// 1. Hive에서 Pet 데이터 불러오기
  /// 2. 데이터 없으면 기본값으로 초기화
  /// 3. 시간 경과에 따른 상태 업데이트 수행
  Future<void> _loadPet() async {
    try {
      // 1. Pet 존재 여부 확인
      final petExists = await repository.hasPet(petId);
      
      if (!petExists) {
        // 2. 데이터 없으면 기본값으로 초기화
        await createDefaultPetUseCase(petId);
      }
      
      // 3. 마지막 접속 시간 업데이트 (앱 실행 시)
      await checkNotificationUseCase.updateLastAccessTime();

      // 4. 앱 비사용 시간 수면 반영(포그라운드 전환 전에 계산)
      await autoSleepPetUseCase(petId, isInBackground: true);

      // 5. 포그라운드 전환 처리 (다음 수면 계산 기준 시각 갱신)
      await phoneUsageRepository.onForeground();

      // 6. 시간 경과에 따른 상태 업데이트 (여기까지 로컬 Hive I/O만 — 빠름)
      final localPet = await updatePetStateUseCase(petId);

      // 로컬 상태로 홈을 먼저 렌더한다. 이후의 활동(헬스/센서 채널)과
      // 서버 동기화(HTTP 5초 타임아웃)는 콜드 스타트 스피너를 길게 잡으므로
      // 첫 페인트 이후 백그라운드로 미룬다.
      final evolvedPet = await _updateAndEvolve(localPet);
      state = AsyncValue.data(evolvedPet);

      // 7~9. 활동/접속보너스/서버동기화는 렌더를 막지 않고 뒤이어 반영
      unawaited(_loadDeferredUpdates());
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 첫 렌더를 막지 않는 후속 갱신 (네트워크/플랫폼 채널)
  ///
  /// 활동 데이터(헬스 커넥트·걸음수 센서), 접속 보너스, 서버 동기화를
  /// 순서대로 반영한다. 각 단계는 독립적으로 실패를 무시하며, 완료 후
  /// 진화 체크까지 마친 최신 상태로 [state]를 다시 내보낸다.
  /// (이미 로컬 상태가 화면에 떠 있으므로 전부 실패해도 무방)
  Future<void> _loadDeferredUpdates() async {
    var pet = await repository.getPet(petId);

    // 활동 데이터 기반 상태 업데이트 (걷기/운동량)
    try {
      pet = await updatePetFromActivityUseCase(petId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetNotifier._loadDeferredUpdates: activity failed: $e');
      }
    }

    // 접속 보너스 + 일일 이벤트
    try {
      await loginBonusUseCase(petId);
      pet = await repository.getPet(petId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetNotifier._loadDeferredUpdates: login bonus failed: $e');
      }
    }

    // 서버 동기화 (앱 시작 시 pull - 실패해도 무시)
    try {
      pet = await syncPetUseCase(petId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetNotifier._loadDeferredUpdates: sync failed: $e');
      }
    }

    try {
      final evolvedPet = await _updateAndEvolve(pet);
      state = AsyncValue.data(evolvedPet);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PetNotifier._loadDeferredUpdates: evolve failed: $e');
      }
    }
  }
  
  /// Pet 새로고침
  /// 
  /// 상태를 다시 로드하고 업데이트
  Future<void> refresh() async {
    await _loadPet();
  }

  /// 앱 포그라운드에서 5분 주기로 호출되는 경량 상태 업데이트
  ///
  /// 동작:
  /// - 수치 감소 + 활동(걸음/운동) 반영
  /// - **lastForegroundTime을 now로 갱신** → 앱을 켜놓고 있는 동안은 sleep이
  ///   카운트되지 않도록 보장. 사용자가 백그라운드로 보낸 시점부터만 sleep 인정.
  Future<void> onMinuteTick() async {
    if (state.isLoading || state.hasError) return;

    try {
      var updatedPet = await updatePetStateUseCase(petId);

      // 포그라운드 동안 sleep 카운트 방지 — anchor를 현재로 밀어둠
      try {
        await phoneUsageRepository.onForeground();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'PetNotifier.onMinuteTick: phoneUsage.onForeground 실패: $e');
        }
      }

      try {
        updatedPet = await updatePetFromActivityUseCase(petId);
      } catch (e) {
        // 헬스케어 권한이 없거나 에러 발생 시 무시
        if (kDebugMode) {
          debugPrint('PetNotifier.onMinuteTick: activity update failed: $e');
        }
      }

      final currentPet = state.valueOrNull;
      if (currentPet == null ||
          updatedPet.hunger != currentPet.hunger ||
          updatedPet.happiness != currentPet.happiness ||
          updatedPet.stamina != currentPet.stamina ||
          updatedPet.totalSteps != currentPet.totalSteps ||
          updatedPet.totalExerciseMinutes != currentPet.totalExerciseMinutes) {
        final evolvedPet = await _updateAndEvolve(updatedPet);
        state = AsyncValue.data(evolvedPet);
      } else {
        // 상태 수치가 동일해도 위젯 데이터가 뒤처질 수 있어 동기화 보강
        // (예: 위젯 재설치/프로세스 재시작 후 stale 데이터)
        try {
          await widgetService.updatePetWidget(currentPet);
        } catch (e) {
          // 위젯 업데이트 실패는 무시
        }
      }
    } catch (e) {
      // 앱 동작에 영향 없도록 무시
    }
  }
  
  /// 상태 업데이트 후 일일 목표 점수 적용, 진화 체크 및 알림 체크
  /// 
  /// 상태 변경 후 자동으로:
  /// 1. 전달받은 Pet을 먼저 저장하여 최신 상태 보장
  /// 2. 일일 목표 점수 적용
  /// 3. 진화 조건을 확인하고 진화 실행
  /// 4. 위젯을 업데이트하여 홈 화면에 반영 (앱 내 상태와 동기화)
  /// 5. 알림 조건을 확인하여 알림 발송
  /// 
  /// 중요: 모든 상태 변경은 이 메서드를 통해 처리되어야 하며,
  /// 위젯은 항상 앱 내 펫 상태와 동일하게 유지됩니다.
  /// 
  /// [pet] 업데이트할 Pet 엔티티 (이 Pet의 상태가 위젯에 반영됨)
  Future<Pet> _updateAndEvolve(Pet pet) async {
    // 1. 전달받은 Pet을 먼저 저장하여 최신 상태 보장
    await repository.updatePet(pet);

    // 2. 사망 체크 (수치 감소 후)
    final checkedPet = await checkPetDeathUseCase(petId);
    if (checkedPet.isDead) {
      try {
        await widgetService.updatePetWidget(checkedPet);
      } catch (e) {
        // 위젯 업데이트 실패 무시
      }
      return checkedPet;
    }

    // 3. 일일 목표 점수 적용 (저장된 Pet을 기반으로)
    await applyDailyGoalsScoreUseCase(petId);

    // 4. 진화 체크 및 실행 (저장된 Pet을 기반으로)
    final evolvedPet = await evolvePetUseCase(petId);

    // 5. 위젯 업데이트 (앱 내 펫 상태와 동기화)
    await widgetService.updatePetWidget(evolvedPet);

    // 6. 알림 체크 (상태 변경 후)
    _checkAndShowNotification();

    // 7. 서버 동기화 (fire-and-forget, UI 블로킹하지 않음)
    _syncToServer(evolvedPet);

    return evolvedPet;
  }
  
  /// 알림 체크 및 발송
  /// 
  /// Pet 상태를 확인하여 알림 발송이 필요한지 판단하고 발송
  Future<void> _checkAndShowNotification() async {
    try {
      final message = await checkNotificationUseCase(petId);
      if (message != null) {
        await notificationService.showNotification(
          title: AppStrings.notificationTitle,
          body: message,
        );
      }
    } catch (e) {
      // 알림 발송 실패는 무시 (앱 동작에 영향 없음)
    }
  }

  /// 서버 동기화 (fire-and-forget)
  /// UI를 블로킹하지 않고 비동기로 서버에 최신 데이터 전송
  Future<void> _syncToServer(Pet pet) async {
    try {
      await syncPetUseCase.remoteRepository?.savePet(pet);
    } catch (e) {
      // 서버 unreachable은 silent fail
      if (kDebugMode) {
        debugPrint('PetNotifier._syncToServer failed: $e');
      }
    }
  }


  /// [디버그 전용] 임의의 Pet 상태를 즉시 주입해 렌더한다 (시나리오 점검용).
  ///
  /// [runEvolution]이 true면 주입 상태에서 진화 유스케이스를 안정될 때까지
  /// 반복 실행해, 주입한 레벨·누적 카운터가 실제로 어떤 단계·등급·종을 만드는지
  /// 눈으로 확인할 수 있게 한다(진화 게이팅 로직 시각 검증). false면 주입한
  /// 값을 그대로 렌더한다(모든 스프라이트·색·mood 조합 직접 확인).
  /// 릴리스 빌드에서는 호출되지 않는다(kDebugMode 진입 버튼 뒤에만 존재).
  Future<Pet> debugApplyPet(Pet pet, {bool runEvolution = false}) async {
    await repository.updatePet(pet);
    var result = pet;
    if (runEvolution) {
      for (int i = 0; i < 5; i++) {
        final next = await evolvePetUseCase(petId);
        final stable = next.evolutionStage == result.evolutionStage &&
            next.evolutionGrade == result.evolutionGrade &&
            next.evolutionType == result.evolutionType;
        result = next;
        if (stable) break;
      }
    }
    try {
      await widgetService.updatePetWidget(result);
    } catch (_) {
      // 위젯 미설치 시 무시
    }
    state = AsyncValue.data(result);
    return result;
  }

  /// 먹이 주기
  ///
  /// Feed 버튼 클릭 시 호출
  /// 상태 변경 후 자동으로 진화 체크 수행
  Future<void> feed() async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet = await feedPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// 재우기
  /// 
  /// Sleep 버튼 클릭 시 호출
  /// 상태 변경 후 자동으로 진화 체크 수행
  Future<void> sleep() async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet = await sleepPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 대체 급식
  ///
  /// 실제 식사 시간대 Feed가 어려운 사용자를 위한 저효율 대체 액션
  Future<void> performAlternativeFeed() async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet = await alternativeFeedPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 대체 수면
  ///
  /// 실제 수면 연동이 어려운 사용자를 위한 저효율 대체 액션
  Future<void> performAlternativeSleep() async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet = await alternativeSleepPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 온라인 배틀 보상 지급
  ///
  /// 서버가 로컬 펫을 갱신하지 않는 결과(예: 상대 접속 끊김 승리)를
  /// 로컬에 반영하고 전적을 남긴다.
  Future<void> awardOnlineBattleReward({
    required bool isVictory,
    required int exp,
  }) async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet =
          await awardBattleRewardUseCase(petId, isVictory: isVictory, exp: exp);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 폰 흔들기 보너스
  ///
  /// 측정된 흔들기 횟수만큼 걸음수 보상을 펫에 반영한다.
  /// 하루 최대 1회 사용 가능.
  ///
  /// [shakeCount] 측정된 흔들기 횟수
  Future<void> performShakeBonus(int shakeCount) async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead == true) return;

    try {
      final updatedPet = await shakeStepBonusUseCase(petId, shakeCount);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// 앱이 포그라운드로 전환되었을 때 호출
  /// 
  /// 폰 미사용 시간을 계산하여 자동으로 Sleep 상태 적용
  /// 시간 경과에 따른 상태 업데이트 수행
  /// 활동 데이터를 기반으로 자동 Play 상태 적용
  /// 알림 체크 및 발송
  Future<void> onAppForeground() async {
    try {
      // 1. 앱 비사용 시간 수면 반영 (포그라운드 전환 전에 계산)
      await autoSleepPetUseCase(petId, isInBackground: true);

      // 2. 폰 사용 상태 업데이트 (포그라운드로 전환)
      await phoneUsageRepository.onForeground();

      // 3. 시간 경과에 따른 상태 업데이트 (hunger, happiness, stamina 감소)
      var activityUpdatedPet = await updatePetStateUseCase(petId);

      // 4. 활동 데이터 기반 자동 Play 적용
      try {
        activityUpdatedPet = await updatePetFromActivityUseCase(petId);
      } catch (e) {
        // 헬스케어 권한이 없거나 에러 발생 시 무시
        if (kDebugMode) {
          debugPrint('PetNotifier.onAppForeground: activity update failed: $e');
        }
      }
      
      // 5. 상태가 변경되었으면 업데이트
      // 걸음/운동/수면 진행치도 비교에 포함 — 스탯이 그대로여도(예: stamina 100,
      // 1000보 미만 delta) 목표 카드가 stale하게 남던 문제 방지.
      final currentPet = state.valueOrNull;
      if (currentPet == null ||
          activityUpdatedPet.hunger != currentPet.hunger ||
          activityUpdatedPet.happiness != currentPet.happiness ||
          activityUpdatedPet.stamina != currentPet.stamina ||
          activityUpdatedPet.exp != currentPet.exp ||
          activityUpdatedPet.totalSteps != currentPet.totalSteps ||
          activityUpdatedPet.totalExerciseMinutes !=
              currentPet.totalExerciseMinutes ||
          activityUpdatedPet.todaySleepMinutes !=
              currentPet.todaySleepMinutes ||
          activityUpdatedPet.name != currentPet.name) {
        // _updateAndEvolve()가 위젯 업데이트를 포함하므로 중복 호출 불필요
        final evolvedPet = await _updateAndEvolve(activityUpdatedPet);
        state = AsyncValue.data(evolvedPet);
      } else {
        // 상태가 변경되지 않아도 포그라운드 전환 시 위젯 재동기화
        // (위젯 stale 데이터 복구 목적)
        try {
          await widgetService.updatePetWidget(currentPet);
        } catch (e) {
          // 위젯 업데이트 실패는 무시
        }

        // 알림 체크 (포그라운드 전환 시)
        _checkAndShowNotification();
      }
    } catch (e) {
      // 에러는 무시 (앱 동작에 영향 없음)
    }
  }
  
  /// 앱이 백그라운드로 전환되었을 때 호출
  /// 
  /// 백그라운드 전환 시간을 기록
  Future<void> onAppBackground() async {
    try {
      // 폰 사용 상태 업데이트 (백그라운드로 전환)
      await phoneUsageRepository.onBackground();
    } catch (e) {
      // 에러는 무시 (앱 동작에 영향 없음)
    }
  }
  
  /// 펫 부활 (광고 시청 후 호출)
  Future<void> resurrect() async {
    if (state.isLoading || state.hasError) return;
    if (state.valueOrNull?.isDead != true) return;

    try {
      final resurrectedPet = await resurrectPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(resurrectedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 펫 초기화 — 처음부터 새로 키우기 (광고 시청 후 호출)
  ///
  /// 기존 펫(레벨/진화/누적 기록 포함)을 버리고 기본 펫으로 교체한다.
  /// 사망 여부와 무관하게 동작한다.
  Future<void> restart() async {
    if (state.isLoading) return;

    try {
      final freshPet = await resetPetUseCase(petId);
      // 위젯 동기화 (설치 안 됐을 수 있으므로 실패는 무시)
      try {
        await widgetService.updatePetWidget(freshPet);
      } catch (e) {
        // 위젯 업데이트 실패 무시
      }
      state = AsyncValue.data(freshPet);
      _syncToServer(freshPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 수동 진화 실행
  ///
  /// MeScreen 진화 버튼 클릭 시 호출
  /// 진화 조건 충족 시 진화 실행 후 상태 갱신
  Future<bool> evolve() async {
    if (state.isLoading || state.hasError) return false;
    final pet = state.valueOrNull;
    if (pet == null || pet.isDead) return false;
    if (!evolvePetUseCase.canEvolve(pet)) return false;

    try {
      final evolvedPet = await evolvePetUseCase(petId);
      if (evolvedPet.evolutionStage != pet.evolutionStage) {
        state = AsyncValue.data(evolvedPet);
        try {
          await widgetService.updatePetWidget(evolvedPet);
        } catch (e) {
          // 위젯 업데이트 실패 무시
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 펫 이름 변경
  ///
  /// [newName] 새로운 이름
  ///
  /// 이름 변경 후 상태 업데이트 및 위젯 업데이트
  Future<void> updateName(String newName) async {
    if (state.isLoading || state.hasError) return;
    
    try {
      final updatedPet = await updatePetNameUseCase(petId, newName);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Pet Notifier Provider
/// PetNotifier 인스턴스를 제공
/// 
/// [petId] 관리할 반려동물 ID (기본값: 'default-pet')
final petNotifierProvider = StateNotifierProvider.family<PetNotifier, AsyncValue<Pet>, String>((ref, petId) {
  return PetNotifier(
    repository: ref.watch(petRepositoryProvider),
    updatePetStateUseCase: ref.watch(updatePetStateUseCaseProvider),
    feedPetUseCase: ref.watch(feedPetUseCaseProvider),
    sleepPetUseCase: ref.watch(sleepPetUseCaseProvider),
    createDefaultPetUseCase: ref.watch(createDefaultPetUseCaseProvider),
    evolvePetUseCase: ref.watch(evolvePetUseCaseProvider),
    checkNotificationUseCase: ref.watch(checkNotificationUseCaseProvider),
    notificationService: ref.watch(notificationServiceProvider),
    widgetService: ref.watch(widgetServiceProvider),
    phoneUsageRepository: ref.watch(phoneUsageRepositoryProvider),
    autoSleepPetUseCase: ref.watch(autoSleepPetUseCaseProvider),
    detectPhoneIdleUseCase: ref.watch(detectPhoneIdleUseCaseProvider),
    updatePetFromActivityUseCase: ref.watch(updatePetFromActivityUseCaseProvider),
    applyDailyGoalsScoreUseCase: ref.watch(applyDailyGoalsScoreUseCaseProvider),
    updatePetNameUseCase: ref.watch(updatePetNameUseCaseProvider),
    alternativeFeedPetUseCase: ref.watch(alternativeFeedPetUseCaseProvider),
    alternativeSleepPetUseCase: ref.watch(alternativeSleepPetUseCaseProvider),
    awardBattleRewardUseCase: ref.watch(awardBattleRewardUseCaseProvider),
    shakeStepBonusUseCase: ref.watch(shakeStepBonusUseCaseProvider),
    checkPetDeathUseCase: ref.watch(checkPetDeathUseCaseProvider),
    resurrectPetUseCase: ref.watch(resurrectPetUseCaseProvider),
    resetPetUseCase: ref.watch(resetPetUseCaseProvider),
    loginBonusUseCase: ref.watch(loginBonusUseCaseProvider),
    syncPetUseCase: ref.watch(syncPetUseCaseProvider),
    petId: petId,
  );
});
