import 'package:flutter/material.dart';
import '../../domain/entities/evolution_type.dart';

/// 종별 컬러 테마 (사신수 매핑)
/// 프로토타입의 data-theme CSS 변수를 Flutter 객체로 변환
///
/// 매핑:
/// - tiger (백호) → blue-gray
/// - bird (주작) → red-orange (phoenix)
/// - turtle (현무) → green
/// - snake (청룡) → blue (dragon)
class SpeciesTheme {
  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color surfaceDeep;
  final Color accent;
  final Color glow;
  final Color gradStart;
  final Color gradEnd;

  /// 도트 스프라이트 보조색 — 원본 캐릭터의 2번째 색
  /// (청룡 크림 배, 백호 설백 몸, 주작 노란 부리/가슴, 현무 갈색 등딱지)
  final Color spriteAccent;

  const SpeciesTheme({
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.surfaceDeep,
    required this.accent,
    required this.glow,
    required this.gradStart,
    required this.gradEnd,
    this.spriteAccent = const Color(0xFFDDE3EC),
  });

  /// 기본 (진화 미결정)
  static const SpeciesTheme defaultTheme = SpeciesTheme(
    primary: Color(0xFF7F9F72),
    primaryDeep: Color(0xFF536F4A),
    primarySoft: Color(0xFFE8F1D8),
    surfaceDeep: Color(0xFFF1E5CF),
    accent: Color(0xFFF2B84B),
    glow: Color(0xFFD7E6B8),
    gradStart: Color(0xFFFFFAF1),
    gradEnd: Color(0xFFEAF3D8),
  );

  /// 백호 (tiger) - blue-gray
  static const SpeciesTheme tiger = SpeciesTheme(
    primary: Color(0xFF4A5A78),
    primaryDeep: Color(0xFF2F3B54),
    primarySoft: Color(0xFFDDE4EF),
    surfaceDeep: Color(0xFFE6ECF5),
    accent: Color(0xFF7B8CA8),
    glow: Color(0xFFB8C4D8),
    gradStart: Color(0xFFF5F8FC),
    gradEnd: Color(0xFFDBE3F0),
    spriteAccent: Color(0xFFF0F3F8),
  );

  /// 주작 (bird/phoenix) - red-orange
  static const SpeciesTheme bird = SpeciesTheme(
    primary: Color(0xFFDC4828),
    primaryDeep: Color(0xFFA52F1A),
    primarySoft: Color(0xFFFFD9C8),
    surfaceDeep: Color(0xFFFFD7C2),
    accent: Color(0xFFFF8A4A),
    glow: Color(0xFFFFB074),
    gradStart: Color(0xFFFFF6EF),
    gradEnd: Color(0xFFFFD0A8),
    spriteAccent: Color(0xFFFFC94D),
  );

  /// 현무 (turtle) - 연두 (yellow-green, 파스텔 라임)
  static const SpeciesTheme turtle = SpeciesTheme(
    primary: Color(0xFF9CCC65),
    primaryDeep: Color(0xFF0E8E68),
    primarySoft: Color(0xFFC4F1E2),
    surfaceDeep: Color(0xFFCEF3E5),
    accent: Color(0xFF45D6AC),
    glow: Color(0xFF8FE9CE),
    gradStart: Color(0xFFEFFDF8),
    gradEnd: Color(0xFFC6F3E4),
    spriteAccent: Color(0xFF9C7A4C),
  );

  /// 청룡 (snake/dragon) - blue
  static const SpeciesTheme snake = SpeciesTheme(
    primary: Color(0xFF2B7AD6),
    primaryDeep: Color(0xFF0F4E9B),
    primarySoft: Color(0xFFCFE1F7),
    surfaceDeep: Color(0xFFCBE0F5),
    accent: Color(0xFF56A3EC),
    glow: Color(0xFFA7C8EC),
    gradStart: Color(0xFFEEF5FD),
    gradEnd: Color(0xFFC8DEFA),
    spriteAccent: Color(0xFFF2E3C2),
  );

  /// 삼족오 (samjoko) - 흑+금 (태양의 까마귀)
  static const SpeciesTheme samjoko = SpeciesTheme(
    primary: Color(0xFF3F3F49),
    primaryDeep: Color(0xFF26262D),
    primarySoft: Color(0xFFE8E3D2),
    surfaceDeep: Color(0xFFE9E4D4),
    accent: Color(0xFFE0B44A),
    glow: Color(0xFFEFCB6F),
    gradStart: Color(0xFFFBF7EC),
    gradEnd: Color(0xFFEADFB9),
    spriteAccent: Color(0xFFF2C24E),
  );

  /// 구미호 (gumiho) - 주황 여우
  static const SpeciesTheme gumiho = SpeciesTheme(
    primary: Color(0xFFE07A3F),
    primaryDeep: Color(0xFFAD5220),
    primarySoft: Color(0xFFFFE3CE),
    surfaceDeep: Color(0xFFFFE0C8),
    accent: Color(0xFFFF9E66),
    glow: Color(0xFFFFC08A),
    gradStart: Color(0xFFFFF8F1),
    gradEnd: Color(0xFFFFDDBE),
    spriteAccent: Color(0xFFFFF0DC),
  );

  /// 달토끼 (moonrabbit) - 흰 몸 + 보라 문양 (달빛). 레퍼런스에 맞춰 몸통을
  /// 밝게(연보라-화이트) 잡고 보라는 보조색으로.
  static const SpeciesTheme moonrabbit = SpeciesTheme(
    primary: Color(0xFFB8ACD8),
    primaryDeep: Color(0xFF6A5AA0),
    primarySoft: Color(0xFFEDE8F8),
    surfaceDeep: Color(0xFFE9E3F6),
    accent: Color(0xFFC8BCE8),
    glow: Color(0xFFD9CFEF),
    gradStart: Color(0xFFFBFAFE),
    gradEnd: Color(0xFFE6DEF5),
    spriteAccent: Color(0xFFF6F3FF),
  );

  /// 해태 (haetae) - 청회색 몸 + 붉은 불꽃 갈기 (돌 수호수).
  /// 레퍼런스 실측: 몸통=청회색('o'), 갈기·꼬리 불꽃=붉은색('+').
  static const SpeciesTheme haetae = SpeciesTheme(
    primary: Color(0xFF5E7A88),
    primaryDeep: Color(0xFF3A5462),
    primarySoft: Color(0xFFD7E3E8),
    surfaceDeep: Color(0xFFD2E0E6),
    accent: Color(0xFFE0654A),
    glow: Color(0xFF9CB4BE),
    gradStart: Color(0xFFF4F8FA),
    gradEnd: Color(0xFFD2E2E8),
    spriteAccent: Color(0xFFD9503A),
  );

  /// 도깨비 (dokkaebi) - 붉은 피부 + 짙은 머리 (장난꾸러기 싸움꾼).
  /// 레퍼런스 실측: 어두운 머리·아웃라인이 최대 군집('o'→짙은 갈색),
  /// 붉은 피부는 보조색('+'). UI도 오니답게 다크레드 톤.
  static const SpeciesTheme dokkaebi = SpeciesTheme(
    primary: Color(0xFF4A3230),
    primaryDeep: Color(0xFF2E201F),
    primarySoft: Color(0xFFF0DAD4),
    surfaceDeep: Color(0xFFEDD6D0),
    accent: Color(0xFFE05A48),
    glow: Color(0xFFB08078),
    gradStart: Color(0xFFFBF4F2),
    gradEnd: Color(0xFFF0D8D2),
    spriteAccent: Color(0xFFD14B3A),
  );

  /// 황룡 (hwangryong) - 금 (오방의 중앙)
  static const SpeciesTheme hwangryong = SpeciesTheme(
    primary: Color(0xFFD4A017),
    primaryDeep: Color(0xFF9C7208),
    primarySoft: Color(0xFFF7ECC8),
    surfaceDeep: Color(0xFFF4E8C2),
    accent: Color(0xFFE8C24A),
    glow: Color(0xFFF0D77E),
    gradStart: Color(0xFFFEFBF2),
    gradEnd: Color(0xFFF2E3B4),
    spriteAccent: Color(0xFFFFE9A8),
  );

  /// 곰 (bear/웅녀) - 갈색 (인내·디톡스)
  static const SpeciesTheme bear = SpeciesTheme(
    primary: Color(0xFF8B5E3C),
    primaryDeep: Color(0xFF5E3D26),
    primarySoft: Color(0xFFEBDCC9),
    surfaceDeep: Color(0xFFE8DBC8),
    accent: Color(0xFFC08A55),
    glow: Color(0xFFD3AA7E),
    gradStart: Color(0xFFFBF6EF),
    gradEnd: Color(0xFFE9D8C2),
    spriteAccent: Color(0xFFE8D2B0),
  );

  /// 수달 (otter) - 갈색 몸 + 물 청록 (건강·물)
  static const SpeciesTheme otter = SpeciesTheme(
    primary: Color(0xFF7C6551),
    primaryDeep: Color(0xFF50412F),
    primarySoft: Color(0xFFE6DCCB),
    surfaceDeep: Color(0xFFDDE8E6),
    accent: Color(0xFF6FB4B0),
    glow: Color(0xFFA9CFCB),
    gradStart: Color(0xFFF4F9F8),
    gradEnd: Color(0xFFD8E6E2),
    spriteAccent: Color(0xFFE6D8C0),
  );

  /// 부엉이 (owl/수리부엉이) - 야행 보라 + 금눈 (지혜·집중)
  static const SpeciesTheme owl = SpeciesTheme(
    primary: Color(0xFF5A4B6E),
    primaryDeep: Color(0xFF362B47),
    primarySoft: Color(0xFFE3DCEC),
    surfaceDeep: Color(0xFFDED7EA),
    accent: Color(0xFFC9A24A),
    glow: Color(0xFFB59BE0),
    gradStart: Color(0xFFF7F5FB),
    gradEnd: Color(0xFFDED4EE),
    spriteAccent: Color(0xFFE8D9A8),
  );

  /// 두루미 (crane/학) - 백색 몸 + 붉은 볏 (십장생·정갈)
  static const SpeciesTheme crane = SpeciesTheme(
    primary: Color(0xFFC9D2DC),
    primaryDeep: Color(0xFF8A96A4),
    primarySoft: Color(0xFFEFF2F6),
    surfaceDeep: Color(0xFFEAEFF4),
    accent: Color(0xFFD6432E),
    glow: Color(0xFFE9B0A6),
    gradStart: Color(0xFFFAFBFD),
    gradEnd: Color(0xFFE4EAF0),
    spriteAccent: Color(0xFFD6432E),
  );

  /// 도트 스프라이트 아웃라인/눈 색 (전 종 공통)
  ///
  /// 근흑색 — 백호(청회색 몸)·흑 계열 변이처럼 어두운 몸통에서도 눈이
  /// 또렷해야 해서 기존 0xFF33383F보다 어둡게 잡았다.
  /// ⚠️ 위젯 네이티브(WidgetPixelRenderer.kt DARK_COLOR)와 동일하게 유지할 것.
  static const Color dotDark = Color(0xFF14161A);

  /// 털뭉치(stage 1) 도트 몸통색 — 연한 크림 베이지 (종 미결정 상태)
  static const Color fluffBody = Color(0xFFF4E9CE);

  /// 털뭉치(stage 1) 보조색 — 볼터치·귀 안쪽 연분홍 (귀여움 강조)
  static const Color fluffAccent = Color(0xFFF2A0AE);

  /// 일반종(normal 성장기·성숙기) 도트 색 — (몸통, 보조색).
  ///
  /// 사신수 대신 '그냥 동물'로 렌더하며, 개체의 육성 스타일(지표 우세 축)에서
  /// 파생한 [variant](0~3)로 종마다 4가지 자연색을 부여해 다양성을 준다.
  /// (0 활동형 · 1 휴식형 · 2 미식형 · 3 전투형)
  static (Color, Color) naturalDotColors(EvolutionType? type, int variant) {
    final v = variant.clamp(0, 3);
    final palettes = switch (type) {
      EvolutionType.bird => const [
        (Color(0xFF9A7B4E), Color(0xFFD8C39A)), // 갈색 수리
        (Color(0xFF8B93A0), Color(0xFFCED4DC)), // 회색 새
        (Color(0xFFCBBB98), Color(0xFFEDE4CF)), // 흰/베이지 새
        (Color(0xFF6E6862), Color(0xFF9A948C)), // 검은 새 (눈 대비 위해 소폭 밝게)
      ],
      EvolutionType.snake => const [
        (Color(0xFF5E9B49), Color(0xFFE7DFBF)), // 초록 뱀
        (Color(0xFF3E8E8A), Color(0xFFCFE3DF)), // 청록 뱀
        (Color(0xFFB79A52), Color(0xFFE9DEB8)), // 황갈 뱀
        (Color(0xFFA85A44), Color(0xFFE2C4B0)), // 적갈 뱀
      ],
      EvolutionType.tiger => const [
        (Color(0xFFE0913F), Color(0xFFF3E4C8)), // 주황 호랑이
        (Color(0xFFB9BEC6), Color(0xFFEDEFF3)), // 회백 호랑이
        (Color(0xFFCBA13E), Color(0xFFF0E4BE)), // 황금 호랑이
        (Color(0xFF6E6760), Color(0xFF9A9288)), // 흑 호랑이 (눈 대비 위해 소폭 밝게)
      ],
      EvolutionType.turtle => const [
        (Color(0xFF6E8F52), Color(0xFF9C7A4C)), // 올리브 거북
        (Color(0xFF4C8A72), Color(0xFF8C7048)), // 청록 거북
        (Color(0xFF9A8748), Color(0xFFB08C50)), // 황갈 거북
        (Color(0xFF4A6B3E), Color(0xFF7A5E3C)), // 짙은초록 거북
      ],
      EvolutionType.samjoko => const [
        (Color(0xFF4B4B54), Color(0xFF8E8E96)), // 회흑 까마귀
        (Color(0xFF6E5A46), Color(0xFFA88C6A)), // 갈색 까마귀
        (Color(0xFF5A6474), Color(0xFF9AA6B8)), // 청회 까마귀
        (Color(0xFF3E3E46), Color(0xFF787880)), // 짙은 흑 까마귀
      ],
      EvolutionType.gumiho => const [
        (Color(0xFFD9853E), Color(0xFFF6E3C8)), // 주황 여우
        (Color(0xFF8E93A2), Color(0xFFE2E6EE)), // 은여우
        (Color(0xFFD9CDB8), Color(0xFFF4EFE2)), // 백여우
        (Color(0xFF57504A), Color(0xFF8B837B)), // 흑여우
      ],
      EvolutionType.moonrabbit => const [
        (Color(0xFFD9D4CC), Color(0xFFF5F2EC)), // 흰 토끼
        (Color(0xFF9BA0A8), Color(0xFFD6DAE0)), // 회 토끼
        (Color(0xFFA98D66), Color(0xFFE0CDAA)), // 갈색 토끼
        (Color(0xFF57534E), Color(0xFF8D8983)), // 검은 토끼
      ],
      EvolutionType.haetae => const [
        (Color(0xFF8E9299), Color(0xFFC8CCD2)), // 돌회 해치
        (Color(0xFF7E8A62), Color(0xFFB7C29A)), // 청동 해치
        (Color(0xFFBCA878), Color(0xFFE6DCC0)), // 모래 해치
        (Color(0xFF4E5258), Color(0xFF83888E)), // 흑요 해치
      ],
      EvolutionType.dokkaebi => const [
        (Color(0xFFC05548), Color(0xFFEFC0B8)), // 홍 도깨비
        (Color(0xFF4E6FA8), Color(0xFFBFD0E8)), // 청 도깨비
        (Color(0xFF5E8A5A), Color(0xFFC2DCC0)), // 녹 도깨비
        (Color(0xFFC9A94E), Color(0xFFEEDFB0)), // 황 도깨비
      ],
      EvolutionType.hwangryong => const [
        (Color(0xFFC9A227), Color(0xFFF0E1B0)), // 금 구렁이
        (Color(0xFFD9D2C0), Color(0xFFF4F0E4)), // 백금 구렁이
        (Color(0xFFC08040), Color(0xFFEDD5B5)), // 적금 구렁이
        (Color(0xFF8A8A5A), Color(0xFFD5D5AC)), // 청금 구렁이
      ],
      EvolutionType.bear => const [
        (Color(0xFF8B5E3C), Color(0xFFE8D2B0)), // 갈색 곰
        (Color(0xFF6E5A50), Color(0xFFCFC3B4)), // 회갈 곰
        (Color(0xFFB08A5A), Color(0xFFE9D9BE)), // 밝은갈 곰
        (Color(0xFF4E3B2C), Color(0xFF8A7358)), // 흑갈 곰
      ],
      EvolutionType.otter => const [
        (Color(0xFF7C6551), Color(0xFFE6D8C0)), // 갈색 수달
        (Color(0xFF5E7A76), Color(0xFFCADFDB)), // 청록 수달
        (Color(0xFFAA8E6E), Color(0xFFE7D8C0)), // 모래 수달
        (Color(0xFF4A4038), Color(0xFF867A6E)), // 짙은갈 수달
      ],
      EvolutionType.owl => const [
        (Color(0xFF5A4B6E), Color(0xFFE8D9A8)), // 보라 부엉이
        (Color(0xFF6E5A46), Color(0xFFDDCBA8)), // 갈색 부엉이
        (Color(0xFF8A8290), Color(0xFFDCD6E0)), // 회 부엉이
        (Color(0xFF3E3448), Color(0xFF7A6E88)), // 흑보라 부엉이
      ],
      EvolutionType.crane => const [
        (Color(0xFFC9D2DC), Color(0xFFD6432E)), // 백색 두루미(붉은볏)
        (Color(0xFFB6BEC8), Color(0xFFE0844A)), // 회백 두루미
        (Color(0xFFD9CDB8), Color(0xFFD6432E)), // 재두루미
        (Color(0xFF8A929C), Color(0xFFB03A2A)), // 청회 두루미
      ],
      null => const [(Color(0xFF4A5A78), Color(0xFFDDE3EC))],
    };
    return palettes[v % palettes.length];
  }

  /// 진화 타입으로 테마 조회
  static SpeciesTheme forType(EvolutionType? type) {
    return switch (type) {
      EvolutionType.tiger => tiger,
      EvolutionType.bird => bird,
      EvolutionType.turtle => turtle,
      EvolutionType.snake => snake,
      EvolutionType.samjoko => samjoko,
      EvolutionType.gumiho => gumiho,
      EvolutionType.moonrabbit => moonrabbit,
      EvolutionType.haetae => haetae,
      EvolutionType.dokkaebi => dokkaebi,
      EvolutionType.hwangryong => hwangryong,
      EvolutionType.bear => bear,
      EvolutionType.otter => otter,
      EvolutionType.owl => owl,
      EvolutionType.crane => crane,
      null => defaultTheme,
    };
  }

  /// 종 이름 (한국어) — 종 미결정(털뭉치 단계)은 '털뭉치'
  static String labelFor(EvolutionType? type) {
    return switch (type) {
      EvolutionType.tiger => '백호',
      EvolutionType.bird => '주작',
      EvolutionType.turtle => '현무',
      EvolutionType.snake => '청룡',
      EvolutionType.samjoko => '삼족오',
      EvolutionType.gumiho => '구미호',
      EvolutionType.moonrabbit => '달토끼',
      EvolutionType.haetae => '해태',
      EvolutionType.dokkaebi => '도깨비',
      EvolutionType.hwangryong => '황룡',
      EvolutionType.bear => '곰',
      EvolutionType.otter => '수달',
      EvolutionType.owl => '부엉이',
      EvolutionType.crane => '두루미',
      null => '털뭉치',
    };
  }
}

/// 디자인 시스템 공통 컬러 (프로토타입의 ink/line/surface 토큰)
class DesignTokens {
  DesignTokens._();

  static const Color ink = Color(0xFF29261F);
  static const Color ink2 = Color(0xFF5B5245);
  static const Color ink3 = Color(0xFF8E8374);
  static const Color line = Color(0xFFE7D8BD);
  static const Color line2 = Color(0xFFD8C6A6);
  static const Color bg = Color(0xFFF7EFE2);
  static const Color surface = Color(0xFFFFFDF7);
  static const Color surfaceSoft = Color(0xFFF8F1E5);
  static const Color good = Color(0xFF6F9764);
  static const Color warn = Color(0xFFE0A33C);
  static const Color bad = Color(0xFFD85D4E);
  static const Color sky = Color(0xFFA9D5E7);
  static const Color paper = Color(0xFFFFFAF1);

  /// 목표 달성·보상 축하 강조색 (라이트 카드 위 금색)
  static const Color gold = Color(0xFFF2B84B);
}
