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

  /// 현무 (turtle) - fresh jade/mint (더 연한 파스텔 제이드)
  static const SpeciesTheme turtle = SpeciesTheme(
    primary: Color(0xFF52CFA3),
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

  /// 털뭉치(stage 1) 도트 몸통색 — 밝은 베이지 (종 미결정 상태)
  static const Color fluffBody = Color(0xFFEAD7A8);

  /// 진화 타입으로 테마 조회
  static SpeciesTheme forType(EvolutionType? type) {
    return switch (type) {
      EvolutionType.tiger => tiger,
      EvolutionType.bird => bird,
      EvolutionType.turtle => turtle,
      EvolutionType.snake => snake,
      null => defaultTheme,
    };
  }

  /// 종 이름 (한국어)
  static String labelFor(EvolutionType? type) {
    return switch (type) {
      EvolutionType.tiger => '백호',
      EvolutionType.bird => '주작',
      EvolutionType.turtle => '현무',
      EvolutionType.snake => '청룡',
      null => '???',
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
}
