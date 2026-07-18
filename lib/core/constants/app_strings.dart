/// 앱 문자열 상수
/// 한국어 현지화를 위한 문자열 모음
///
/// 실제 참조되는 상수만 유지한다 (미사용 상수는 UI 정리 때 일괄 제거).
class AppStrings {
  AppStrings._(); // private constructor

  // 펫 상태 (mood)
  static const String moodHappy = '행복';
  static const String moodNormal = '보통';
  static const String moodHungry = '배고픔';
  static const String moodSleepy = '졸림';
  static const String moodTired = '지침';
  static const String moodSad = '시무룩';
  // 사망이 아니라 "긴 잠" 컨셉 — 위젯(PetWidgetProvider.kt)과 동일 표기 유지
  static const String moodDead = '긴 잠';

  // 액션
  static const String feed = '먹이주기';

  // 대체 케어
  static const String shakeBonusInProgress = '폰을 흔드세요!';
  static const String shakeBonusComplete = '흔들기 완료';
  static const String napModeRunning = '낮잠 모드 진행 중';

  // 알림 메시지 — 펫 1인칭 + 가벼운 제안 톤 (PM_REVIEW.md 톤 가이드)
  // 죄책감 유발("안 볼거야?", "굶고 있어요")·명령형·재촉 표현 금지
  static const String notificationTitle = '내 펫';
  static const String notificationInactive = '보고 싶었어! 오늘 이야기 들려줄래?';
  static const String notificationHungry = '배가 살짝 고파졌어. 간식 있을까?';
  static const String notificationBored = '몸이 근질근질해! 같이 산책 갈까?';
  static const String notificationFeedTime = '맛있는 밥 시간이야, 같이 먹자 🍽️';

  // 진화 단계 카테고리 라벨 (털뭉치 → 유아기 → 성장기 → 성숙기)
  static const Map<int, String> stageLabels = {
    1: '털뭉치',
    2: '유아기',
    3: '성장기',
    4: '성숙기',
  };

  // 진화 단계별 이름
  static const Map<String, String> stage2Names = {
    'bird': '아기새', 'snake': '아기뱀', 'tiger': '아기범', 'turtle': '아기거북',
  };
  static const Map<String, Map<String, String>> stage3Names = {
    'bird': {'normal': '독수리', 'superior': '봉황'},
    'snake': {'normal': '뱀', 'superior': '이무기'},
    'tiger': {'normal': '호랑이', 'superior': '맹호'},
    'turtle': {'normal': '바다거북', 'superior': '영귀'},
  };
  // 성숙기: 잘 키우면 사신수(mythical), 아니면 그냥 동물(normal)
  static const Map<String, Map<String, String>> stage4Names = {
    'bird': {'normal': '수리', 'mythical': '주작 \u{1F525}'},
    'snake': {'normal': '구렁이', 'mythical': '청룡 \u{1F409}'},
    'tiger': {'normal': '호랑이', 'mythical': '백호 \u{26A1}'},
    'turtle': {'normal': '왕거북', 'mythical': '현무 \u{1F30A}'},
  };

  // 대결
  static const String battleVictory = '승리!';
  static const String battleDefeat = '패배!';

  // 진화
  static const String evolutionEvolving = '진화 중...';
  static const String evolutionEvolveNow = '지금 진화하기';

  // 종 결정 연출 (SpeciesRevealScreen — 서사 본문은 SpeciesRevealNarrator가 생성)
  static const String speciesRevealBadge = '사신수 각성';
  static const String speciesRevealConfirm = '만나러 가기';

  // 온보딩 (OnboardingScreen — 이름 짓기 → 권한 → 첫 목표 → 위젯 유도)
  static const String onboardWelcomeTitle = '작은 친구가 깨어났어요';
  static const String onboardWelcomeBody =
      '함께 걷고, 먹고, 잘수록 무럭무럭 자라요.\n어떤 모습으로 클지는 당신의 하루에 달렸어요.';
  static const String onboardNameHint = '이름을 지어주세요';
  static const String onboardNameButton = '이름 지어주기';
  static const String onboardPermissionTitle = '같이 걸어줄래?';
  static const String onboardPermissionBody =
      '걸음을 알아야 내가 자랄 수 있어.\n걸음 측정 권한만 켜주면 돼!';
  static const String onboardPermissionButton = '걸음 측정 켜기';
  static const String onboardPermissionSkip = '나중에 할게';
  static const String onboardGoalTitle = '오늘 우리의 첫 목표';
  static const String onboardGoalBody = '가볍게 시작해요. 셋 다 채우면 첫 보상이 기다려요!';
  static const String onboardGoalButton = '좋아, 해볼게';
  static const String onboardWidgetTitle = '홈 화면에서도 만나요';
  static const String onboardWidgetBody =
      '위젯을 두면 앱을 열지 않아도\n내 기분이 보여요. 폰은 덜 보고, 나는 자주 보고!';
  static const String onboardWidgetButton = '위젯 추가하기';
  static const String onboardWidgetSkip = '나중에';
  static const String onboardWidgetUnsupported =
      '이 기기에서는 홈 화면 편집에서 직접 추가해 주세요.';

  // 긴 잠/깨우기 (사망·부활 리프레이밍 — 돌아온 유저를 벌하지 않는다)
  static const String longSleepTitle = '깊은 잠에 빠졌어요';
  static const String longSleepHint = '오래 혼자 있으면 긴 잠에 들어요.\n깨워주면 다시 함께할 수 있어요!';
  static const String longSleepSinceLabel = '잠든 날';
  static const String wakeFreeButton = '쓰다듬어 깨우기';
  static const String wakeAdButton = '간식으로 깨우기 (광고 · 완전 회복)';
  static const String wakeSuccess = '깨어났어요! "보고 싶었어!"';
  static const String adLoadFailed = '광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  // 새로 키우기(초기화)
  static const String restartButton = '처음부터 새로 키우기';
  static const String restartConfirmTitle = '새로 키우기';
  static const String restartConfirmBody =
      '지금까지 키운 펫은 사라지고 처음부터 다시 시작해요.\n광고를 본 뒤 새 펫으로 시작할까요?';
  static const String restartConfirm = '광고 보고 시작';
  static const String restartCancel = '취소';
  static const String restartSuccess = '새로운 펫과 함께 시작해요!';

  // 일일 이벤트
  static const Map<String, String> eventNames = {
    'sunny': '맑은 날 - 걸음 보상 1.5배',
    'cozy': '포근한 날 - 수면 회복 1.5배',
    'tasty': '맛있는 날 - 식사 회복 +5',
    'happy_day': '행복한 날 - Decay 절반',
    'adventure': '모험의 날 - 배틀 EXP 2배',
    'normal': '평범한 날',
  };

  // 에러 메시지
  static const String error = '오류';
  static const String retry = '다시 시도';
}
