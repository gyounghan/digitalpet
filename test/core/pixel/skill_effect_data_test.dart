import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/core/pixel/skill_effect_data.dart';

/// 스킬 이펙트 도트 데이터 무결성 테스트.
///
/// 수작업 아트라 실수하기 쉬운 지점을 고정한다:
///  1. 모든 이펙트는 20×20 그리드 3프레임
///  2. 3레이어(dark/body/accent) 비겹침
///  3. 프레임 간 차이가 있어야 함 (애니메이션 성립)
///  4. 전 스킬 이름이 이펙트에 매핑됨
void main() {
  group('skillEffectSprites', () {
    test('모든 이펙트 — 3프레임, 20×20, 행 수 일치', () {
      expect(skillEffectSprites, isNotEmpty);
      for (final entry in skillEffectSprites.entries) {
        expect(entry.value.length, 3, reason: '${entry.key} 프레임 수');
        for (final frame in entry.value) {
          expect(frame.size, skillEffectGridSize,
              reason: '${entry.key} 그리드 크기');
          expect(frame.dark.length, frame.size);
          expect(frame.body.length, frame.size);
          expect(frame.accent.length, frame.size);
        }
      }
    });

    test('레이어 비겹침 — 같은 칸에 두 색 없음', () {
      for (final entry in skillEffectSprites.entries) {
        for (int f = 0; f < entry.value.length; f++) {
          final frame = entry.value[f];
          for (int y = 0; y < frame.size; y++) {
            expect(frame.dark[y] & frame.body[y], 0,
                reason: '${entry.key}[$f] y=$y dark∩body');
            expect(frame.dark[y] & frame.accent[y], 0,
                reason: '${entry.key}[$f] y=$y dark∩accent');
            expect(frame.body[y] & frame.accent[y], 0,
                reason: '${entry.key}[$f] y=$y body∩accent');
          }
        }
      }
    });

    test('프레임에 도트가 존재하고 프레임 간 차이가 있다', () {
      for (final entry in skillEffectSprites.entries) {
        String sig(int f) {
          final fr = entry.value[f];
          return '${fr.dark}|${fr.body}|${fr.accent}';
        }

        for (int f = 0; f < entry.value.length; f++) {
          final fr = entry.value[f];
          final dots = List.generate(
                  fr.size, (y) => fr.dark[y] | fr.body[y] | fr.accent[y])
              .where((r) => r != 0);
          expect(dots, isNotEmpty, reason: '${entry.key}[$f] 빈 프레임');
        }
        expect(sig(0) != sig(1) || sig(1) != sig(2), isTrue,
            reason: '${entry.key} 모든 프레임 동일');
      }
    });
  });

  group('스킬 이름 매핑', () {
    test('전 스킬(9종)이 이펙트로 매핑된다', () {
      const allSkills = [
        '쪼기', '급강하', // 주작
        '물기', '조이기', // 청룡
        '할퀴기', '포효', // 백호
        '박치기', '방어자세', // 현무
        '공격', // 기본
      ];
      for (final name in allSkills) {
        expect(skillEffectForSkillName(name), isNotNull, reason: name);
      }
    });

    test('미등록 스킬은 null', () {
      expect(skillEffectForSkillName('없는스킬'), isNull);
    });

    test('자기 대상(버프) 이펙트 — 4종', () {
      for (final s in ['방어자세', '보름달', '여의주', '버티기']) {
        expect(isSelfSkillEffect(s), isTrue, reason: s);
      }
      for (final s in ['쪼기', '포효', '물대포', '회오리']) {
        expect(isSelfSkillEffect(s), isFalse, reason: s);
      }
    });

    test('추가 이펙트 7종이 등록돼 있다', () {
      for (final key in ['bite', 'slam', 'fire', 'water', 'gust', 'moon', 'charm']) {
        expect(skillEffectSprites[key], isNotNull, reason: key);
      }
    });

    test('동물 영물(2차) 스킬이 이펙트로 매핑된다', () {
      const animalSkills = {
        '내려치기': 'slam', '버티기': 'guard', // 곰
        '물장구': 'water', '물대포': 'water', // 수달
        '발톱치기': 'slash', '밤바람': 'gust', // 부엉이
        '부리쪼기': 'strike', '회오리': 'gust', // 두루미
      };
      animalSkills.forEach((name, effect) {
        expect(skillNameToEffect[name], effect, reason: name);
        expect(skillEffectForSkillName(name), isNotNull, reason: name);
      });
    });

    test('돌려쓰기 축소 — strike 공유 스킬이 3개 이하', () {
      final strikeCount =
          skillNameToEffect.values.where((e) => e == 'strike').length;
      expect(strikeCount, lessThanOrEqualTo(3),
          reason: '기존 8개에서 대폭 축소');
    });
  });
}
