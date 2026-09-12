import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/anim/anim_manifest.dart';
import '../../domain/entities/evolution_type.dart';
import 'pixel_motion_animation.dart' show PixelMotion;

/// (종·단계·모션)에 프레임 애니메이션 에셋이 있으면 그 키를 반환, 없으면 null.
/// 키 = '{EvolutionType.name}_{stage}_{motion.name}' (예: 'gumiho_2_walk').
/// 우선순위(자체>AI)는 빌드 시 [animFrameCounts]에 이미 반영돼 있고,
/// 여기서 null이면 런타임이 도트 스프라이트로 폴백한다(3순위).
String? animKeyFor(EvolutionType? type, int stage, PixelMotion motion) {
  if (type == null) return null;
  final key = '${type.name}_${stage}_${motion.name}';
  return animFrameCounts.containsKey(key) ? key : null;
}

/// 해당 (종·단계·모션)에 프레임 애니메이션이 존재하는가.
bool hasFrameAnimation(EvolutionType? type, int stage, PixelMotion motion) =>
    animKeyFor(type, stage, motion) != null;

/// 투명 PNG 프레임 시퀀스를 루프 재생하는 펫 애니메이션.
///
/// `assets/anim/{animKey}_{i}.png` (0..frameCount-1)을 [fps]로 순환한다.
/// 프레임은 88px 픽셀아트라 확대는 nearest(FilterQuality.none)로 또렷하게.
class FramePetAnimation extends StatefulWidget {
  final String animKey;
  final int frameCount;
  final double width;
  final double height;
  final int fps;

  const FramePetAnimation({
    super.key,
    required this.animKey,
    required this.frameCount,
    required this.width,
    required this.height,
    this.fps = 12,
  });

  @override
  State<FramePetAnimation> createState() => _FramePetAnimationState();
}

class _FramePetAnimationState extends State<FramePetAnimation> {
  Timer? _timer;
  int _i = 0;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    final count = widget.frameCount;
    if (count <= 1) return; // 단일 프레임은 정지 표시
    final periodMs = (1000 / widget.fps).round().clamp(40, 400);
    _timer = Timer.periodic(Duration(milliseconds: periodMs), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % count);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // 프레임 전체 프리캐시 — 재생 중 깜빡임 방지
    for (var i = 0; i < widget.frameCount; i++) {
      precacheImage(AssetImage('assets/anim/${widget.animKey}_$i.png'), context);
    }
  }

  @override
  void didUpdateWidget(FramePetAnimation old) {
    super.didUpdateWidget(old);
    if (old.animKey != widget.animKey ||
        old.frameCount != widget.frameCount ||
        old.fps != widget.fps) {
      _i = 0;
      _precached = false;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/anim/${widget.animKey}_$_i.png',
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
    );
  }
}
