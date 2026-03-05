import 'package:flutter/material.dart';

/// 앱 색상 정의
/// design 폴더의 theme.css를 기반으로 한 Flutter 색상 팔레트
class AppColors {
  AppColors._();
  
  // 배경색
  static const Color backgroundDark = Color(0xFF0F0F1E);
  static const Color backgroundDarkSecondary = Color(0xFF1a1a2e);
  static const Color backgroundDarkTertiary = Color(0xFF16213e);
  
  // Primary 색상
  static const Color primary = Color(0xFF8B7FFF);
  static const Color primaryDark = Color(0xFF6B5FEF);
  static const Color primaryGlow = Color(0x4D8B7FFF); // rgba(139, 127, 255, 0.3)
  
  // Accent 색상
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentCyan = Color(0xFF5DFDCB);
  
  // 상태 색상
  static const Color hunger = Color(0xFFFF8A65);
  static const Color hungerDark = Color(0xFFFF6B4A);
  static const Color happiness = Color(0xFFFFD93D);
  static const Color happinessDark = Color(0xFFFFC107);
  static const Color stamina = Color(0xFF6BCF7F);
  static const Color staminaDark = Color(0xFF4CAF50);
  
  // 기타 색상
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFFF5252);
  static const Color success = Color(0xFF69F0AE);
  
  // 글래스모피즘 색상
  static const Color glassBackground = Color(0x0DFFFFFF); // rgba(255, 255, 255, 0.05)
  static const Color glassBorder = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)
  static const Color glassBackgroundLight = Color(0x08FFFFFF); // rgba(255, 255, 255, 0.03)
  static const Color glassBorderLight = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  
  // 텍스트 색상
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x99FFFFFF); // rgba(255, 255, 255, 0.6)
  static const Color textTertiary = Color(0x66FFFFFF); // rgba(255, 255, 255, 0.4)
  
  // 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDarkSecondary, backgroundDark, backgroundDarkTertiary],
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0D8B7FFF), // rgba(139, 127, 255, 0.05)
      Colors.transparent,
      Color(0x0DFF6B9D), // rgba(255, 107, 157, 0.05)
    ],
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
