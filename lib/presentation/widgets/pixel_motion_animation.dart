import 'package:flutter/material.dart';
import '../../core/pixel/pet_motion_data.dart';
import '../../core/pixel/pet_pixel_data.dart';
import '../../domain/entities/pet.dart';
import 'pixel_pet_image.dart';

/// 베이비(stage 2) 펫의 도트 모션 종류
enum PixelMotion {
  walk,
  eat,
  sleep,
  attack,
  dodge,
  hurt,
  angry,
  joy,
}

/// mood → 홈 화면 대기 모션 매핑
///
/// - happy → joy (점프+반짝이)
/// - normal → walk (뒤뚱뒤뚱)
/// - hungry → angry (배고파서 화남)
/// - sleepy/tired → sleep (엎드려 ZZZ)
/// - sad/dead → hurt (시무룩)
PixelMotion motionForMood(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return PixelMotion.joy;
    case PetMood.normal:
      return PixelMotion.walk;
    case PetMood.hungry:
      return PixelMotion.angry;
    case PetMood.sleepy:
      return PixelMotion.sleep;
    case PetMood.tired:
      return PixelMotion.sleep;
    case PetMood.sad:
      return PixelMotion.hurt;
    case PetMood.dead:
      return PixelMotion.hurt;
  }
}

/// 종/모션에 해당하는 프레임 조회 (없으면 null)
List<PixelSprite>? motionFramesFor(String species, PixelMotion motion) {
  return babyMotionFrames[species]?[motion.name];
}

/// 에셋 경로가 베이비(stage 2) 스프라이트('{species}1.png')이면 종 키 반환
///
/// 'assets/dragon1.png' → 'dragon', 'assets/dragon2.png' → null
String? babySpeciesFromAssetPath(String assetPath) {
  final key = pixelKeyFromAssetPath(assetPath);
  if (!key.endsWith('1')) return null;
  final species = key.substring(0, key.length - 1);
  return babyMotionFrames.containsKey(species) ? species : null;
}

/// 베이비 펫 도트 모션 애니메이션 — 3프레임 루프
///
/// [babyMotionFrames]의 합성 프레임을 순환 재생한다.
/// 프레임 데이터가 없으면 정적 베이비 스프라이트로 폴백.
///
/// 성능: [PetImageAnimation]과 동일하게 인덱스가 실제 바뀐 tick에만
/// setState 하여 rebuild를 최소화한다.
class PixelMotionAnimation extends StatefulWidget {
  /// 종 키 ('tiger' | 'bird' | 'turtle' | 'dragon')
  final String species;
  final PixelMotion motion;

  /// 한 사이클(3프레임) 재생 시간
  final Duration duration;
  final double? width;
  final double? height;

  /// 몸통 도트 색 (종별 테마색)
  final Color dotColor;

  /// 아웃라인 도트 색
  final Color darkColor;

  /// 보조색 도트 색 (배/부리/등딱지 — null이면 dotColor)
  final Color? accentColor;

  const PixelMotionAnimation({
    super.key,
    required this.species,
    required this.motion,
    this.duration = const Duration(milliseconds: 900),
    this.width,
    this.height,
    required this.dotColor,
    this.darkColor = const Color(0xFF33383F),
    this.accentColor,
  });

  @override
  State<PixelMotionAnimation> createState() => _PixelMotionAnimationState();
}

class _PixelMotionAnimationState extends State<PixelMotionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;

  List<PixelSprite>? get _frames =>
      motionFramesFor(widget.species, widget.motion);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addListener(_handleTick);
    _maybeStart();
  }

  void _maybeStart() {
    final frames = _frames;
    if (frames == null || frames.length <= 1) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _handleTick() {
    final frames = _frames;
    if (frames == null) return;
    final n = frames.length;
    var idx = (_controller.value * n).floor();
    if (idx >= n) idx = n - 1;
    if (idx != _currentIndex) {
      setState(() => _currentIndex = idx);
    }
  }

  @override
  void didUpdateWidget(PixelMotionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.species != widget.species ||
        oldWidget.motion != widget.motion) {
      _currentIndex = 0;
      _maybeStart();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames == null || frames.isEmpty) {
      // 프레임 데이터가 없으면 정적 베이비 스프라이트로 폴백
      return PixelPetImage(
        assetPath: 'assets/${widget.species}1.png',
        width: widget.width,
        height: widget.height,
        dotColor: widget.dotColor,
        darkColor: widget.darkColor,
        accentColor: widget.accentColor,
      );
    }
    final idx = _currentIndex < frames.length ? _currentIndex : 0;
    return PixelSpriteView(
      sprite: frames[idx],
      width: widget.width,
      height: widget.height,
      dotColor: widget.dotColor,
      darkColor: widget.darkColor,
      accentColor: widget.accentColor,
    );
  }
}
