/// 앱 문자열 상수
/// 한국어 현지화를 위한 문자열 모음
class AppStrings {
  AppStrings._(); // private constructor
  
  // 상태 라벨
  static const String hunger = '포만감';
  static const String happiness = '운동';
  static const String stamina = '수면';
  static const String level = '레벨';
  
  // 펫 상태
  static const String moodHappy = '기쁨';
  static const String moodSleepy = '졸림';
  static const String moodHungry = '배고픔';
  static const String moodBored = '지루함';
  static const String moodNormal = '보통';
  static const String moodEnergetic = '활기참';
  static const String moodTired = '피곤함';
  static const String moodFull = '배부름';
  static const String moodAnxious = '불안함';
  static const String moodSatisfied = '만족함';
  static const String moodDead = '사망';
  
  // 화면 제목
  static const String home = '홈';
  static const String evolution = '진화';
  static const String battle = '대결';
  static const String share = '공유';
  
  // 버튼 (자동화로 인해 사용되지 않지만 호환성을 위해 유지)
  static const String feed = '먹이주기';
  static const String play = '놀아주기';
  static const String sleep = '재우기';
  static const String alternativeCareTitle = '대체 케어';
  static const String alternativeFeed = '간편 급식';
  static const String alternativeSleep = '낮잠 모드 15분';
  static const String alternativeExercise = '실내 운동 1분';
  static const String alternativeExerciseRunning = '운동 진행 중';
  static const String snackTimeGuide = '간식 시간: 10-11시, 15-16시, 20-21시';
  static const String napModeRunning = '낮잠 모드 진행 중';
  
  // 알림 메시지
  static const String notificationTitle = '내 펫';
  static const String notificationInactive = '오늘 나 안 볼거야?';
  static const String notificationHungry = '나 너무 배고파...';
  static const String notificationBored = '나 심심해...';
  static const String notificationFeedTime = '밥 먹을 시간이에요! 🍽️';
  
  // 진화 단계
  static const String evolutionStage1 = '털뭉치';
  static const String evolutionStage2 = '성장';
  static const String evolutionStage3 = '완성';
  
  // 진화 방향
  static const String evolutionTypeActive = '활동형';
  static const String evolutionTypeRestful = '휴식형';
  static const String evolutionTypeBalanced = '균형형';
  
  // 대결
  static const String battleArena = '대결 아레나';
  static const String battleTurn = '턴';
  static const String battleYourTurn = '당신의 턴';
  static const String battleAttack = '공격';
  static const String battleDefend = '방어';
  static const String battleVictory = '승리!';
  static const String battleDefeat = '패배!';
  static const String battleWon = '대결에서 승리했습니다!';
  static const String battleLost = '다음엔 더 잘할 수 있을 거예요!';
  static const String battleStarted = '대결 시작!';
  
  // 진화 화면
  static const String evolutionReady = '펫을 진화시킬 준비가 되었나요?';
  static const String evolutionCurrent = '현재';
  static const String evolutionNextStage = '다음 단계';
  static const String evolutionRequirements = '진화 요구사항';
  static const String evolutionLevelRequired = '레벨 15 이상';
  static const String evolutionCurrentLevel = '현재 레벨';
  static const String evolutionEvolving = '진화 중...';
  static const String evolutionEvolved = '진화 완료!';
  static const String evolutionEvolveNow = '지금 진화하기';
  
  // 공유 화면
  static const String shareYourPet = '펫 공유하기';
  static const String shareSubtitle = '친구들에게 내 펫을 소개해보세요';
  static const String shareHappy = '운동';
  static const String shareFed = '포만감';
  static const String shareEnergy = '수면';
  static const String shareToFriends = '친구에게 공유하기';
  static const String downloadCard = '카드 다운로드';
  static const String shareInfo = '펫을 친구들에게 공유하면 특별한 보상을 받을 수 있어요!';
  
  // 사망/부활
  static const String petDead = '사망';
  static const String gravestoneTitle = '여기 잠들다';
  static const String resurrectButton = '부활하기 (광고 시청)';
  static const String resurrectSuccess = '펫이 부활했어요!';
  static const String deathWarning = '수치가 모두 0이에요! 3일 안에 회복하지 않으면...';
  static const String deathNotification = '펫이 죽었어요... 부활시켜 주세요.';

  // 일일 이벤트
  static const Map<String, String> eventNames = {
    'sunny': '맑은 날 - 걸음 보상 1.5배',
    'cozy': '포근한 날 - 수면 회복 1.5배',
    'tasty': '맛있는 날 - 식사 회복 +5',
    'happy_day': '행복한 날 - Decay 절반',
    'adventure': '모험의 날 - 배틀 EXP 2배',
    'normal': '평범한 날',
  };

  // 목표 기간
  static const String goalPeriod = '목표 기간';
  static const String goalStreak = '연속 달성';
  static const String goalExpired = '목표 기간 만료! 페널티가 적용됩니다.';
  static const String goalStreakBonus = '연속 달성 보너스!';
  static const String goalDaysRemaining = '남은 기간';

  // 에러 메시지
  static const String error = '오류';
  static const String retry = '다시 시도';
}
