import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/constants/notification_constants.dart';

/// 알림 서비스
/// flutter_local_notifications를 사용한 실제 알림 발송
/// 
/// 플랫폼별 알림 권한 요청 및 알림 발송을 담당
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  /// 알림 서비스 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 알림 채널 설정 및 권한 요청
  Future<void> init() async {
    if (_initialized) return;
    
    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 초기화 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // 초기화 설정
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // 알림 초기화
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Android 알림 채널 생성
    const androidChannel = AndroidNotificationChannel(
      NotificationConstants.notificationChannelId,
      NotificationConstants.notificationChannelName,
      description: NotificationConstants.notificationChannelDescription,
      importance: Importance.high,
      playSound: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    _initialized = true;
  }
  
  /// 알림 탭 이벤트 처리
  /// 
  /// 사용자가 알림을 탭했을 때 호출되는 콜백
  void _onNotificationTapped(NotificationResponse response) {
    // 알림 탭 시 앱으로 이동하는 로직은 여기에 구현
    // 필요시 Navigator나 다른 라우팅 로직 추가 가능
  }
  
  /// 알림 발송
  /// 
  /// [title] 알림 제목
  /// [body] 알림 내용
  /// 
  /// 반환: 알림 발송 성공 여부
  Future<bool> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }
    
    // Android 알림 상세 설정
    const androidDetails = AndroidNotificationDetails(
      NotificationConstants.notificationChannelId,
      NotificationConstants.notificationChannelName,
      channelDescription: NotificationConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    // iOS 알림 상세 설정
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // 알림 상세 설정
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // 알림 발송
    try {
      await _notifications.show(
        0, // 알림 ID
        title,
        body,
        notificationDetails,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 알림 권한 요청
  /// 
  /// iOS에서 알림 권한을 요청
  Future<bool> requestPermission() async {
    if (!_initialized) {
      await init();
    }
    
    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      return await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    
    return true; // Android는 항상 true
  }
  
}
