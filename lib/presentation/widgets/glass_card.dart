import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 글래스모피즘 카드 위젯
/// design 폴더의 GlassCard 컴포넌트를 Flutter로 구현
/// 
/// 사용 예시:
/// ```dart
/// GlassCard(
///   gradient: true,
///   child: Text('Content'),
/// )
/// ```
class GlassCard extends StatelessWidget {
  /// 카드 내용
  final Widget child;
  
  /// 그라디언트 효과 적용 여부
  final bool gradient;
  
  /// 추가 패딩
  final EdgeInsetsGeometry? padding;
  
  /// 추가 마진
  final EdgeInsetsGeometry? margin;
  
  const GlassCard({
    super.key,
    required this.child,
    this.gradient = false,
    this.padding,
    this.margin,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), // 밝은 배경에 맞게 그림자 약하게
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 그라디언트 오버레이
            if (gradient)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.glassGradient,
                  ),
                ),
              ),
            // 내용
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
