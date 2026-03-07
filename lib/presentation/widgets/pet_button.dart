import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Pet 액션 버튼 위젯
/// design 폴더의 PetButton 컴포넌트를 Flutter로 구현
/// 
/// 사용 예시:
/// ```dart
/// PetButton(
///   variant: PetButtonVariant.primary,
///   icon: Icons.restaurant,
///   onPressed: () {},
///   child: Text('Feed'),
/// )
/// ```
enum PetButtonVariant {
  primary,
  secondary,
}

class PetButton extends StatefulWidget {
  /// 버튼 변형 (primary 또는 secondary)
  final PetButtonVariant variant;
  
  /// 아이콘
  final IconData? icon;
  
  /// 버튼 텍스트
  final Widget child;
  
  /// 클릭 핸들러
  final VoidCallback? onPressed;
  
  /// 비활성화 여부
  final bool disabled;
  
  const PetButton({
    super.key,
    this.variant = PetButtonVariant.primary,
    this.icon,
    required this.child,
    this.onPressed,
    this.disabled = false,
  });
  
  @override
  State<PetButton> createState() => _PetButtonState();
}

class _PetButtonState extends State<PetButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    if (!widget.disabled) {
      _controller.forward();
    }
  }
  
  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (!widget.disabled && widget.onPressed != null) {
      widget.onPressed!();
    }
  }
  
  void _handleTapCancel() {
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == PetButtonVariant.primary;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primary : AppColors.glassBackground, // 활성: 보라색, 비활성: 흰색
            borderRadius: BorderRadius.circular(24),
            border: isPrimary
                ? null
                : Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), // 보라색 테두리
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: isPrimary ? Colors.white : AppColors.primary, // 활성: 흰색, 비활성: 보라색
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppColors.primary, // 활성: 흰색, 비활성: 보라색
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
