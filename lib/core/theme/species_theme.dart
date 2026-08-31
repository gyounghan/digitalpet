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
    primary: Color(0xFF4A5A78),
    primaryDeep: Color(0xFF2F3B54),
    primarySoft: Color(0xFFDDE4EF),
    surfaceDeep: Color(0xFFE6ECF5),
    accent: Color(0xFF7B8CA8),
    glow: Color(0xFFB8C4D8),
    gradStart: Color(0xFFF5F8FC),
    gradEnd: Color(0xFFDBE3F0),
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

  /// 달토끼 (moonrabbit) - 연보라 (달빛)
  static const SpeciesTheme moonrabbit = SpeciesTheme(
    primary: Color(0xFF9B8AC9),
    primaryDeep: Color(0xFF5F4E96),
    primarySoft: Color(0xFFEDE8F8),
    surfaceDeep: Color(0xFFE9E3F6),
    accent: Color(0xFFB9A8E4),
    glow: Color(0xFFD3C7EF),
    gradStart: Color(0xFFFAF8FE),
    gradEnd: Color(0xFFE2D9F5),
    spriteAccent: Color(0xFFF8F6FF),
  );

  /// 해태 (haetae) - 청록+금 갈기 (돌 수호수)
  static const SpeciesTheme haetae = SpeciesTheme(
    primary: Color(0xFF2E9B8F),
    primaryDeep: Color(0xFF176B62),
    primarySoft: Color(0xFFCDEEE9),
    surfaceDeep: Color(0xFFC9ECE6),
    accent: Color(0xFF54C2B4),
    glow: Color(0xFF8FDDD1),
    gradStart: Color(0xFFF0FBF9),
    gradEnd: Color(0xFFC5EBE4),
    spriteAccent: Color(0xFFE8C86A),
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
      null => const [
          (Color(0xFF4A5A78), Color(0xFFDDE3EC)),
        ],
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
      null => '털뭉치',
    };
  }
}

/// 디자인 시스템 공통 컬러 (프로토타입의 ink/line/surface 토큰)
class DesignTokens {
  DesignTokens._();

  static const Color ink = Color(0xFF1A1A1F);
  static const Color ink2 = Color(0xFF4A4A55);
  static const Color ink3 = Color(0xFF8A8A95);
  static const Color line = Color(0x141414CC); // rgba(20,20,30,0.08)
  static const Color line2 = Color(0x241414CC); // rgba(20,20,30,0.14)
  static const Color bg = Color(0xFFF7F4EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF4F1EC);
  static const Color good = Color(0xFF2E9B6B);
  static const Color warn = Color(0xFFE2843A);
  static const Color bad = Color(0xFFD9484F);

  /// 목표 달성·보상 축하 강조색 (라이트 카드 위 금색)
  static const Color gold = Color(0xFFD99A0B);
}
