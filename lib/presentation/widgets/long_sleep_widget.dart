import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/species_theme.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../domain/entities/pet.dart';
import 'pet_image_animation.dart';
import 'pixel_motion_animation.dart';

/// 긴 잠 위젯
/// 펫이 긴 잠(isDead)에 빠졌을 때 HomeScreen에 표시되는 UI.
///
/// 사망·비석 컨셉이 아니라 "깨워주면 다시 함께할 수 있는 잠"으로 표현한다
/// (돌아온 유저를 벌하지 않는다 — PM_REVIEW.md 참조).
///
/// - [onWakeFree] 무료 깨우기 (수치 30/30/30 재시작)
/// - [onWakeWithAd] 광고 시청 깨우기 (완전 회복). 리워드 광고 흐름
///   (로드~표시/실패)을 끝까지 처리하는 Future를 반환해야 하며,
///   위젯은 그 동안 버튼을 비활성화하고 스피너를 표시한다.
class LongSleepWidget extends StatefulWidget {
  final Pet pet;
  final Future<void> Function() onWakeFree;
  final Future<void> Function() onWakeWithAd;

  const LongSleepWidget({
    super.key,
    required this.pet,
    required this.onWakeFree,
    required this.onWakeWithAd,
  });

  @override
  State<LongSleepWidget> createState() => _LongSleepWidgetState();
}

class _LongSleepWidgetState extends State<LongSleepWidget> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final theme = SpeciesTheme.forType(pet.evolutionType);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 잠든 펫 (기존 도트 그대로, 수면 모션 고정)
            _buildSleepingSprite(pet, theme),
            const SizedBox(height: 4),
            Text(
              'Zzz…',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[300],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${pet.name}, ${AppStrings.longSleepTitle}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.longSleepHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey[600],
              ),
            ),
            if (pet.deathDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${AppStrings.longSleepSinceLabel} ${_formatDate(pet.deathDate!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 24),
            // 무료 깨우기 — 낮은 수치로 재시작
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _isBusy ? null : () => _run(widget.onWakeFree),
                icon: const Icon(Icons.pets, size: 18),
                label: const Text(AppStrings.wakeFreeButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 광고 깨우기 — 완전 회복
            SizedBox(
              width: 240,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : () => _run(widget.onWakeWithAd),
                icon: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.card_giftcard, size: 18),
                label: Text(
                  _isBusy ? '광고 로딩 중...' : AppStrings.wakeAdButton,
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 잠든 펫 스프라이트 — 홈 무대와 동일한 렌더 경로에서 수면 모션만 고정
  Widget _buildSleepingSprite(Pet pet, SpeciesTheme theme) {
    final spriteKey = motionSpriteKeyForStage(
        pet.evolutionType, pet.evolutionStage, pet.evolutionGrade);
    if (spriteKey != null) {
      final (dotColor, accentColor) = dotColorsForKey(
          spriteKey, pet.evolutionType, theme, colorVariantFor(pet));
      return PixelMotionAnimation(
        spriteKey: spriteKey,
        motion: PixelMotion.sleep,
        width: 200,
        height: 200,
        dotColor: dotColor,
        accentColor: accentColor,
      );
    }
    return SizedBox(
      width: 200,
      height: 200,
      child: PetImageAnimation(
        type: PetImageType.sleep,
        duration: const Duration(milliseconds: 800),
        dotColor: theme.primary,
        accentColor: theme.spriteAccent,
        evolutionImagePath: getEvolutionMoodImagePath(
              pet.evolutionType,
              pet.evolutionStage,
              PetMood.sleepy,
            ) ??
            getEvolutionImagePath(
              pet.evolutionType,
              pet.evolutionStage,
            ),
      ),
    );
  }

  String _formatDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
