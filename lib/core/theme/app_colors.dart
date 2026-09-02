import 'package:flutter/material.dart';

/// 앱 색상 정의
/// design 폴더의 theme.css를 기반으로 한 Flutter 색상 팔레트
class AppColors {
  AppColors._();

  // 배경색 (따뜻한 종이색 + 연한 풀빛)
  static const Color backgroundDark = Color(0xFFFFFAF1);
  static const Color backgroundDarkSecondary = Color(0xFFF4EAD8);
  static const Color backgroundDarkTertiary = Color(0xFFEDF3E3);

  // Primary 색상 (차분한 잎색)
  static const Color primary = Color(0xFF7F9F72);
  static const Color primaryDark = Color(0xFF536F4A);
  static const Color primaryGlow = Color(0x4D7F9F72);

  // Accent 색상
  static const Color accentPink = Color(0xFFE97861);
  static const Color accentCyan = Color(0xFFA9D5E7);

  // 상태 색상 (이미지 참고)
  static const Color hunger = Color(0xFFF2786B); // 오렌지-레드 (#F2786B) - 이미지 참고
  static const Color hungerDark = Color(0xFFE85D4F);
  static const Color happiness = Color(
    0xFFF6C769,
  ); // 노란색-오렌지 (#F6C769) - 이미지 참고
  static const Color happinessDark = Color(0xFFF4B84A);
  static const Color stamina = Color(0xFF78C97B); // 그린 (#78C97B) - 이미지 참고
  static const Color staminaDark = Color(0xFF6AB86D);

  // 기타 색상
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFFF5252);
  static const Color success = Color(0xFF69F0AE);

  // 카드 색상
  static const Color glassBackground = Color(0xFFFFFDF7);
  static const Color glassBorder = Color(0xFFE7D8BD);
  static const Color glassBackgroundLight = Color(0xFFF8F1E5);
  static const Color glassBorderLight = Color(0xFFD8C6A6);

  // 텍스트 색상
  static const Color textPrimary = Color(0xFF29261F);
  static const Color textSecondary = Color(0xFF5B5245);
  static const Color textTertiary = Color(0xFF8E8374);

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
    colors: [Color(0x147F9F72), Colors.transparent, Color(0x18F2B84B)],
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
