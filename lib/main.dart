import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/models/pet_model_adapter.dart';
import 'data/datasource/pet_local_datasource.dart';
import 'data/datasource/notification_local_datasource.dart';
import 'data/services/notification_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive 초기화
  await _initHive();
  
  // 알림 서비스 초기화
  await _initNotifications();
  
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
  
  // PetLocalDataSource 초기화 (Box 열기)
  final dataSource = PetLocalDataSource();
  await dataSource.init();
  
  // NotificationLocalDataSource 초기화 (Box 열기)
  final notificationDataSource = NotificationLocalDataSource();
  await notificationDataSource.init();
}

/// 알림 서비스 초기화
/// 
/// 앱 시작 시 한 번만 호출하여 알림 서비스를 준비
Future<void> _initNotifications() async {
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermission();
}

/// 메인 앱 위젯
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Pet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
