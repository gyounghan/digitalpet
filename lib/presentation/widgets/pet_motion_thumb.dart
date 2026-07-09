import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../domain/entities/evolution_type.dart';
import 'pixel_motion_animation.dart';
import 'pixel_pet_image.dart';

/// 펫 대표 썸네일 — 도트 모션의 대표 프레임(walk 1프레임)을 그린다.
///
/// - 털뭉치·유아기·성장기: 도트 모션 첫 프레임을 종별 테마색으로
/// - 성숙기(stage 4): 성장기 모션 재활용 + 짙은 몸통색·금빛 보조색
/// - 종 미결정(stage 2+ 인데 type null): '?' 표시
///
/// 배틀 내 펫 카드 / 도감 프로필·진화 트리 등 "프로필 사진" 자리 공용.
class PetMotionThumb extends StatelessWidget {
  final EvolutionType? type;
  final int stage;
  final double size;

  const PetMotionThumb({
    super.key,
    required this.type,
    required this.stage,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 종 미결정 상태에서 미래 단계는 알 수 없음 → '?'
    if (type == null && stage >= 2) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: DesignTokens.ink3,
            ),
          ),
        ),
      );
    }

    final theme = SpeciesTheme.forType(type);
    final key = motionSpriteKeyForStage(type, stage);
    if (key != null) {
      final frames = motionFramesFor(key, PixelMotion.walk);
      if (frames != null && frames.isNotEmpty) {
        final isFluff = key == 'fluff';
        final isMature = stage >= 4;
        return PixelSpriteView(
          sprite: frames.first,
          width: size,
          height: size,
          dotColor: isFluff
              ? SpeciesTheme.fluffBody
              : (isMature ? theme.matureBody : theme.primary),
          accentColor: isFluff
              ? SpeciesTheme.fluffAccent
              : (isMature ? SpeciesTheme.matureAccent : theme.spriteAccent),
        );
      }
    }
    final imagePath = getEvolutionImagePath(type, stage);
    if (imagePath != null) {
      return PixelPetImage(
        assetPath: imagePath,
        width: size,
        height: size,
        dotColor: theme.primary,
        accentColor: theme.spriteAccent,
        fallback: Icon(Icons.pets, size: size * 0.6, color: DesignTokens.ink3),
      );
    }
    return Icon(Icons.pets, size: size * 0.6, color: DesignTokens.ink3);
  }
}
