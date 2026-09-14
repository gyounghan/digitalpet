import 'package:flutter/services.dart';

/// 촉각(햅틱) 피드백 서비스 — 주요 상호작용에 진동 반응을 준다.
///
/// Flutter 내장 [HapticFeedback]만 사용하므로 추가 패키지가 필요 없다.
/// 사운드(효과음)는 오디오 에셋이 준비되면 이 서비스에 확장한다.
/// [enabled] 플래그로 설정에서 끌 수 있다(기본 켜짐, 앱 시작 시 설정값 주입).
class FeedbackService {
  FeedbackService._();

  /// 햅틱 사용 여부 — 앱 시작 시 저장된 설정으로 덮어쓴다.
  static bool enabled = true;

  /// 가벼운 탭 (버튼·펫 톡 건드리기)
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// 중간 세기 (밥/물 주기 등 액션)
  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// 선택/토글
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// 성공/보상 (구매·목표 달성·승리) — 묵직한 두 번
  static void success() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// 실패/거부 (코인 부족 등)
  static void error() {
    if (enabled) HapticFeedback.vibrate();
  }
}
