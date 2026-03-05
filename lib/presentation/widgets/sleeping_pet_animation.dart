import 'package:flutter/material.dart';

/// 잠자는 펫 애니메이션 위젯
/// 
/// 3장의 잠자는 이미지를 순환하여 애니메이션 효과를 만듦
/// 펫이 잠자는 상태일 때 표시됨
class SleepingPetAnimation extends StatefulWidget {
  /// 이미지 크기
  final double size;
  
  /// 애니메이션 속도 (초)
  final Duration duration;
  
  const SleepingPetAnimation({
    super.key,
    this.size = 192,
    this.duration = const Duration(milliseconds: 800),
  });
  
  @override
  State<SleepingPetAnimation> createState() => _SleepingPetAnimationState();
}

class _SleepingPetAnimationState extends State<SleepingPetAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<String> _sleepingImages;
  
  @override
  void initState() {
    super.initState();
    
    // 잠자는 이미지 경로 리스트
    _sleepingImages = [
      'assets/sleeping_1.jpg',
      'assets/sleeping_2.jpg',
      'assets/sleeping_3.jpg',
    ];
    
    // 애니메이션 컨트롤러 초기화
    // 3장의 이미지를 순환하므로 0.0 ~ 1.0 범위를 3등분
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// 현재 애니메이션 값에 따라 표시할 이미지 인덱스 결정
  /// 
  /// 0.0 ~ 1.0 범위를 3등분하여 각 이미지를 순환
  int _getCurrentImageIndex() {
    final value = _controller.value;
    // 0.0 ~ 0.33: 이미지 0
    // 0.33 ~ 0.66: 이미지 1
    // 0.66 ~ 1.0: 이미지 2
    if (value < 0.33) {
      return 0;
    } else if (value < 0.66) {
      return 1;
    } else {
      return 2;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final imageIndex = _getCurrentImageIndex();
        final imagePath = _sleepingImages[imageIndex];
        
        return Image.asset(
          imagePath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // 이미지 로드 실패 시 대체 위젯
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bedtime,
                size: 64,
                color: Colors.white,
              ),
            );
          },
        );
      },
    );
  }
}
