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

  // 알림 메시지
  static const String notificationTitle = '내 펫';
  static const String notificationInactive = '오늘 나 안 볼거야?';
  static const String notificationHungry = '나 너무 배고파...';
  static const String notificationBored = '나 심심해...';
  static const String notificationFeedTime = '밥 먹을 시간이에요! 🍽️';

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
