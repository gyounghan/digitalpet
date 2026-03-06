import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pet.dart';
import '../../domain/repositories/pet_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/update_pet_state_usecase.dart';
import '../../domain/usecases/feed_pet_usecase.dart';
import '../../domain/usecases/play_pet_usecase.dart';
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

/// PlayPetUseCase Provider
/// 놀아주기 유스케이스 인스턴스를 제공
final playPetUseCaseProvider = Provider<PlayPetUseCase>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return PlayPetUseCase(repository);
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
  final PlayPetUseCase playPetUseCase;
  final SleepPetUseCase sleepPetUseCase;
  final CreateDefaultPetUseCase createDefaultPetUseCase;
  final EvolvePetUseCase evolvePetUseCase;
  final CheckNotificationUseCase checkNotificationUseCase;
  final NotificationService notificationService;
  final WidgetService widgetService;
  final String petId;
  
  PetNotifier({
    required this.repository,
    required this.updatePetStateUseCase,
    required this.feedPetUseCase,
    required this.playPetUseCase,
    required this.sleepPetUseCase,
    required this.createDefaultPetUseCase,
    required this.evolvePetUseCase,
    required this.checkNotificationUseCase,
    required this.notificationService,
    required this.widgetService,
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
      
      // 4. 시간 경과에 따른 상태 업데이트 (이미 저장된 Pet이어도 시간 경과 반영)
      await updatePetStateUseCase(petId);
      
      // 5. 진화 체크 및 실행
      final evolvedPet = await evolvePetUseCase(petId);
      state = AsyncValue.data(evolvedPet);
      
      // 6. 위젯 업데이트 (기본값: sleeping 이미지)
      await widgetService.updatePetWidget(evolvedPet, imageType: 'sleeping');
      
      // 7. 알림 체크 (앱 실행 시)
      _checkAndShowNotification();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Pet 새로고침
  /// 
  /// 상태를 다시 로드하고 업데이트
  Future<void> refresh() async {
    await _loadPet();
  }
  
  /// 상태 업데이트 후 진화 체크 및 알림 체크
  /// 
  /// 상태 변경 후 자동으로 진화 조건을 확인하고 진화 실행
  /// 그리고 알림 조건을 확인하여 알림 발송
  /// 그리고 위젯을 업데이트하여 홈 화면에 반영
  Future<Pet> _updateAndEvolve(Pet pet) async {
    // 진화 체크 및 실행
    final evolvedPet = await evolvePetUseCase(petId);
    
    // 위젯 업데이트 (기본값: sleeping 이미지)
    await widgetService.updatePetWidget(evolvedPet, imageType: 'sleeping');
    
    // 알림 체크 (상태 변경 후)
    _checkAndShowNotification();
    
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
          title: '내 펫',
          body: message,
        );
      }
    } catch (e) {
      // 알림 발송 실패는 무시 (앱 동작에 영향 없음)
    }
  }
  
  /// 먹이 주기
  /// 
  /// Feed 버튼 클릭 시 호출
  /// 상태 변경 후 자동으로 진화 체크 수행
  Future<void> feed() async {
    if (state.isLoading || state.hasError) return;
    
    try {
      final updatedPet = await feedPetUseCase(petId);
      final evolvedPet = await _updateAndEvolve(updatedPet);
      state = AsyncValue.data(evolvedPet);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// 놀아주기
  /// 
  /// Play 버튼 클릭 시 호출
  /// 상태 변경 후 자동으로 진화 체크 수행
  Future<void> play() async {
    if (state.isLoading || state.hasError) return;
    
    try {
      final updatedPet = await playPetUseCase(petId);
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
    
    try {
      final updatedPet = await sleepPetUseCase(petId);
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
    playPetUseCase: ref.watch(playPetUseCaseProvider),
    sleepPetUseCase: ref.watch(sleepPetUseCaseProvider),
    createDefaultPetUseCase: ref.watch(createDefaultPetUseCaseProvider),
    evolvePetUseCase: ref.watch(evolvePetUseCaseProvider),
    checkNotificationUseCase: ref.watch(checkNotificationUseCaseProvider),
    notificationService: ref.watch(notificationServiceProvider),
    widgetService: ref.watch(widgetServiceProvider),
    petId: petId,
  );
});
