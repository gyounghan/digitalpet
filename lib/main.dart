import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/models/pet_model_adapter.dart';
import 'data/models/battle_history_model_adapter.dart';
import 'data/datasource/pet_local_datasource.dart';
import 'data/datasources/battle_history_datasource.dart';
import 'data/datasource/notification_local_datasource.dart';
import 'data/datasources/phone_usage_datasource.dart';
import 'data/datasources/health_datasource.dart';
import 'data/services/notification_service.dart';
import 'data/services/widget_service.dart';
import 'data/services/background_service.dart';
import 'data/datasources/auth_session.dart';
import 'data/datasources/device_id_datasource.dart';
import 'data/datasources/step_sensor_datasource.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'core/theme/app_theme.dart';

/// startup 정책:
/// runApp 전에는 "UI 첫 페인트에 반드시 필요한" 작업만 await한다.
///   - Hive 초기화 + 6개 Box open (병렬)
///   - 알림 채널 init (다이얼로그 X)
/// 나머지(권한 다이얼로그, WorkManager, 위젯, 광고 SDK)는 MainNavigationScreen의
/// postFrame에서 deferredInit으로 실행한다. 다이얼로그가 main을 막거나
/// MobileAds 초기화(1~5초)가 첫 진입을 지연시키지 않도록 분리.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 및 6개 Box 열기 (디스크 I/O라 병렬화 효과 큼)
  await _initHive();

  // 알림 인스턴스 init만 — 권한 요청 다이얼로그는 postFrame에서
  await _initNotificationsCore();

  // 로그인 세션 로드 — 첫 서버 동기화부터 Authorization 헤더가 붙도록
  await AuthSession.load();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Hive 초기화 — Adapter 등록 후 6개 Box를 병렬로 open
Future<void> _initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(PetModelAdapter());
  Hive.registerAdapter(BattleHistoryModelAdapter());

  await Future.wait([
    PetLocalDataSource().init(),
    NotificationLocalDataSource().init(),
    PhoneUsageDataSource().init(),
    BattleHistoryDataSource().init(),
    DeviceIdDatasource().init(),
    StepSensorDatasource().init(),
  ]);
}

/// 알림 채널만 등록. 권한 요청은 [runDeferredStartupTasks]에서.
Future<void> _initNotificationsCore() async {
  try {
    await NotificationService().init();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('main._initNotificationsCore: $e');
    }
  }
}

/// 첫 프레임 이후에 실행되는 무거운 초기화들.
///
/// - 알림 권한 요청 (다이얼로그)
/// - Health Connect 권한 요청 (다이얼로그) + activityRecognition 권한
/// - WorkManager 초기화 + 4개 Task 등록
/// - 홈위젯 app group 설정
///
/// 광고 SDK는 [AdService.showRewardedAd] 첫 호출 시 lazy 초기화되므로
/// 여기서도 제외 — 부활 등 실사용 시점까지 지연.
Future<void> runDeferredStartupTasks() async {
  // 권한 요청은 사용자 응답을 기다리므로 다른 작업과 병렬로 실행해도 안전.
  // 각 future는 자체 try/catch로 에러를 흡수해 한쪽 실패가 다른 쪽을 막지 않게 한다.
  await Future.wait([
    _requestNotificationPermission(),
    _initHealth(),
    BackgroundService.initialize().catchError((e) {
      if (kDebugMode) {
        debugPrint('runDeferredStartupTasks: BackgroundService init failed: $e');
      }
    }),
    WidgetService().initialize().catchError((e) {
      if (kDebugMode) {
        debugPrint('runDeferredStartupTasks: WidgetService init failed: $e');
      }
    }),
  ]);
}

Future<void> _requestNotificationPermission() async {
  try {
    await NotificationService().requestPermission();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('runDeferredStartupTasks: notification permission failed: $e');
    }
  }
}

Future<void> _initHealth() async {
  try {
    await HealthDataSource().init();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('runDeferredStartupTasks: health init failed: $e');
    }
  }
}

/// 메인 앱 위젯
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Pet',
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
