import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 상태바 위젯
/// Pet의 상태(포만감, 수면, 운동)를 시각적으로 표시
/// design 폴더의 StatusBar 컴포넌트를 Flutter로 구현
/// 
/// 사용 예시:
/// ```dart
/// StatusBar(
///   label: '포만감',
///   value: 75,
///   color: StatusBarColor.hunger,
///   icon: Icons.restaurant,
/// )
/// ```
enum StatusBarColor {
  hunger, // 포만감
  stamina, // 수면
  happiness, // 운동
}

class StatusBar extends StatefulWidget {
  /// 상태바 라벨 (예: "포만감", "수면", "운동")
  final String label;
  
  /// 상태 값 (0~100)
  final int value;
  
  /// 상태바 색상 타입
  final StatusBarColor color;
  
  /// 아이콘 (선택사항)
  final IconData? icon;
  
  const StatusBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });
  
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _widthAnimation = Tween<double>(
      begin: 0,
      end: widget.value / 100,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }
  
  @override
  void didUpdateWidget(StatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _widthAnimation = Tween<double>(
        begin: oldWidget.value / 100,
        end: widget.value / 100,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.reset();
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Color _getBackgroundColor() {
    switch (widget.color) {
      case StatusBarColor.hunger:
        return AppColors.hunger.withValues(alpha: 0.2);
      case StatusBarColor.happiness:
        return AppColors.happiness.withValues(alpha: 0.2);
      case StatusBarColor.stamina:
        return AppColors.stamina.withValues(alpha: 0.2);
    }
  }
  
  Gradient _getGradient() {
    switch (widget.color) {
      case StatusBarColor.hunger:
        return AppColors.hungerGradient;
      case StatusBarColor.happiness:
        return AppColors.happinessGradient;
      case StatusBarColor.stamina:
        return AppColors.staminaGradient;
    }
  }
  
  Color _getGlowColor() {
    switch (widget.color) {
      case StatusBarColor.hunger:
        return AppColors.hunger.withValues(alpha: 0.4);
      case StatusBarColor.happiness:
        return AppColors.happiness.withValues(alpha: 0.4);
      case StatusBarColor.stamina:
        return AppColors.stamina.withValues(alpha: 0.4);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨과 값 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.value}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 진행바
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedBuilder(
            animation: _widthAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: _widthAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _getGradient(),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: _getGlowColor(),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
