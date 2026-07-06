import 'package:flutter/material.dart';
import 'pixel_pet_image.dart';

/// 펫 도트 애니메이션 위젯
///
/// 펫의 상태(급식, 수면, 운동, 행복, 슬픔)에 따라 다른 프레임을 표시.
/// evolutionImagePath가 주어지면 정적 도트 스프라이트 (사신수 mood) 표시.
///
/// 렌더링은 이미지 디코딩 없이 좌표 데이터([PixelPetImage]) 기반 도트로
/// 그린다 — 다마고치 LCD 스타일.
///
/// 성능:
/// - AnimationController(vsync)를 사용해 TickerMode로 자동 정지 가능
///   (탭 비활성, 백그라운드 등에서 자동 멈춤)
/// - AnimatedBuilder(매 프레임 rebuild) 대신 listener로 인덱스가
///   실제 변경된 프레임에만 setState 호출 → CPU 60x 감소
class PetImageAnimation extends StatefulWidget {
  final PetImageType type;
  final Duration duration;
  final String? evolutionImagePath;

  /// 몸통 도트 색 (종별 테마색)
  final Color dotColor;

  /// 보조색 도트 색 (배/부리 등 — null이면 dotColor)
  final Color? accentColor;

  const PetImageAnimation({
    super.key,
    required this.type,
    this.duration = const Duration(milliseconds: 800),
    this.evolutionImagePath,
    this.dotColor = const Color(0xFF7BAA6E),
    this.accentColor,
  });

  @override
  State<PetImageAnimation> createState() => _PetImageAnimationState();
}

enum PetImageType {
  feed,
  sleep,
  exercise,
  happy,
  bored,
  anxious,
  full,
  sad,
}

class _PetImageAnimationState extends State<PetImageAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;
  late List<String> _images;

  /// 도트 캔버스 크기 (픽셀) - 하단 overflow 방지
  static const double maxImageSize = 300.0;

  @override
  void initState() {
    super.initState();
    _updateImages();

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addListener(_handleTick);
    _maybeStart();
  }

  /// 정적 이미지가 아닐 때만 controller 동작
  void _maybeStart() {
    if (widget.evolutionImagePath != null || _images.length <= 1) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  /// 매 vsync tick에서 호출되지만, 인덱스가 실제로 변경된 경우에만 setState.
  /// 이 덕분에 60fps × 800ms = 48프레임 중 단 3~4번만 rebuild 발생.
  void _handleTick() {
    final newIndex = _computeIndex(_controller.value);
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  int _computeIndex(double value) {
    final n = _images.length;
    if (n <= 1) return 0;
    final idx = (value * n).floor();
    return idx >= n ? n - 1 : idx;
  }

  @override
  void didUpdateWidget(PetImageAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    var restart = false;
    if (oldWidget.type != widget.type) {
      _updateImages();
      _currentIndex = 0;
      restart = true;
    }
    if (oldWidget.evolutionImagePath != widget.evolutionImagePath) {
      restart = true;
    }
    if (restart) _maybeStart();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  void _updateImages() {
    switch (widget.type) {
      case PetImageType.sleep:
        _images = const [
          'assets/sleep_1.png',
          'assets/sleep_2.png',
          'assets/sleep_3.png',
        ];
      case PetImageType.feed:
        _images = const [
          'assets/feed_1.png',
          'assets/feed_2.png',
          'assets/feed_3.png',
          'assets/feed_4.png',
        ];
      case PetImageType.exercise:
        _images = const [
          'assets/exercise_1.png',
          'assets/exercise_2.png',
          'assets/exercise_3.png',
        ];
      case PetImageType.happy:
        _images = const [
          'assets/happy_1.png',
          'assets/happy_2.png',
          'assets/happy_3.png',
        ];
      case PetImageType.bored:
        _images = const [
          'assets/bored_1.png',
          'assets/bored_2.png',
          'assets/bored_3.png',
        ];
      case PetImageType.anxious:
        _images = const [
          'assets/anxious_1.png',
          'assets/anxious_2.png',
          'assets/anxious_3.png',
        ];
      case PetImageType.full:
        _images = const [
          'assets/full_1.png',
          'assets/full_2.png',
          'assets/full_3.png',
        ];
      case PetImageType.sad:
        _images = const [
          'assets/sad_1.png',
          'assets/sad_2.png',
          'assets/sad_3.png',
        ];
    }
  }

  /// 도트 스프라이트 한 프레임 (하단 정렬, 정사각 캔버스)
  Widget _buildSprite(String path) {
    return SizedBox(
      width: maxImageSize,
      height: maxImageSize,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: PixelPetImage(
          assetPath: path,
          width: maxImageSize * 0.9,
          height: maxImageSize * 0.9,
          dotColor: widget.dotColor,
          accentColor: widget.accentColor,
          fallback: _fallbackIcon(),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.type == PetImageType.sleep
            ? Icons.bedtime
            : widget.type == PetImageType.feed
                ? Icons.restaurant
                : widget.type == PetImageType.sad
                    ? Icons.sentiment_dissatisfied
                    : Icons.pets,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.evolutionImagePath != null) {
      return _buildSprite(widget.evolutionImagePath!);
    }
    if (_images.isEmpty) return const SizedBox.shrink();
    return _buildSprite(_images[_currentIndex]);
  }
}
