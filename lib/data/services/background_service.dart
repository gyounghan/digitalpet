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
  static const String mealTimeTaskName = 'petMealTimeTask';
  
  /// WorkManager 초기화 및 백그라운드 작업 등록
  /// 
  /// 앱 시작 시 한 번만 호출
  /// 식사 시간대(아침 7-9시, 점심 12-14시, 저녁 18-20시)에 일회성 작업을 스케줄링
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
    
    // 식사 시간대 알림을 위한 일회성 작업 스케줄링
    await scheduleMealTimeNotifications();
  }
  
  /// 식사 시간대 알림을 위한 일회성 작업 스케줄링
  /// 
  /// 매일 아침(8시), 점심(13시), 저녁(19시)에 알림 체크 작업을 등록
  static Future<void> scheduleMealTimeNotifications() async {
    final now = DateTime.now();
    
    // 오늘의 식사 시간대 계산
    final todayMorning = DateTime(now.year, now.month, now.day, 8, 0);
    final todayLunch = DateTime(now.year, now.month, now.day, 13, 0);
    final todayDinner = DateTime(now.year, now.month, now.day, 19, 0);
    
    // 이미 지난 시간대는 내일로 스케줄링
    final morningTime = todayMorning.isBefore(now) 
        ? todayMorning.add(const Duration(days: 1))
        : todayMorning;
    final lunchTime = todayLunch.isBefore(now)
        ? todayLunch.add(const Duration(days: 1))
        : todayLunch;
    final dinnerTime = todayDinner.isBefore(now)
        ? todayDinner.add(const Duration(days: 1))
        : todayDinner;
    
    // 각 식사 시간대에 일회성 작업 등록
    await Workmanager().registerOneOffTask(
      '${mealTimeTaskName}_morning',
      mealTimeTaskName,
      initialDelay: morningTime.difference(now),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
    
    await Workmanager().registerOneOffTask(
      '${mealTimeTaskName}_lunch',
      mealTimeTaskName,
      initialDelay: lunchTime.difference(now),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
    
    await Workmanager().registerOneOffTask(
      '${mealTimeTaskName}_dinner',
      mealTimeTaskName,
      initialDelay: dinnerTime.difference(now),
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
    await Workmanager().cancelByUniqueName('${mealTimeTaskName}_morning');
    await Workmanager().cancelByUniqueName('${mealTimeTaskName}_lunch');
    await Workmanager().cancelByUniqueName('${mealTimeTaskName}_dinner');
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
      // 식사 시간대 작업인 경우 알림만 체크하고 종료
      if (task == BackgroundService.mealTimeTaskName) {
        await _checkMealTimeNotification();
        // 다음 날 식사 시간대 작업 재스케줄링
        await _rescheduleMealTimeNotifications();
        return true;
      }
      
      // 일반 백그라운드 작업 실행
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

/// 식사 시간대 알림 체크 및 발송
/// 
/// 식사 시간대에 펫의 배고픔 상태를 확인하고 알림 발송
Future<void> _checkMealTimeNotification() async {
  try {
    // Hive 초기화
    await Hive.initFlutter();
    
    // Repository 및 UseCase 인스턴스 생성
    final petDataSource = PetLocalDataSource();
    await petDataSource.init();
    final petRepository = PetRepositoryImpl(petDataSource);
    
    final notificationDataSource = NotificationLocalDataSource();
    await notificationDataSource.init();
    final notificationRepository = NotificationRepositoryImpl(notificationDataSource);
    
    final notificationService = NotificationService();
    await notificationService.init();
    
    final checkNotificationUseCase = CheckNotificationUseCase(
      petRepository: petRepository,
      notificationRepository: notificationRepository,
    );
    
    // 펫 ID
    const petId = HomeScreen.defaultPetId;
    
    // 알림 체크 및 발송 (식사 시간대이므로 배고픔 알림이 우선적으로 발송됨)
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
}

/// 다음 날 식사 시간대 작업 재스케줄링
/// 
/// 오늘 작업이 실행된 후 내일의 식사 시간대 작업을 다시 등록
Future<void> _rescheduleMealTimeNotifications() async {
  try {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    
    // 내일의 식사 시간대 계산
    final tomorrowMorning = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
    final tomorrowLunch = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13, 0);
    final tomorrowDinner = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 0);
    
    // 각 식사 시간대에 일회성 작업 등록
    await Workmanager().registerOneOffTask(
      '${BackgroundService.mealTimeTaskName}_morning',
      BackgroundService.mealTimeTaskName,
      initialDelay: tomorrowMorning.difference(now),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
    
    await Workmanager().registerOneOffTask(
      '${BackgroundService.mealTimeTaskName}_lunch',
      BackgroundService.mealTimeTaskName,
      initialDelay: tomorrowLunch.difference(now),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
    
    await Workmanager().registerOneOffTask(
      '${BackgroundService.mealTimeTaskName}_dinner',
      BackgroundService.mealTimeTaskName,
      initialDelay: tomorrowDinner.difference(now),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  } catch (e) {
    // 재스케줄링 실패는 무시 (다음 앱 실행 시 다시 스케줄링됨)
  }
}
