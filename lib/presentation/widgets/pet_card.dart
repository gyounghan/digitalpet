import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Pet 카드 위젯
/// design 폴더의 PetCard 컴포넌트를 Flutter로 구현
/// 
/// 사용 예시:
/// ```dart
/// PetCard(
///   petName: 'Luna',
///   level: 12,
///   hp: 80,
///   maxHp: 100,
///   side: PetCardSide.left,
///   mood: PetMood.happy,
/// )
/// ```
enum PetCardSide {
  left,
  right,
}

enum PetMood {
  happy,
  sad,
  neutral,
}

class PetCard extends StatefulWidget {
  /// Pet 이름
  final String petName;
  
  /// 레벨
  final int level;
  
  /// 현재 HP (선택사항)
  final int? hp;
  
  /// 최대 HP (선택사항)
  final int? maxHp;
  
  /// Pet 이미지 (선택사항, 현재는 이모지 사용)
  final String? petImage;
  
  /// 카드 위치 (left 또는 right)
  final PetCardSide side;
  
  /// 기분 상태
  final PetMood mood;
  
  const PetCard({
    super.key,
    required this.petName,
    required this.level,
    this.hp,
    this.maxHp,
    this.petImage,
    this.side = PetCardSide.left,
    this.mood = PetMood.neutral,
  });
  
  @override
  State<PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<PetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    final offset = widget.side == PetCardSide.left
        ? const Offset(-1, 0)
        : const Offset(1, 0);
    
    _slideAnimation = Tween<Offset>(
      begin: offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  String _getMoodEmoji() {
    if (widget.petImage != null) {
      return widget.petImage!;
    }
    switch (widget.mood) {
      case PetMood.happy:
        return '😊';
      case PetMood.sad:
        return '😢';
      case PetMood.neutral:
        return '😐';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 그라디언트 오버레이
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.glassGradient,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
              // 내용
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pet 이미지/이모지
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getMoodEmoji(),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 이름과 레벨
                  Text(
                    widget.petName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lv. ${widget.level}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  // HP 바 (있는 경우)
                  if (widget.hp != null && widget.maxHp != null) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'HP',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Text(
                              '${widget.hp}/${widget.maxHp}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.glassBackground,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: widget.hp! / widget.maxHp!,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.accentPink, AppColors.hunger],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
