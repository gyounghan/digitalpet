import 'package:flutter/material.dart';

/// 펫 이미지 애니메이션 위젯
/// 
/// 펫의 상태(급식, 수면, 운동, 행복, 슬픔)에 따라 다른 이미지를 표시
/// 이미지의 실제 크기에 맞춰서 표시
class PetImageAnimation extends StatefulWidget {
  /// 펫 상태 타입
  final PetImageType type;
  
  /// 애니메이션 속도 (초)
  final Duration duration;
  
  const PetImageAnimation({
    super.key,
    required this.type,
    this.duration = const Duration(milliseconds: 800),
  });
  
  @override
  State<PetImageAnimation> createState() => _PetImageAnimationState();
}

/// 펫 이미지 타입
enum PetImageType {
  /// 급식 상태
  feed,
  /// 수면 상태
  sleep,
  /// 운동 상태
  exercise,
  /// 행복 상태
  happy,
  /// 지루함 상태
  bored,
  /// 불안함 상태
  anxious,
  /// 배부름 상태
  full,
  /// 슬픔/불안 상태
  sad,
}

class _PetImageAnimationState extends State<PetImageAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<String> _images;
  final Map<String, Size> _imageSizes = {};
  
  /// 최대 이미지 크기 (픽셀)
  /// 하단 overflow 방지를 위해 300px로 제한
  static const double maxImageSize = 300.0;
  
  @override
  void initState() {
    super.initState();
    _updateImages();
    _loadAllImageSizes();
    
    // 애니메이션 컨트롤러 초기화
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }
  
  /// 모든 이미지의 실제 크기 로드
  /// 
  /// 각 이미지의 크기를 개별적으로 로드하여 저장
  void _loadAllImageSizes() {
    if (_images.isEmpty) return;
    
    for (final imagePath in _images) {
      if (_imageSizes.containsKey(imagePath)) {
        continue; // 이미 로드된 이미지는 스킵
      }
      
      try {
        final imageProvider = AssetImage(imagePath);
        final imageStream = imageProvider.resolve(const ImageConfiguration());
        
        imageStream.addListener(
          ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
              if (mounted) {
                final originalSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
                
                setState(() {
                  _imageSizes[imagePath] = originalSize;
                });
              }
            },
          ),
        );
      } catch (e) {
        // 이미지 크기 로드 실패 시 무시
      }
    }
  }
  
  @override
  void didUpdateWidget(PetImageAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _updateImages();
      _loadAllImageSizes();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// 펫 상태에 따라 이미지 리스트 업데이트
  void _updateImages() {
    switch (widget.type) {
      case PetImageType.sleep:
        _images = [
          'assets/sleep_1.png',
          'assets/sleep_2.png',
          'assets/sleep_3.png',
        ];
        break;
      case PetImageType.feed:
        // 급식 이미지 4장 사용
        _images = [
          'assets/feed_1.png',
          'assets/feed_2.png',
          'assets/feed_3.png',
          'assets/feed_4.png',
        ];
        break;
      case PetImageType.exercise:
        _images = [
          'assets/exercise_1.png',
          'assets/exercise_2.png',
          'assets/exercise_3.png',
        ];
        break;
      case PetImageType.happy:
        _images = [
          'assets/happy_1.png',
          'assets/happy_2.png',
          'assets/happy_3.png',
        ];
        break;
      case PetImageType.bored:
        _images = [
          'assets/bored_1.png',
          'assets/bored_2.png',
          'assets/bored_3.png',
        ];
        break;
      case PetImageType.anxious:
        _images = [
          'assets/anxious_1.png',
          'assets/anxious_2.png',
          'assets/anxious_3.png',
        ];
        break;
      case PetImageType.full:
        _images = [
          'assets/full_1.png',
          'assets/full_2.png',
          'assets/full_3.png',
        ];
        break;
      case PetImageType.sad:
        _images = [
          'assets/sad_1.png',
          'assets/sad_2.png',
          'assets/sad_3.png',
        ];
        break;
    }
  }
  
  /// 펫 상태의 한글 이름 반환
  String _getMoodText() {
    switch (widget.type) {
      case PetImageType.sleep:
        return '수면 중💤';
      case PetImageType.feed:
        return '먹는 중🍖';
      case PetImageType.exercise:
        return '운동 중⚡';
      case PetImageType.happy:
        return '행복함😊';
      case PetImageType.bored:
        return '지루함😑';
      case PetImageType.anxious:
        return '불안함😰';
      case PetImageType.full:
        return '배부름🤢';
      case PetImageType.sad:
        return '슬픔😢';
    }
  }

  /// 펫 상태의 아이콘 반환
  IconData _getMoodIcon() {
    switch (widget.type) {
      case PetImageType.sleep:
        return Icons.bedtime;
      case PetImageType.feed:
        return Icons.restaurant;
      case PetImageType.exercise:
        return Icons.fitness_center;
      case PetImageType.happy:
        return Icons.sentiment_satisfied;
      case PetImageType.bored:
        return Icons.sentiment_neutral;
      case PetImageType.anxious:
        return Icons.sentiment_very_dissatisfied;
      case PetImageType.full:
        return Icons.sentiment_dissatisfied;
      case PetImageType.sad:
        return Icons.sentiment_dissatisfied;
    }
  }

  /// 이미지 로드 실패 시 표시할 fallback 위젯
  Widget _buildFallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getMoodIcon(),
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            _getMoodText(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 현재 애니메이션 값에 따라 표시할 이미지 인덱스 결정
  ///
  /// 0.0 ~ 1.0 범위를 이미지 개수만큼 등분하여 각 이미지를 순환
  int _getCurrentImageIndex() {
    final value = _controller.value;
    final imageCount = _images.length;
    final segmentSize = 1.0 / imageCount;
    
    for (int i = 0; i < imageCount; i++) {
      if (value < segmentSize * (i + 1)) {
        return i;
      }
    }
    return imageCount - 1;
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final imageIndex = _getCurrentImageIndex();
        final imagePath = _images[imageIndex];
        final imageSize = _imageSizes[imagePath];
        
        Widget content;

        // 이미지 크기가 아직 로드되지 않았으면 로딩 중 표시
        if (imageSize == null) {
          content = Image.asset(
            imagePath,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null) {
                // 이미지가 로드되면 크기 업데이트
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _loadAllImageSizes();
                  }
                });
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildFallback(200, 200);
            },
          );
        } else {
          // 각 이미지의 실제 크기를 기준으로 스케일링하여 표시
          // 최대 300px로 제한하면서 비율 유지
          double scale = 1.0;
          if (imageSize.width > maxImageSize) {
            scale = maxImageSize / imageSize.width;
          }
          if (imageSize.height * scale > maxImageSize) {
            scale = maxImageSize / imageSize.height;
          }
          
          final displayWidth = imageSize.width * scale;
          final displayHeight = imageSize.height * scale;
          
          content = FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Image.asset(
                imagePath,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback(displayWidth, displayHeight);
                },
              ),
            ),
          );
        }

        // 모든 프레임을 동일한 박스 하단에 고정해
        // 이미지 전환 시 펫이 위아래로 흔들리지 않게 한다.
        return SizedBox(
          width: maxImageSize,
          height: maxImageSize,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: content,
          ),
        );
      },
    );
  }
}
