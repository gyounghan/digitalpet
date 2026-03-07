# Feed 시스템 문서

## 개요

Feed 시스템은 펫의 배고픔 상태와 식사 시간대를 기반으로 사용자가 펫에게 먹이를 줄 수 있는 상호작용 시스템입니다.

## 구현 방식

### 옵션 선택: 알림 기반 + 식사 시간대 조합

사용자가 선택한 옵션 5번을 기반으로 구현되었습니다:
- 펫이 배고픈 상태에서 식사 시간대에 알림을 보냄
- 홈 화면에 Feed 버튼이 조건부로 표시됨
- 사용자가 직접 Feed 버튼을 눌러야 먹이를 줄 수 있음

## Feed 가능 조건

### 기본 조건

1. **배고픔 상태**: `hunger < 30`
   - 펫이 배고픈 상태여야 함

2. **식사 시간대**: 다음 시간대 중 하나
   - 아침: 7시 ~ 9시
   - 점심: 12시 ~ 14시
   - 저녁: 18시 ~ 20시

3. **예외 조건**: 매우 심한 배고픔
   - `hunger < 10`인 경우 식사 시간대 무관하게 Feed 가능

## 구현 파일

### Domain 레이어

- **`lib/domain/usecases/can_feed_pet_usecase.dart`**
  - Feed 가능 여부를 확인하는 비즈니스 로직
  - `hungerThreshold`: 30 (배고픔 임계값)
  - `severeHungerThreshold`: 10 (심한 배고픔 임계값)
  - `mealTimeRanges`: 식사 시간대 정의

### Presentation 레이어

- **`lib/presentation/screens/home_screen.dart`**
  - Feed 버튼 조건부 표시
  - `CanFeedPetUseCase`를 사용하여 Feed 가능 여부 확인
  - Feed 버튼 클릭 시 `petNotifier.feed()` 호출

- **`lib/presentation/providers/pet_provider.dart`**
  - `canFeedPetUseCaseProvider`: Feed 가능 여부 확인 UseCase Provider
  - `feed()` 메서드: Feed 액션 실행

### 알림 시스템

- **`lib/domain/usecases/check_notification_usecase.dart`**
  - 식사 시간대에 배고픈 상태일 때 알림 발송
  - `AppStrings.notificationFeedTime` 사용

- **`lib/core/constants/app_strings.dart`**
  - `notificationFeedTime`: '밥 먹을 시간이에요! 🍽️'

## 사용 방법

### Feed 버튼 표시 조건

```dart
// HomeScreen에서 Feed 버튼 조건부 표시
Consumer(
  builder: (context, ref, _) {
    final canFeedUseCase = ref.watch(canFeedPetUseCaseProvider);
    final canFeed = canFeedUseCase.canFeed(pet);
    
    if (!canFeed) {
      return const SizedBox.shrink();
    }
    
    return PetButton(
      variant: PetButtonVariant.primary,
      icon: Icons.restaurant,
      onPressed: () {
        ref.read(petNotifierProvider(HomeScreen.defaultPetId).notifier).feed();
      },
      child: Text(AppStrings.feed),
    );
  },
)
```

### Feed 가능 여부 확인

```dart
// UseCase 직접 사용
final canFeedUseCase = CanFeedPetUseCase(petRepository);
final canFeed = await canFeedUseCase.call(petId);

// 또는 Pet 엔티티 직접 전달
final canFeed = canFeedUseCase.canFeed(pet);
```

## 알림 동작

### 알림 발송 조건

1. 펫이 배고픈 상태 (`hunger < 30`)
2. 현재 시간이 식사 시간대
3. 알림 메시지: "밥 먹을 시간이에요! 🍽️"

### 알림 발송 시점

- `CheckNotificationUseCase`에서 주기적으로 확인
- 식사 시간대에 배고픈 상태일 때 자동 발송

## Feed 액션 효과

Feed 버튼을 누르면:
- `hunger` 값이 +30 증가
- 펫의 상태가 업데이트됨
- 위젯도 자동으로 업데이트됨

## 변경 이력

### 자동 Feed에서 상호작용 Feed로 변경

**이전**: 자동으로 Feed가 실행됨 (`AutoFeedPetUseCase`)
**현재**: 사용자가 직접 Feed 버튼을 눌러야 함 (`CanFeedPetUseCase`)

**변경 이유**: 사용자와의 상호작용을 높이고, 더 게임적인 경험을 제공하기 위해

## 관련 파일

- `lib/domain/usecases/can_feed_pet_usecase.dart` - Feed 가능 여부 확인 로직
- `lib/domain/usecases/check_notification_usecase.dart` - Feed 알림 로직
- `lib/presentation/screens/home_screen.dart` - Feed 버튼 UI
- `lib/presentation/providers/pet_provider.dart` - Feed 액션 실행
- `lib/core/constants/app_strings.dart` - Feed 관련 문자열
