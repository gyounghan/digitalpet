import 'package:flutter/material.dart';
import '../../core/pixel/pet_motion_data.dart';
import '../../core/pixel/pet_pixel_data.dart';
import '../../core/pixel/hidden_palette.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../core/theme/species_theme.dart';
import '../../domain/entities/evolution_type.dart';
import '../../domain/entities/pet.dart';
import 'pixel_pet_image.dart';

/// 스프라이트 키 + 색변이에서 설화 영물 5색 팔레트 조회 (아니면 null).
///
/// [variant] 0=원본(제일 좋은 자기 색), 1=밝은, 2=어두운.
/// 키 형식: '{종}{스테이지}' — 예: 'gumiho2', 'haetae3'.
List<Color>? hiddenPaletteForSpriteKey(String spriteKey, [int variant = 0]) {
  for (final species in hiddenSpeciesPalette.keys) {
    if (spriteKey.startsWith(species)) {
      final variants = hiddenSpeciesPalette[species]!;
      return variants[variant.clamp(0, variants.length - 1)];
    }
  }
  return null;
}

/// 도트 모션 종류 (유아기 stage 2 / 성장기 stage 3 공통)
enum PixelMotion {
  walk,
  eat,
  sleep,
  attack,
  dodge,
  hurt,
  angry,
  joy,
  hungry,
}

/// mood → 홈 화면 대기 모션 매핑
///
/// - happy → joy (점프+반짝이)
/// - normal → walk (뒤뚱뒤뚱)
/// - hungry → hungry (침 흘리며 조름)
/// - sleepy/tired → sleep (엎드려 ZZZ)
/// - sad → hurt (시무룩), dead(긴 잠) → sleep
PixelMotion motionForMood(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return PixelMotion.joy;
    case PetMood.normal:
      return PixelMotion.walk;
    case PetMood.hungry:
      return PixelMotion.hungry;
    case PetMood.sleepy:
      return PixelMotion.sleep;
    case PetMood.tired:
      return PixelMotion.sleep;
    case PetMood.sad:
      return PixelMotion.hurt;
    case PetMood.dead:
      // 긴 잠 컨셉 — 잠자는 모습으로 표현
      return PixelMotion.sleep;
  }
}

/// 스프라이트 키/모션에 해당하는 프레임 조회 (없으면 null)
List<PixelSprite>? motionFramesFor(String spriteKey, PixelMotion motion) {
  return motionFrames[spriteKey]?[motion.name];
}

/// 진화 단계 → 도트 모션 스프라이트 키 (홈/썸네일/위젯 공통 규칙)
///
/// - stage 1 (털뭉치)  → 'fluff' (40)
/// - stage 2 (유아기)  → '{종}1' (32)
/// - stage 3 (성장기)  → '{종}2' (36)
/// - stage 4 (성숙기)  → 사신수(mythical) '{종}3' / 일반종 '{종}3n' (56)
/// - 종 미결정 stage 2+ → null
String? motionSpriteKeyForStage(EvolutionType? type, int stage,
    [String grade = '']) {
  if (stage <= 1) return 'fluff';
  final species = evolutionSpeciesImagePrefix(type);
  if (species == null) return null;
  // 10종 통일: 등급·'n' 없이 단일 디자인. stage2→{종}1, 3→{종}2, 4→{종}3.
  return '$species${stage - 1}';
}

/// 개체 색 변이(0~2) — [Pet.colorVariant] 위임 (렌더부 편의 래퍼).
int colorVariantFor(Pet pet) => pet.colorVariant;

/// 사신수 도트 (몸통색, 보조색) — 색변이별. 0=테마 원색(제일 좋은 자기 색),
/// 1·2=자연 모프(naturalDotColors 재사용). 히든 종은 이 경로가 아니라
/// [hiddenPaletteForSpriteKey]의 5색 팔레트로 렌더된다.
(Color, Color) dotColorsForKey(
    String? spriteKey, EvolutionType? type, SpeciesTheme theme,
    [int variant = 0]) {
  if (spriteKey == 'fluff') {
    return (SpeciesTheme.fluffBody, SpeciesTheme.fluffAccent);
  }
  final v = variant.clamp(0, 2); // 3변이로 통일 (원본 + 밝은/어두운 자연 모프)
  if (v == 0) {
    return (theme.primary, theme.spriteAccent);
  }
  return SpeciesTheme.naturalDotColors(type, v - 1);
}

/// 에셋 경로에 모션 데이터가 있으면 스프라이트 키 반환
///
/// 'assets/기본이미지.png' → 'fluff' (털뭉치),
/// 'assets/dragon1.png' → 'dragon1' ... 'assets/dragon3.png' → 'dragon3'
String? motionSpriteKeyFromAssetPath(String assetPath) {
  final key = pixelKeyFromAssetPath(assetPath);
  final spriteKey = key == '기본이미지' ? 'fluff' : key;
  return motionFrames.containsKey(spriteKey) ? spriteKey : null;
}

/// 펫 도트 모션 애니메이션 — 3프레임 루프
///
/// [motionFrames]의 합성 프레임을 순환 재생한다.
/// 프레임 데이터가 없으면 같은 이름의 정적 스프라이트로 폴백.
///
/// 성능: [PetImageAnimation]과 동일하게 인덱스가 실제 바뀐 tick에만
/// setState 하여 rebuild를 최소화한다.
class PixelMotionAnimation extends StatefulWidget {
  /// 스프라이트 키 ('{종}{스테이지}' — 예: 'dragon1', 'tiger2')
  final String spriteKey;
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

  /// 색 변이 0~2 — 설화 영물 팔레트 선택용 (사신수는 색이 dotColor로 전달됨)
  final int colorVariant;

  const PixelMotionAnimation({
    super.key,
    required this.spriteKey,
    required this.motion,
    this.duration = const Duration(milliseconds: 900),
    this.width,
    this.height,
    required this.dotColor,
    this.darkColor = SpeciesTheme.dotDark,
    this.accentColor,
    this.colorVariant = 0,
  });

  @override
  State<PixelMotionAnimation> createState() => _PixelMotionAnimationState();
}

class _PixelMotionAnimationState extends State<PixelMotionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;

  List<PixelSprite>? get _frames =>
      motionFramesFor(widget.spriteKey, widget.motion);

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
    if (oldWidget.spriteKey != widget.spriteKey ||
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
      // 프레임 데이터가 없으면 같은 키의 정적 스프라이트로 폴백
      return PixelPetImage(
        assetPath: 'assets/${widget.spriteKey}.png',
        width: widget.width,
        height: widget.height,
        dotColor: widget.dotColor,
        darkColor: widget.darkColor,
        accentColor: widget.accentColor,
      );
    }
    final idx = _currentIndex < frames.length ? _currentIndex : 0;

    // 설화 영물은 레퍼런스 5색 팔레트로 렌더 (테마 재도색 대신 실제 색)
    final palette =
        hiddenPaletteForSpriteKey(widget.spriteKey, widget.colorVariant);
    if (palette != null && palette.length >= 5) {
      return PixelSpriteView(
        sprite: frames[idx],
        width: widget.width,
        height: widget.height,
        darkColor: palette[0],
        dotColor: palette[1],
        accentColor: palette[2],
        accent2Color: palette[3],
        accent3Color: palette[4],
      );
    }

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
