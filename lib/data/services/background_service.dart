import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/usecases/auto_sleep_pet_usecase.dart';
import '../../domain/usecases/auto_feed_pet_usecase.dart';
import '../../domain/usecases/update_pet_from_activity_usecase.dart';
import '../../domain/usecases/check_notification_usecase.dart';
import '../../domain/usecases/evolve_pet_usecase.dart';
import '../../domain/usecases/calculate_daily_goals_score_usecase.dart';
import '../../domain/usecases/apply_daily_goals_score_usecase.dart';
import '../../data/repository/pet_repository_impl.dart';
import '../../data/datasource/pet_local_datasource.dart';
import '../../data/repositories/phone_usage_repository_impl.dart';
import '../../data/datasources/phone_usage_datasource.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../data/datasources/health_datasource.dart';
import '../../data/repository/notification_repository_impl.dart';
import '../../data/datasource/notification_local_datasource.dart';
import 'notification_service.dart';
import 'widget_service.dart';
import '../../presentation/screens/home_screen.dart';

/// 백그라운드 작업 서비스
/// WorkManager를 사용하여 백그라운드에서 펫 상태 업데이트, 알림 발송, 위젯 업데이트 수행
class BackgroundService {
  static const String taskName = 'petBackgroundTask';
  
  /// WorkManager 초기화 및 백그라운드 작업 등록
  /// 
  /// 앱 시작 시 한 번만 호출
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // 주기적 백그라운드 작업 등록 (15분마다 실행)
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }
  
  /// 백그라운드 작업 취소
  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(taskName);
  }
}

/// 백그라운드 작업 콜백 함수
/// 
/// WorkManager에서 호출되는 최상위 함수
/// Flutter 엔진이 초기화되지 않은 상태에서도 실행 가능해야 함
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Hive 초기화 (백그라운드에서도 필요)
      await Hive.initFlutter();
      
      // Repository 및 UseCase 인스턴스 생성
      final petDataSource = PetLocalDataSource();
      await petDataSource.init();
      final petRepository = PetRepositoryImpl(petDataSource);
      
      final phoneUsageDataSource = PhoneUsageDataSource();
      await phoneUsageDataSource.init();
      final phoneUsageRepository = PhoneUsageRepositoryImpl(phoneUsageDataSource);
      
      final healthDataSource = HealthDataSource();
      await healthDataSource.init();
      final activityRepository = ActivityRepositoryImpl(healthDataSource);
      
      final notificationDataSource = NotificationLocalDataSource();
      await notificationDataSource.init();
      final notificationRepository = NotificationRepositoryImpl(notificationDataSource);
      
      final notificationService = NotificationService();
      await notificationService.init();
      
      final widgetService = WidgetService();
      await widgetService.initialize();
      
      // UseCase 인스턴스 생성
      final autoSleepUseCase = AutoSleepPetUseCase(
        petRepository: petRepository,
        phoneUsageRepository: phoneUsageRepository,
      );
      
      final autoFeedUseCase = AutoFeedPetUseCase(petRepository);
      
      final updateFromActivityUseCase = UpdatePetFromActivityUseCase(
        petRepository: petRepository,
        activityRepository: activityRepository,
      );
      
      final checkNotificationUseCase = CheckNotificationUseCase(
        petRepository: petRepository,
        notificationRepository: notificationRepository,
      );
      
      final evolvePetUseCase = EvolvePetUseCase(petRepository);
      
      final calculateDailyGoalsScoreUseCase = CalculateDailyGoalsScoreUseCase(
        petRepository: petRepository,
        activityRepository: activityRepository,
      );
      
      final applyDailyGoalsScoreUseCase = ApplyDailyGoalsScoreUseCase(
        petRepository: petRepository,
        calculateScoreUseCase: calculateDailyGoalsScoreUseCase,
      );
      
      // 펫 ID
      const petId = HomeScreen.defaultPetId;
      
      // 1. 자동 Sleep 적용 (폰 미사용 시간 기반)
      var pet = await autoSleepUseCase(petId, isInBackground: true);
      
      // 2. 자동 Feed 적용 (시간 기반)
      pet = await autoFeedUseCase(petId);
      
      // 3. 활동 데이터 기반 상태 업데이트 (걷기/운동량)
      try {
        pet = await updateFromActivityUseCase(petId);
      } catch (e) {
        // 헬스케어 권한이 없거나 에러 발생 시 무시
      }
      
      // 4. 일일 목표 점수 적용
      pet = await applyDailyGoalsScoreUseCase(petId);
      
      // 5. 진화 체크 및 실행
      pet = await evolvePetUseCase(petId);
      
      // 5. 위젯 업데이트
      try {
        await widgetService.updatePetWidget(pet);
      } catch (e) {
        // 위젯 업데이트 실패는 무시
      }
      
      // 6. 알림 체크 및 발송
      try {
        final message = await checkNotificationUseCase(petId);
        if (message != null) {
          await notificationService.showNotification(
            title: '내 펫',
            body: message,
          );
        }
      } catch (e) {
        // 알림 발송 실패는 무시
      }
      
      return true;
    } catch (e) {
      // 에러 발생 시에도 작업 완료로 처리 (다음 실행 시 재시도)
      return true;
    }
  });
}
