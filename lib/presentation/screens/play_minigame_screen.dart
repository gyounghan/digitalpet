import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../widgets/mock_ui_widgets.dart';
import '../../core/theme/species_theme.dart';
import '../../data/services/feedback_service.dart';
import '../../domain/usecases/play_with_pet_usecase.dart';

/// 놀아주기 미니게임 — 제한 시간 동안 떠오르는 하트를 탭해 점수를 쌓고,
/// 점수를 펫의 행복도로 돌려준다. (행복 상한 100이라 farming 불가)
class PlayMinigameScreen extends ConsumerStatefulWidget {
  const PlayMinigameScreen({super.key});

  @override
  ConsumerState<PlayMinigameScreen> createState() => _PlayMinigameScreenState();
}

class _Heart {
  final int id;
  final double left; // 0..1
  final double top; // 0..1
  _Heart(this.id, this.left, this.top);
}

class _PlayMinigameScreenState extends ConsumerState<PlayMinigameScreen> {
  static const int _durationSec = 15;

  final math.Random _random = math.Random();
  Timer? _tick;
  Timer? _spawner;
  int _remaining = _durationSec;
  int _score = 0;
  int _heartSeq = 0;
  final List<_Heart> _hearts = [];
  bool _finished = false;

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
    _spawner = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() {
        final id = _heartSeq++;
        _hearts.add(_Heart(
          id,
          0.08 + _random.nextDouble() * 0.84,
          0.08 + _random.nextDouble() * 0.78,
        ));
      });
      final id = _heartSeq - 1;
      // 하트는 잠깐 떴다가 사라진다
      Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _hearts.removeWhere((h) => h.id == id));
      });
    });
  }

  void _tapHeart(_Heart heart) {
    FeedbackService.light();
    setState(() {
      _hearts.removeWhere((h) => h.id == heart.id);
      _score++;
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    _spawner?.cancel();
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
    _spawner?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MockUI.screenTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: DesignTokens.ink,
        title: const Text('놀아주기',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(child: _finished ? _buildResult() : _buildGame()),
    );
  }

  Widget _buildGame() {
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
              return Stack(
                children: [
                  const Center(
                    child: Text('하트를 탭하세요!',
                        style: TextStyle(
                            fontSize: 13, color: DesignTokens.ink3)),
                  ),
                  for (final heart in _hearts)
                    Positioned(
                      left: heart.left * (constraints.maxWidth - 44),
                      top: heart.top * (constraints.maxHeight - 44),
                      child: GestureDetector(
                        onTap: () => _tapHeart(heart),
                        child: const Icon(Icons.favorite,
                            color: MockUI.coral, size: 40),
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

  Widget _buildResult() {
    final gain = _score * PlayWithPetUseCase.happinessPerHit;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, size: 56, color: DesignTokens.gold),
          const SizedBox(height: 12),
          Text('$_score개 성공!',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: DesignTokens.ink)),
          const SizedBox(height: 6),
          Text('행복 +$gain',
              style: const TextStyle(
                  fontSize: 15, color: DesignTokens.ink2)),
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
