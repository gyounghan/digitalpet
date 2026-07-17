import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/usecases/battle_result_narrator.dart';

BattleNarration _narrate({
  bool isVictory = true,
  bool isDominantVictory = false,
  int playerHpRemaining = 80,
  int playerMaxHp = 100,
  int hunger = 50,
  int happiness = 50,
  int stamina = 50,
  int todaySteps = 0,
  bool affinityAdvantage = false,
}) {
  return BattleResultNarrator.narrate(
    isVictory: isVictory,
    isDominantVictory: isDominantVictory,
    playerHpRemaining: playerHpRemaining,
    playerMaxHp: playerMaxHp,
    hunger: hunger,
    happiness: happiness,
    stamina: stamina,
    todaySteps: todaySteps,
    affinityAdvantage: affinityAdvantage,
  );
}

void main() {
  group('BattleResultNarrator 헤드라인', () {
    test('압승 → 완벽한 컨디션', () {
      final n = _narrate(isVictory: true, isDominantVictory: true);
      expect(n.headline, '완벽한 컨디션이었어!');
    });

    test('승리 → 노력이 빛났어', () {
      final n = _narrate(isVictory: true);
      expect(n.headline, '오늘의 노력이 빛났어!');
    });

    test('패배 → 성장 프레임 (패배 단어 없음)', () {
      final n = _narrate(isVictory: false);
      expect(n.headline, '아쉽지만, 한 뼘 성장했어!');
    });
  });

  group('승리 해설 — HP·걸음 서사', () {
    test('HP 절반 이상 + 1000보 이상이면 실제 걸음 수를 언급', () {
      final n = _narrate(
          playerHpRemaining: 60, playerMaxHp: 100, todaySteps: 8200);
      expect(n.lines.first, contains('8200보'));
      expect(n.lines.first, contains('버텨줬어'));
    });

    test('HP 절반 이상 + 걸음이 적으면 걸음 수 언급 없이 칭찬', () {
      final n = _narrate(
          playerHpRemaining: 60, playerMaxHp: 100, todaySteps: 300);
      expect(n.lines.first, isNot(contains('보를')));
      expect(n.lines.first, contains('버텨줬어'));
    });

    test('HP 절반 미만이면 아슬아슬 서사', () {
      final n = _narrate(playerHpRemaining: 20, playerMaxHp: 100);
      expect(n.lines.first, contains('아슬아슬'));
    });
  });

  group('승리 해설 — 컨디션 칭찬', () {
    test('행복 70 이상이면 공격 칭찬 (최우선)', () {
      final n = _narrate(happiness: 80, stamina: 90, hunger: 90);
      expect(n.lines, contains('행복이 가득해서 공격이 잘 먹혔어.'));
    });

    test('행복이 낮고 기력 70 이상이면 방어 칭찬', () {
      final n = _narrate(happiness: 50, stamina: 75, hunger: 50);
      expect(n.lines, contains('기력이 좋아서 방어를 잘했어.'));
    });

    test('행복·기력이 낮고 포만감 70 이상이면 지구력 칭찬', () {
      final n = _narrate(happiness: 50, stamina: 50, hunger: 75);
      expect(n.lines, contains('든든하게 먹어둔 덕에 지치지 않았어.'));
    });

    test('모든 스탯이 70 미만이면 칭찬 줄 없음', () {
      final n = _narrate(happiness: 50, stamina: 50, hunger: 50);
      expect(n.lines.length, 1);
    });
  });

  group('승리 해설 — 상성', () {
    test('상성 유리 시 한 줄 추가', () {
      final n = _narrate(affinityAdvantage: true);
      expect(n.lines, contains('사신수 상성도 우리 편이었어!'));
    });

    test('상성 무관 시 언급 없음', () {
      final n = _narrate(affinityAdvantage: false);
      expect(n.lines.any((l) => l.contains('상성')), false);
    });
  });

  group('패배 해설 — 원인 + 처방 세트', () {
    test('포만감 최저 → 밥 처방', () {
      final n = _narrate(
          isVictory: false, hunger: 30, happiness: 60, stamina: 60);
      expect(n.lines.first, contains('포만감이 낮아서'));
      expect(n.lines.first, contains('밥을 챙기면'));
    });

    test('행복 최저 → 산책 처방', () {
      final n = _narrate(
          isVictory: false, hunger: 60, happiness: 30, stamina: 60);
      expect(n.lines.first, contains('산책하면 공격이 강해질'));
    });

    test('기력 최저 → 휴식 처방', () {
      final n = _narrate(
          isVictory: false, hunger: 60, happiness: 60, stamina: 30);
      expect(n.lines.first, contains('폰을 내려놓고 쉬면'));
    });

    test('전 스탯이 좋았는데 패배 → 상대가 강했다는 프레임', () {
      final n = _narrate(
          isVictory: false, hunger: 90, happiness: 90, stamina: 90);
      expect(n.lines.first, contains('상대가 한 수 위였어'));
    });

    test('패배 시에도 잘한 점을 하나 짚어준다', () {
      final n = _narrate(
          isVictory: false, hunger: 30, happiness: 80, stamina: 60);
      expect(n.lines, contains('행복이 가득해서 공격이 잘 먹혔어.'));
    });

    test('금지 표현 — "약하", "졌" 미포함', () {
      final n = _narrate(
          isVictory: false, hunger: 10, happiness: 10, stamina: 10);
      final all = '${n.headline} ${n.lines.join(' ')}';
      expect(all.contains('약하'), false);
      expect(all.contains('졌'), false);
    });
  });

  group('공통 규칙', () {
    test('해설은 최대 3줄', () {
      final n = _narrate(
        playerHpRemaining: 90,
        playerMaxHp: 100,
        todaySteps: 12000,
        happiness: 90,
        stamina: 90,
        hunger: 90,
        affinityAdvantage: true,
      );
      expect(n.lines.length, lessThanOrEqualTo(3));
    });

    test('maxHp가 0이어도 예외 없이 동작', () {
      final n = _narrate(playerHpRemaining: 0, playerMaxHp: 0);
      expect(n.lines, isNotEmpty);
    });
  });
}
