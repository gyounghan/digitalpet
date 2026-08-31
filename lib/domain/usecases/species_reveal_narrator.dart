import '../entities/evolution_type.dart';
import '../entities/pet.dart';
import 'evolution_axis_scores.dart';

/// 종 결정 연출용 서사 묶음
///
/// [title] — "당신의 생활이 백호를 깨웠어요" (풀스크린 헤드라인)
/// [reasonLines] — 판정 근거 2줄 (활발/차분 축 1줄 + 규칙/자유 축 1줄)
/// [personality] — 종 성격 한 줄 (숫자 대신 캐릭터성으로)
class SpeciesRevealStory {
  final EvolutionType type;
  final String speciesLabel;
  final String title;
  final List<String> reasonLines;
  final String personality;

  const SpeciesRevealStory({
    required this.type,
    required this.speciesLabel,
    required this.title,
    required this.reasonLines,
    required this.personality,
  });
}

/// 종 결정 순간의 판정 근거 서사 생성기 (순수 함수)
///
/// 톤 규칙 (PM_REVIEW.md §8):
/// - 판정 근거는 실제 누적 데이터를 언급한다 ("함께 걸은 12,400보")
/// - 수치가 아직 없으면 성향 서술로 폴백 (거짓 수치 금지)
/// - 점수 공식은 [EvolutionAxisScores] 단일 소스 — 실제 종 판정과 어긋나지 않는다
class SpeciesRevealNarrator {
  SpeciesRevealNarrator._();

  /// 종 결정 서사 생성
  ///
  /// [pet.evolutionType]이 이미 결정돼 있으면 그 종을 따르고,
  /// 아직이면 축 점수로 판정한다 (연출 미리보기 등).
  static SpeciesRevealStory narrate(Pet pet) {
    final scores = EvolutionAxisScores.fromPet(pet);
    final type = pet.evolutionType ?? scores.resultType;
    final label = _speciesLabel(type);

    return SpeciesRevealStory(
      type: type,
      speciesLabel: label,
      title: '당신의 생활이\n$label${objectParticle(label)} 깨웠어요',
      reasonLines: [
        _activityAxisLine(type, pet),
        _rhythmAxisLine(type, pet),
      ],
      personality: _personality(type),
    );
  }

  /// 활발/차분 축 근거 1줄 — 종이 속한 축 기준
  static String _activityAxisLine(EvolutionType type, Pet pet) {
    final isActiveType = type == EvolutionType.tiger ||
        type == EvolutionType.bird ||
        type == EvolutionType.samjoko ||
        type == EvolutionType.dokkaebi;
    if (isActiveType) {
      if (pet.totalSteps >= 1000) {
        return '함께 걸은 ${formatNumber(pet.totalSteps)}보가 활발한 기운을 키웠어요';
      }
      return '부지런히 몸을 움직인 나날이 활발한 기운을 키웠어요';
    }
    if (pet.sleepAchievedCount > 0) {
      return '포근하게 잠든 ${pet.sleepAchievedCount}번의 밤이 차분한 기운을 키웠어요';
    }
    return '느긋하게 쉬어 간 시간들이 차분한 기운을 키웠어요';
  }

  /// 규칙/자유 축 근거 1줄 — 종이 속한 축 기준
  static String _rhythmAxisLine(EvolutionType type, Pet pet) {
    final isRegularType = type == EvolutionType.tiger ||
        type == EvolutionType.turtle ||
        type == EvolutionType.haetae ||
        type == EvolutionType.hwangryong;
    if (isRegularType) {
      if (pet.consecutiveLoginDays > 1) {
        return '${pet.consecutiveLoginDays}일 연속 찾아와 준 꾸준함이 더해졌어요';
      }
      return '하루하루 빼먹지 않는 꾸준함이 더해졌어요';
    }
    if (pet.feedAchievedCount > 0) {
      return '자유롭게 챙겨 준 ${pet.feedAchievedCount}번의 식사가 여유를 더했어요';
    }
    return '자기만의 리듬으로 지낸 여유가 더해졌어요';
  }

  /// 종 성격 한 줄 — 도감·연출 공용 캐릭터성 서술
  static String _personality(EvolutionType type) {
    switch (type) {
      case EvolutionType.bird:
        return '신나는 걸 좋아하는 기동형 친구예요';
      case EvolutionType.snake:
        return '느긋하고 영리한 마법형 친구예요';
      case EvolutionType.tiger:
        return '몸 쓰는 걸 좋아하는 든든한 전투형 친구예요';
      case EvolutionType.turtle:
        return '차분하고 묵직한 방어형 친구예요';
      case EvolutionType.samjoko:
        return '태양을 향해 달리는 전설의 걸음꾼이에요';
      case EvolutionType.gumiho:
        return '맛있는 것 앞에선 못 참는 미식가 여우예요';
      case EvolutionType.moonrabbit:
        return '달빛 아래 꿀잠이 특기인 몽글한 친구예요';
      case EvolutionType.haetae:
        return '하루도 빠짐없이 곁을 지키는 수호수예요';
      case EvolutionType.dokkaebi:
        return '싸움도 장난처럼 즐기는 개구쟁이예요';
      case EvolutionType.hwangryong:
        return '무엇 하나 빠짐없는 오방의 중심이에요';
    }
  }

  /// 사신수 한국어 이름 (연출은 아기 단계여도 "깨어난 사신수"로 부른다)
  static String _speciesLabel(EvolutionType type) {
    switch (type) {
      case EvolutionType.bird:
        return '주작';
      case EvolutionType.snake:
        return '청룡';
      case EvolutionType.tiger:
        return '백호';
      case EvolutionType.turtle:
        return '현무';
      case EvolutionType.samjoko:
        return '삼족오';
      case EvolutionType.gumiho:
        return '구미호';
      case EvolutionType.moonrabbit:
        return '달토끼';
      case EvolutionType.haetae:
        return '해태';
      case EvolutionType.dokkaebi:
        return '도깨비';
      case EvolutionType.hwangryong:
        return '황룡';
    }
  }

  /// 목적격 조사 선택 — 받침 있으면 '을', 없으면 '를'
  ///
  /// 한글 음절(가~힣)만 판정하며, 그 외 문자는 '를'로 폴백.
  static String objectParticle(String word) {
    if (word.isEmpty) return '를';
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return '를';
    return (code - 0xAC00) % 28 != 0 ? '을' : '를';
  }

  /// 천 단위 콤마 표기 (12400 → '12,400')
  static String formatNumber(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }
}
