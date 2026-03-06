# PocketFriend UI 가이드

## 목차
1. [개요](#개요)
2. [디자인 시스템](#디자인-시스템)
3. [화면 구조](#화면-구조)
4. [위젯 컴포넌트](#위젯-컴포넌트)
5. [애니메이션](#애니메이션)
6. [레이아웃 가이드](#레이아웃-가이드)

---

## 개요

PocketFriend는 다크 테마 기반의 글래스모피즘 디자인을 사용하는 반려동물 키우기 앱입니다. 
디자인 시스템은 `design/` 폴더의 React 컴포넌트를 기반으로 Flutter로 구현되었습니다.

### 주요 특징
- **다크 테마**: 어두운 배경에 밝은 액센트 색상 사용
- **글래스모피즘**: 반투명 효과와 블러를 활용한 현대적인 UI
- **부드러운 애니메이션**: 상태 변화와 사용자 인터랙션에 자연스러운 애니메이션 적용
- **반응형 레이아웃**: 다양한 화면 크기에 대응하는 유연한 레이아웃

---

## 디자인 시스템

### 색상 팔레트

#### 배경색
```dart
AppColors.backgroundDark          // #0F0F1E - 메인 배경
AppColors.backgroundDarkSecondary // #1a1a2e - 보조 배경
AppColors.backgroundDarkTertiary  // #16213e - 3차 배경
```

#### Primary 색상
```dart
AppColors.primary      // #8B7FFF - 메인 색상 (보라색)
AppColors.primaryDark // #6B5FEF - 어두운 보라색
AppColors.primaryGlow // rgba(139, 127, 255, 0.3) - 글로우 효과
```

#### Accent 색상
```dart
AppColors.accentPink  // #FF6B9D - 핑크 액센트
AppColors.accentCyan  // #5DFDCB - 시안 액센트
```

#### 상태 색상
```dart
// 배고픔
AppColors.hunger      // #FF8A65
AppColors.hungerDark  // #FF6B4A

// 행복도
AppColors.happiness   // #FFD93D
AppColors.happinessDark // #FFC107

// 체력
AppColors.stamina     // #6BCF7F
AppColors.staminaDark // #4CAF50
```

#### 글래스모피즘 색상
```dart
AppColors.glassBackground     // rgba(255, 255, 255, 0.05)
AppColors.glassBorder        // rgba(255, 255, 255, 0.1)
AppColors.glassBackgroundLight // rgba(255, 255, 255, 0.03)
AppColors.glassBorderLight   // rgba(255, 255, 255, 0.08)
```

#### 텍스트 색상
```dart
AppColors.textPrimary   // 흰색 (100% 불투명도)
AppColors.textSecondary // rgba(255, 255, 255, 0.6)
AppColors.textTertiary  // rgba(255, 255, 255, 0.4)
```

### 그라디언트

```dart
// 배경 그라디언트
AppColors.backgroundGradient
// [backgroundDarkSecondary, backgroundDark, backgroundDarkTertiary]

// 글래스 그라디언트
AppColors.glassGradient
// [rgba(139, 127, 255, 0.05), transparent, rgba(255, 107, 157, 0.05)]

// 상태 그라디언트
AppColors.hungerGradient
AppColors.happinessGradient
AppColors.staminaGradient
```

### 테마

앱은 `AppTheme.darkTheme`을 사용하며, Material 3 디자인 시스템을 기반으로 합니다.

```dart
MaterialApp(
  theme: AppTheme.darkTheme,
  // ...
)
```

---

## 화면 구조

### 메인 네비게이션 (`MainNavigationScreen`)

앱의 메인 컨테이너로, 하단 네비게이션 바를 통해 4개의 화면을 전환합니다.

**구조:**
```
MainNavigationScreen
├── IndexedStack (화면 스택)
│   ├── HomeScreen
│   ├── EvolutionScreen
│   ├── BattleScreen
│   └── ShareScreen
└── BottomNavigationBar
```

**특징:**
- `IndexedStack`을 사용하여 화면 상태 유지
- 커스텀 하단 네비게이션 바
- 각 탭에 대한 아이콘과 라벨 표시

### 홈 화면 (`HomeScreen`)

펫의 상태를 표시하고 Feed/Play/Sleep 액션을 수행할 수 있는 메인 화면입니다.

**레이아웃 구조:**
```
HomeScreen
├── 배경 그라디언트
├── SafeArea
│   └── Column
│       ├── 헤더 (메뉴, 펫 이름/레벨, 설정)
│       ├── 펫 이미지 애니메이션 영역
│       ├── 상태바 섹션 (GlassCard)
│       │   ├── Hunger StatusBar
│       │   ├── Happiness StatusBar
│       │   └── Stamina StatusBar
│       └── 액션 버튼들 (Row)
│           ├── Feed Button
│           ├── Play Button
│           └── Sleep Button
```

**주요 기능:**
- 펫 이미지 애니메이션 (기본: 잠자는 상태)
- Feed 버튼 클릭 시 배고픈 이미지로 전환 (3초 후 복귀)
- Sleep 버튼 클릭 시 잠자는 이미지로 전환
- 실시간 상태바 업데이트

### 진화 화면 (`EvolutionScreen`)

펫의 진화 상태와 다음 진화 조건을 표시하는 화면입니다.

### 배틀 화면 (`BattleScreen`)

펫 간 배틀 기능을 제공하는 화면입니다.

### 공유 화면 (`ShareScreen`)

펫 정보를 공유하는 화면입니다.

---

## 위젯 컴포넌트

### PetButton

펫 액션 버튼 컴포넌트입니다.

**사용 예시:**
```dart
PetButton(
  variant: PetButtonVariant.primary,
  icon: Icons.restaurant,
  onPressed: () {
    // Feed 액션
  },
  child: Text('Feed'),
)
```

**Props:**
- `variant`: `PetButtonVariant.primary` 또는 `PetButtonVariant.secondary`
- `icon`: `IconData?` (선택사항)
- `child`: `Widget` (필수)
- `onPressed`: `VoidCallback?`
- `disabled`: `bool` (기본값: false)

**스타일:**
- Primary: 그라디언트 배경 + 글로우 효과
- Secondary: 글래스모피즘 배경 + 테두리
- 탭 애니메이션: 스케일 다운 효과 (0.95)

### StatusBar

펫의 상태(hunger, happiness, stamina)를 시각적으로 표시하는 컴포넌트입니다.

**사용 예시:**
```dart
StatusBar(
  label: 'Hunger',
  value: 75,
  color: StatusBarColor.hunger,
  icon: Icons.restaurant,
)
```

**Props:**
- `label`: `String` - 상태바 라벨
- `value`: `int` - 상태 값 (0~100)
- `color`: `StatusBarColor` - 색상 타입 (hunger, happiness, stamina)
- `icon`: `IconData?` - 아이콘 (선택사항)

**애니메이션:**
- 값 변경 시 부드러운 너비 애니메이션 (800ms)
- 글로우 효과 적용

### GlassCard

글래스모피즘 효과를 가진 카드 컴포넌트입니다.

**사용 예시:**
```dart
GlassCard(
  gradient: true,
  padding: EdgeInsets.all(24),
  child: Column(
    children: [
      // 내용
    ],
  ),
)
```

**Props:**
- `child`: `Widget` (필수)
- `gradient`: `bool` - 그라디언트 오버레이 적용 여부
- `padding`: `EdgeInsetsGeometry?` - 추가 패딩
- `margin`: `EdgeInsetsGeometry?` - 추가 마진

**스타일:**
- 반투명 배경 (`glassBackground`)
- 테두리 (`glassBorder`)
- 그림자 효과
- 선택적 그라디언트 오버레이

### PetImageAnimation

펫의 상태에 따라 다른 이미지를 애니메이션으로 표시하는 컴포넌트입니다.

**사용 예시:**
```dart
PetImageAnimation(
  type: PetImageType.sleeping,
  size: 192,
  duration: Duration(milliseconds: 800),
)
```

**Props:**
- `type`: `PetImageType` - 이미지 타입 (normal, sleeping, hungry)
- `size`: `double` - 이미지 크기 (기본값: 192)
- `duration`: `Duration` - 애니메이션 속도 (기본값: 800ms)

**이미지 타입:**
- `PetImageType.sleeping`: `sleeping_1.png`, `sleeping_2.png`, `sleeping_3.png`
- `PetImageType.hungry`: `hungry_1.png`, `hungry_2.png`, `hungry_3.png`
- `PetImageType.normal`: 기본 상태 (현재는 sleeping 이미지 사용)

**애니메이션:**
- 3장의 이미지를 순환하여 표시
- 각 이미지가 약 0.8초씩 표시 (총 2.4초 주기)

### PetCard

펫 정보를 카드 형태로 표시하는 컴포넌트입니다.

---

## 애니메이션

### 펫 이미지 애니메이션

**동작:**
- 3장의 이미지를 순환하여 표시
- 각 이미지가 일정 시간 동안 표시된 후 다음 이미지로 전환
- 애니메이션 컨트롤러를 사용하여 부드러운 전환

**타입별 동작:**
- **Sleeping**: 잠자는 이미지 3장 순환
- **Hungry**: 배고픈 이미지 3장 순환
- **Normal**: 기본 이미지 (현재는 sleeping 이미지 사용)

### 상태바 애니메이션

**동작:**
- 값 변경 시 너비 애니메이션 (800ms)
- `Curves.easeOut` 커브 사용
- 글로우 효과로 시각적 피드백 제공

### 버튼 애니메이션

**동작:**
- 탭 다운 시 스케일 다운 (0.95)
- 탭 업 시 원래 크기로 복귀
- 100ms 애니메이션 지속 시간

---

## 레이아웃 가이드

### 화면 크기

- 최대 너비: 390px (모바일 최적화)
- SafeArea 적용으로 노치/상태바 고려

### 간격 시스템

```dart
// 작은 간격
const SizedBox(height: 8)

// 기본 간격
const SizedBox(height: 16)

// 큰 간격
const SizedBox(height: 24)
const SizedBox(height: 32)
```

### 패딩

```dart
// 카드 내부 패딩
padding: EdgeInsets.all(24)

// 화면 패딩
padding: EdgeInsets.all(24)

// 버튼 패딩
padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16)
```

### 모서리 둥글기

```dart
// 작은 둥글기
BorderRadius.circular(16)

// 기본 둥글기
BorderRadius.circular(24)

// 큰 둥글기
BorderRadius.circular(28)
```

### 그림자

```dart
// 기본 그림자
BoxShadow(
  color: Colors.black.withValues(alpha: 0.3),
  blurRadius: 20,
  spreadRadius: 0,
)

// 글로우 효과
BoxShadow(
  color: AppColors.primaryGlow,
  blurRadius: 20,
  spreadRadius: 0,
)
```

---

## 이미지 에셋

### 펫 이미지

**잠자는 이미지:**
- `assets/sleeping_1.png`
- `assets/sleeping_2.png`
- `assets/sleeping_3.png`

**배고픈 이미지:**
- `assets/hungry_1.png`
- `assets/hungry_2.png`
- `assets/hungry_3.png`
- `assets/hungry_4.png` (현재 미사용)

**사용 규칙:**
- 기본 상태: 잠자는 이미지 표시
- Sleep 버튼 클릭: 잠자는 이미지로 전환
- Feed 버튼 클릭: 배고픈 이미지로 전환 (3초 후 잠자는 이미지로 복귀)

---

## 사용자 인터랙션

### Feed 액션

1. 사용자가 Feed 버튼 클릭
2. 펫 이미지가 배고픈 이미지로 전환
3. `hunger` 값이 +10 증가 (최대 100)
4. 3초 후 자동으로 잠자는 이미지로 복귀

### Sleep 액션

1. 사용자가 Sleep 버튼 클릭
2. 펫 이미지가 잠자는 이미지로 전환
3. `stamina` 값이 +10 증가 (최대 100)
4. 계속 잠자는 이미지 유지

### Play 액션

1. 사용자가 Play 버튼 클릭
2. `happiness` 값이 +10 증가 (최대 100)
3. 펫 이미지는 변경되지 않음 (현재 구현)

---

## 접근성

### 색상 대비

- 텍스트와 배경 간 충분한 대비 확보
- 상태바 색상은 명확하게 구분 가능

### 터치 영역

- 버튼 최소 크기: 44x44dp
- 충분한 패딩으로 터치 영역 확보

---

## 성능 최적화

### 이미지 최적화

- PNG 형식 사용
- 적절한 해상도로 리사이즈
- 애니메이션은 3장의 이미지만 사용하여 메모리 효율적

### 애니메이션 최적화

- `SingleTickerProviderStateMixin` 사용으로 애니메이션 컨트롤러 관리
- 불필요한 리빌드 방지를 위한 `AnimatedBuilder` 사용
- 애니메이션 완료 후 컨트롤러 정리 (`dispose`)

---

## 참고 자료

- 디자인 원본: `design/` 폴더의 React 컴포넌트
- 색상 정의: `lib/core/theme/app_colors.dart`
- 테마 정의: `lib/core/theme/app_theme.dart`
- 위젯 구현: `lib/presentation/widgets/`
- 화면 구현: `lib/presentation/screens/`
