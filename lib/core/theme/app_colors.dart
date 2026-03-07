import 'package:flutter/material.dart';

/// 앱 색상 정의
/// design 폴더의 theme.css를 기반으로 한 Flutter 색상 팔레트
class AppColors {
  AppColors._();
  
  // 배경색 (밝은 라벤더/핑크 그라디언트)
  static const Color backgroundDark = Color(0xFFF3E8F5); // 밝은 라벤더 핑크 (상단)
  static const Color backgroundDarkSecondary = Color(0xFFF8F0F8); // 더 밝은 핑크 (중간)
  static const Color backgroundDarkTertiary = Color(0xFFFFF5F8); // 거의 흰색 핑크 (하단)
  
  // Primary 색상 (중간 보라색)
  static const Color primary = Color(0xFFA08CDB); // 중간 보라색 (#A08CDB) - 이미지 참고
  static const Color primaryDark = Color(0xFF8B7BC8); // 진한 보라색
  static const Color primaryGlow = Color(0x4DA08CDB); // rgba(160, 140, 219, 0.3)
  
  // Accent 색상
  static const Color accentPink = Color(0xFFA08CDB); // 보라색 (Primary와 동일)
  static const Color accentCyan = Color(0xFFE0D6F5); // 밝은 라일락 (헤더 버튼 배경)
  
  // 상태 색상 (이미지 참고)
  static const Color hunger = Color(0xFFF2786B); // 오렌지-레드 (#F2786B) - 이미지 참고
  static const Color hungerDark = Color(0xFFE85D4F);
  static const Color happiness = Color(0xFFF6C769); // 노란색-오렌지 (#F6C769) - 이미지 참고
  static const Color happinessDark = Color(0xFFF4B84A);
  static const Color stamina = Color(0xFF78C97B); // 그린 (#78C97B) - 이미지 참고
  static const Color staminaDark = Color(0xFF6AB86D);
  
  // 기타 색상
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFFF5252);
  static const Color success = Color(0xFF69F0AE);
  
  // 카드/글래스모피즘 색상 (밝은 배경에 맞게 조정)
  static const Color glassBackground = Color(0xFFFFFFFF); // 흰색 (#FFFFFF) - 이미지 참고
  static const Color glassBorder = Color(0x1A000000); // rgba(0, 0, 0, 0.1) - 연한 검정 테두리
  static const Color glassBackgroundLight = Color(0xFFF8F8F8); // 매우 밝은 회색
  static const Color glassBorderLight = Color(0x14000000); // rgba(0, 0, 0, 0.08)
  
  // 텍스트 색상 (밝은 배경에 맞게 조정)
  static const Color textPrimary = Color(0xFF333333); // 어두운 회색 (#333333) - 이미지 참고
  static const Color textSecondary = Color(0xFF888888); // 중간 회색 (#888888) - 이미지 참고
  static const Color textTertiary = Color(0xFFA08CDB); // 보라색 (#A08CDB) - 레벨 텍스트 등
  
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
    colors: [
      Color(0x0DA08CDB), // rgba(160, 140, 219, 0.05) - 보라색
      Colors.transparent,
      Color(0x0DF6C769), // rgba(246, 199, 105, 0.05) - 노란색
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
