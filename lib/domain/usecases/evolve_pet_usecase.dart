import '../entities/pet.dart';
import '../entities/evolution_type.dart';
import '../repositories/pet_repository.dart';
import 'evolution_axis_scores.dart';

/// 반려동물 진화 유스케이스 (사신수 진화 트리)
///
/// 진화 단계 (4단계):
/// - 1단계: 털뭉치 (evolutionStage = 1, 기본 상태)
/// - 2단계: 아기 종 (evolutionStage = 2, Lv5 → 활동량×규칙성으로 종 결정)
/// - 3단계: normal / superior (evolutionStage = 3, Lv10 → 종별 추가 조건)
/// - 4단계: mythical (evolutionStage = 4, Lv15 → superior만 승격 가능)
///
/// 진화 종 (EvolutionType):
/// - bird (주작): 활발+자유 패턴
/// - snake (청룡): 차분+자유 패턴
/// - tiger (백호): 활발+규칙 패턴
/// - turtle (현무): 차분+규칙 패턴
///
/// 진화 등급 (evolutionGrade):
/// - '': 미결정 (1단계)
/// - 'normal': 일반 (3단계 기본)
/// - 'superior': 상위 (3단계 우수)
/// - 'mythical': 신수 (4단계, superior에서만 승격)
class EvolvePetUseCase {
  final PetRepository petRepository;

  EvolvePetUseCase(this.petRepository);

  /// 진화 체크 및 실행
  Future<Pet> call(String petId) async {
    final pet = await petRepository.getPet(petId);
    if (pet.isDead) return pet;

    int newStage = pet.evolutionStage;
    EvolutionType? newType = pet.evolutionType;
    String newGrade = pet.evolutionGrade;

    // 단조 상향: 3단계 normal이 이후 superior 조건을 충족하면 승격(하향 없음).
    // Lv10~14 동안 매 진화 체크마다 재평가되므로, 조건을 늦게 채워도
    // 신수(mythical) 루트를 탈 수 있다. superior는 절대 normal로 내려가지 않는다.
    if (newStage == 3 &&
        newGrade == 'normal' &&
        _determineStage3Grade(pet) == 'superior') {
      newGrade = 'superior';
    }

    // 4단계(성숙기): Lv15에서 등급으로 최종 형태 분기.
    // - superior + 신수 조건 충족 → 사신수(mythical)
    // - normal → 그냥 동물(일반종). 잘 못 키우면 사신수가 아닌 일반종이 된다.
    // - superior인데 신수 조건 미달 → 성장기 유지(계속 도전)
    // (등급 판정은 위에서 갱신한 newGrade 기준 — 같은 틱에 승격되면 신수 도전 가능)
    if (pet.level >= 15 && newStage < 4 && newStage >= 3) {
      if (newGrade == 'superior' && _meetsStage4Condition(pet)) {
        newStage = 4;
        newGrade = 'mythical';
      } else if (newGrade == 'normal') {
        newStage = 4;
        newGrade = 'normal';
      }
    }
    // 3단계: Lv10 + 종별 조건 → normal / superior
    else if (pet.level >= 10 && newStage < 3 && newStage >= 2) {
      final grade = _determineStage3Grade(pet);
      if (grade.isNotEmpty) {
        newStage = 3;
        newGrade = grade;
      }
    }
    // 2단계: Lv5 + 활동 패턴으로 종 결정
    else if (pet.level >= 5 && newStage < 2) {
      newStage = 2;
      newType = _determineEvolutionType(pet);
      newGrade = '';
    }

    if (newStage == pet.evolutionStage &&
        newType == pet.evolutionType &&
        newGrade == pet.evolutionGrade) {
      return pet;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final evolvedPet = pet.copyWith(
      evolutionStage: newStage,
      evolutionType: newType,
      evolutionGrade: newGrade,
      lastUpdated: currentTime,
    );

    await petRepository.updatePet(evolvedPet);
    return evolvedPet;
  }

  /// 2단계 진화 종 결정 (활발 × 규칙/자유 매트릭스)
  ///
  /// 세트 클리어 방식에선 포만감/수면/운동 달성 카운트가 함께 오르므로,
  /// 단순 카운트 비교는 종이 한쪽으로 쏠린다. 그래서 사용자가 실제로
  /// 다르게 행동하는 "원천 지표"를 정규화해 두 축으로 판정한다.
  ///
  /// 점수 공식·축 정의는 [EvolutionAxisScores]가 단일 소스 —
  /// 종 결정 연출(SpeciesRevealNarrator)의 판정 근거 문구와 항상 일치한다.
  EvolutionType _determineEvolutionType(Pet pet) {
    return EvolutionAxisScores.fromPet(pet).resultType;
  }

  /// 3단계 등급 결정 (종별 조건 — 종 대칭 · 누적 성취 게이팅)
  ///
  /// 각 종을 정의한 **두 축**(활발/차분 × 규칙/자유)을 동일 임계값으로 요구한다.
  /// "이 종이 된 방식대로 꾸준히 잘 키웠나"를 누적 달성 카운터로 판정 —
  /// 변동 스냅샷(happiness/stamina)이나 특정 종만 유리한 전투 게이트를 쓰지 않는다.
  ///
  /// 축별 임계값 — 실측 페이싱에 정렬:
  /// 세트 클리어 유저는 일 ~140 EXP로 Lv10을 약 7일에 도달한다(시뮬레이션 실측).
  /// 축당 하루 1~2달성이므로 임계값 8이면 "꾸준히 키운 유저"가 Lv10 도달
  /// 시점(±수일)에 superior 판정을 받는다. 놓쳐도 단조 상향으로 이후 승격.
  ///   활발 exerciseAchievedCount>=[_supActive], 차분 sleepAchievedCount>=[_supCalm],
  ///   자유 feedAchievedCount>=[_supFree],       규칙 consecutiveLoginDays>=[_supRegular]
  ///
  /// bird  (활발+자유): 운동 && 급식 달성
  /// snake (차분+자유): 수면 && 급식 달성
  /// tiger (활발+규칙): 운동 && 연속접속
  /// turtle(차분+규칙): 수면 && 연속접속
  static const int _supActive = 8;
  static const int _supCalm = 8;
  static const int _supFree = 8;
  static const int _supRegular = 7;

  String _determineStage3Grade(Pet pet) {
    final bool superior;
    switch (pet.evolutionType) {
      case EvolutionType.bird:
        superior = pet.exerciseAchievedCount >= _supActive &&
            pet.feedAchievedCount >= _supFree;
        break;
      case EvolutionType.snake:
        superior = pet.sleepAchievedCount >= _supCalm &&
            pet.feedAchievedCount >= _supFree;
        break;
      case EvolutionType.tiger:
        superior = pet.exerciseAchievedCount >= _supActive &&
            pet.consecutiveLoginDays >= _supRegular;
        break;
      case EvolutionType.turtle:
        superior = pet.sleepAchievedCount >= _supCalm &&
            pet.consecutiveLoginDays >= _supRegular;
        break;
      default:
        return 'normal';
    }
    return superior ? 'superior' : 'normal';
  }

  /// 4단계 mythical 조건 충족 여부 (superior에서만 승격 가능 — 종 대칭)
  ///
  /// superior와 같은 두 축을 더 높은 누적 임계값으로 요구한다.
  /// 세트 클리어 유저 Lv15 ≈ 17일(실측) 기준: 축 20은 하루 1달성이면 20일,
  /// 2달성이면 10일 → Lv15 도달 직후~수일 내 사신수 진화가 가능해
  /// "잘 키웠는데 일반종보다 한참 늦게 진화"하는 대기 구간을 없앤다.
  ///   활발 exerciseAchievedCount>=[_mythActive], 차분 sleepAchievedCount>=[_mythCalm],
  ///   자유 feedAchievedCount>=[_mythFree],       규칙 consecutiveLoginDays>=[_mythRegular]
  ///
  /// bird(봉황→주작):   운동 && 급식
  /// snake(이무기→청룡): 수면 && 급식
  /// tiger(맹호→백호):   운동 && 연속접속
  /// turtle(영귀→현무):  수면 && 연속접속
  static const int _mythActive = 20;
  static const int _mythCalm = 20;
  static const int _mythFree = 20;
  static const int _mythRegular = 14;

  bool _meetsStage4Condition(Pet pet) {
    switch (pet.evolutionType) {
      case EvolutionType.bird:
        return pet.exerciseAchievedCount >= _mythActive &&
            pet.feedAchievedCount >= _mythFree;
      case EvolutionType.snake:
        return pet.sleepAchievedCount >= _mythCalm &&
            pet.feedAchievedCount >= _mythFree;
      case EvolutionType.tiger:
        return pet.exerciseAchievedCount >= _mythActive &&
            pet.consecutiveLoginDays >= _mythRegular;
      case EvolutionType.turtle:
        return pet.sleepAchievedCount >= _mythCalm &&
            pet.consecutiveLoginDays >= _mythRegular;
      default:
        return false;
    }
  }

  /// 진화 가능 여부 확인
  bool canEvolve(Pet pet) {
    if (pet.isDead) return false;

    // 4단계(성숙기) 진화 가능? normal은 항상 일반종으로, superior는 신수 조건 충족 시.
    if (pet.level >= 15 && pet.evolutionStage < 4 && pet.evolutionStage >= 3) {
      if (pet.evolutionGrade == 'normal') return true;
      return pet.evolutionGrade == 'superior' && _meetsStage4Condition(pet);
    }
    // 3단계 진화 가능?
    if (pet.level >= 10 && pet.evolutionStage < 3 && pet.evolutionStage >= 2) {
      return true; // 3단계는 항상 normal 이상으로 진화 가능
    }
    // 3단계 normal → superior 상향 가능? (단조 상향)
    if (pet.evolutionStage == 3 &&
        pet.evolutionGrade == 'normal' &&
        _determineStage3Grade(pet) == 'superior') {
      return true;
    }
    // 2단계 종 결정 가능?
    if (pet.level >= 5 && pet.evolutionStage < 2) {
      return true;
    }
    return false;
  }
}
