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
import 'data/services/ad_service.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive 초기화
  await _initHive();
  
  // 알림 서비스 초기화
  await _initNotifications();
  
  // 위젯 서비스 초기화
  await _initWidget();
  
  // 헬스케어 데이터소스 초기화
  // HealthDataSource._initialized는 static이므로 Provider의 lazy 초기화와 공유됨.
  // 앱 시작 시 미리 권한을 요청하여 첫 동기화 지연을 방지한다.
  await _initHealth();

  // 백그라운드 작업 초기화
  await _initBackgroundService();

  // 광고 서비스 초기화
  await _initAds();
  
  // 앱 실행
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Hive 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 Hive와 Adapter를 준비
Future<void> _initHive() async {
  // Hive Flutter 초기화
  await Hive.initFlutter();
  
  // PetModelAdapter 등록
  Hive.registerAdapter(PetModelAdapter());
  
  // BattleHistoryModelAdapter 등록
  Hive.registerAdapter(BattleHistoryModelAdapter());
  
  // PetLocalDataSource 초기화 (Box 열기)
  final dataSource = PetLocalDataSource();
  await dataSource.init();
  
  // NotificationLocalDataSource 초기화 (Box 열기)
  final notificationDataSource = NotificationLocalDataSource();
  await notificationDataSource.init();
  
  // PhoneUsageDataSource 초기화 (Box 열기)
  final phoneUsageDataSource = PhoneUsageDataSource();
  await phoneUsageDataSource.init();
  
  // BattleHistoryDataSource 초기화 (Box 열기)
  final battleHistoryDataSource = BattleHistoryDataSource();
  await battleHistoryDataSource.init();
}

/// 알림 서비스 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 알림 서비스를 준비
Future<void> _initNotifications() async {
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermission();
}

/// 위젯 서비스 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 홈 화면 위젯 서비스를 준비
Future<void> _initWidget() async {
  final widgetService = WidgetService();
  await widgetService.initialize();
}

/// 헬스케어 데이터소스 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 헬스케어 권한을 요청하고 초기화
/// 권한이 거부되면 에러를 무시하고 계속 진행 (활동 추적 기능만 비활성화)
Future<void> _initHealth() async {
  try {
    final healthDataSource = HealthDataSource();
    await healthDataSource.init();
  } catch (e) {
    // 헬스케어 권한이 거부되거나 초기화 실패 시 무시
    // 앱은 정상적으로 동작하되 활동 추적 기능만 비활성화됨
    debugPrint('main._initHealth: Health init failed: $e');
  }
}

/// 백그라운드 작업 서비스 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 WorkManager를 초기화하고 백그라운드 작업을 등록
Future<void> _initBackgroundService() async {
  await BackgroundService.initialize();
}

/// 광고 서비스 초기화
Future<void> _initAds() async {
  try {
    final adService = AdService();
    await adService.initialize();
  } catch (e) {
    debugPrint('main._initAds: Ads init failed: $e');
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
