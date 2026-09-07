import 'package:flutter/material.dart';

/// 앱 색상 정의
/// design 폴더의 theme.css를 기반으로 한 Flutter 색상 팔레트
class AppColors {
  AppColors._();

  // 배경색 (하늘빛 + 크림)
  static const Color backgroundDark = Color(0xFFEAF8FF);
  static const Color backgroundDarkSecondary = Color(0xFFFFFEFD);
  static const Color backgroundDarkTertiary = Color(0xFFFFF0E9);

  // Primary 색상
  static const Color primary = Color(0xFF4BA3FF);
  static const Color primaryDark = Color(0xFF2869B1);
  static const Color primaryGlow = Color(0x4D4BA3FF);

  // Accent 색상
  static const Color accentPink = Color(0xFFFF6F61);
  static const Color accentCyan = Color(0xFFBFF4FF);

  // 상태 색상 (이미지 참고)
  static const Color hunger = Color(0xFFFF6F61);
  static const Color hungerDark = Color(0xFFD85449);
  static const Color happiness = Color(0xFFFFC84D);
  static const Color happinessDark = Color(0xFFEFA72F);
  static const Color stamina = Color(0xFF2FBF71);
  static const Color staminaDark = Color(0xFF1D9F59);

  // 기타 색상
  static const Color warning = Color(0xFFFFA24D);
  static const Color danger = Color(0xFFFF6F61);
  static const Color success = Color(0xFF2FBF71);

  // 카드/글래스모피즘 색상 (밝은 배경에 맞게 조정)
  static const Color glassBackground = Color(0xFFFFFEF8);
  static const Color glassBorder = Color(0x52FFAE63);
  static const Color glassBackgroundLight = Color(0xFFECF8FF);
  static const Color glassBorderLight = Color(0x334BA3FF);

  // 텍스트 색상 (밝은 배경에 맞게 조정)
  static const Color textPrimary = Color(0xFF26324A);
  static const Color textSecondary = Color(0xFF536076);
  static const Color textTertiary = Color(0xFF7B8598);

  // 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundDarkSecondary, backgroundDarkTertiary],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1A4BA3FF), Colors.transparent, Color(0x1AFFC84D)],
  );

  static const LinearGradient hungerGradient = LinearGradient(
    colors: [hunger, hungerDark],
  );

  static const LinearGradient happinessGradient = LinearGradient(
    colors: [happiness, happinessDark],
  );

  static const LinearGradient staminaGradient = LinearGradient(
    colors: [stamina, staminaDark],
  );
}
