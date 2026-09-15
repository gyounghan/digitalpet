import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../widgets/mock_ui_widgets.dart';
import '../widgets/frame_pet_animation.dart';
import '../widgets/pixel_motion_animation.dart';
import '../../core/anim/anim_manifest.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/feedback_service.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/play_with_pet_usecase.dart';

/// 놀아주기 미니게임 — 튕겨다니는 공을 탭하면 펫이 기뻐하며(joy) 하트가 터진다.
/// 펫이 화면에 등장해 반응하므로 "펫이랑 논다"는 느낌을 준다.
/// 점수는 펫의 행복도로 돌아간다. (행복 상한 100이라 farming 불가)
class PlayMinigameScreen extends ConsumerStatefulWidget {
  const PlayMinigameScreen({super.key});

  @override
  ConsumerState<PlayMinigameScreen> createState() => _PlayMinigameScreenState();
}

class _Heart {
  final int id;
  final double dx; // 펫 기준 좌우 오프셋(px)
  _Heart(this.id, this.dx);
}

class _PlayMinigameScreenState extends ConsumerState<PlayMinigameScreen> {
  static const int _durationSec = 15;
  static const double _toy = 52; // 공 크기
  static const double _petSize = 200;

  final math.Random _random = math.Random();
  Timer? _tick;
  Timer? _mover;
  Timer? _joyTimer;

  int _remaining = _durationSec;
  int _score = 0;
  bool _petJoy = false;
  bool _finished = false;

  // 공 위치·속도 (놀이 영역 비율 0..1)
  Offset _ball = const Offset(0.5, 0.3);
  double _vx = 0.016, _vy = 0.013;

  int _heartSeq = 0;
  final List<_Heart> _hearts = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _finish();
    });
    _mover = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      setState(() {
        var nx = _ball.dx + _vx, ny = _ball.dy + _vy;
        if (nx <= 0) {
          nx = 0;
          _vx = _vx.abs();
        } else if (nx >= 1) {
          nx = 1;
          _vx = -_vx.abs();
        }
        if (ny <= 0) {
          ny = 0;
          _vy = _vy.abs();
        } else if (ny >= 1) {
          ny = 1;
          _vy = -_vy.abs();
        }
        _ball = Offset(nx, ny);
      });
    });
  }

  void _hitBall() {
    FeedbackService.light();
    setState(() {
      _score++;
      _petJoy = true;
      _hearts.add(_Heart(_heartSeq++, (_random.nextDouble() - 0.5) * 90));
      // 공은 새 위치로 튀고 조금 빨라진다
      _ball = Offset(0.1 + _random.nextDouble() * 0.8,
          0.05 + _random.nextDouble() * 0.5);
      final speedUp = 1.0 + _score * 0.015;
      final dir = _random.nextBool() ? 1 : -1;
      _vx = 0.016 * speedUp * dir;
      _vy = 0.013 * speedUp * (_random.nextBool() ? 1 : -1);
    });
    final myHeart = _heartSeq - 1;
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hearts.removeWhere((h) => h.id == myHeart));
    });
    _joyTimer?.cancel();
    _joyTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _petJoy = false);
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    _mover?.cancel();
    _joyTimer?.cancel();
    setState(() => _hearts.clear());
    if (_score > 0) {
      FeedbackService.success();
      await ref
          .read(petNotifierProvider(ref.read(activePetIdProvider)).notifier)
          .play(_score);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _mover?.cancel();
    _joyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(activePetIdProvider);
    final pet = ref.watch(petNotifierProvider(petId)).valueOrNull;
    return Scaffold(
      backgroundColor: MockUI.stageMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: DesignTokens.ink,
        title: const Text('놀아주기',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: (_finished || pet == null)
            ? _buildResult()
            : _buildGame(pet),
      ),
    );
  }

  Widget _buildGame(Pet pet) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('점수 $_score',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.ink)),
              MockCoinPill('$_remaining초'),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 펫 — 하단 중앙에서 논다
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildPet(pet)),
                  ),
                  // 펫에서 터지는 하트
                  for (final heart in _hearts)
                    Positioned(
                      bottom: 120,
                      left: w / 2 + heart.dx,
                      child: _FloatingHeart(key: ValueKey(heart.id)),
                    ),
                  // 튕기는 공 (탭 대상)
                  Positioned(
                    left: _ball.dx * (w - _toy),
                    top: _ball.dy * (h * 0.62),
                    child: GestureDetector(
                      onTap: _hitBall,
                      child: Container(
                        width: _toy,
                        height: _toy,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MockUI.coral,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.sports_baseball,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 0,
                    child: Text('공을 탭해서 같이 놀아요!',
                        style: TextStyle(
                            fontSize: 12.5, color: DesignTokens.ink3)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 펫 렌더 — 홈과 동일 우선순위(프레임 → 도트 → 아이콘). joy일 때 기뻐한다.
  Widget _buildPet(Pet pet) {
    final motion = _petJoy ? PixelMotion.joy : PixelMotion.walk;
    final animKey =
        animKeyForOrFallback(pet.evolutionType, pet.evolutionStage, motion);
    if (animKey != null) {
      return FramePetAnimation(
        animKey: animKey,
        frameCount: animFrameCounts[animKey]!,
        width: _petSize,
        height: _petSize,
      );
    }
    final spriteKey = motionSpriteKeyForStage(
        pet.evolutionType, pet.evolutionStage, pet.evolutionGrade);
    if (spriteKey != null) {
      final theme = SpeciesTheme.forType(pet.evolutionType);
      final (dotColor, accentColor) =
          dotColorsForKey(spriteKey, pet.evolutionType, theme, pet.colorVariant);
      return PixelMotionAnimation(
        spriteKey: spriteKey,
        motion: motion,
        width: _petSize,
        height: _petSize,
        dotColor: dotColor,
        accentColor: accentColor,
        colorVariant: pet.colorVariant,
      );
    }
    return const Icon(Icons.pets, size: 96, color: DesignTokens.ink3);
  }

  Widget _buildResult() {
    final gain = _score * PlayWithPetUseCase.happinessPerHit;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, size: 56, color: DesignTokens.gold),
          const SizedBox(height: 12),
          Text('$_score번 같이 놀았어요!',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: DesignTokens.ink)),
          const SizedBox(height: 6),
          Text('행복 +$gain',
              style: const TextStyle(fontSize: 15, color: DesignTokens.ink2)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }
}

/// 펫에서 위로 떠오르며 사라지는 하트 하나.
class _FloatingHeart extends StatefulWidget {
  const _FloatingHeart({super.key});

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -60 * _c.value),
          child: Opacity(
            opacity: (1 - _c.value).clamp(0.0, 1.0),
            child: const Icon(Icons.favorite, color: MockUI.coral, size: 26),
          ),
        );
      },
    );
  }
}
