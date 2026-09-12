import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../core/utils/pose_sheet.dart';
import '../../domain/entities/evolution_type.dart';
import 'pixel_motion_animation.dart';
import 'pixel_pet_image.dart';
import 'frame_pet_animation.dart';

/// 펫 대표 썸네일 — 도트 모션의 대표 프레임(walk 1프레임)을 그린다.
///
/// - 털뭉치~성숙기 전 단계: 도트 모션 첫 프레임을 종별 테마색으로
/// - 종 미결정(stage 2+ 인데 type null): '?' 표시
///
/// 배틀 내 펫 카드 / 도감 프로필·진화 트리 등 "프로필 사진" 자리 공용.
class PetMotionThumb extends StatelessWidget {
  final EvolutionType? type;
  final int stage;
  final double size;

  /// 진화 등급 — 성숙기 사신수('mythical')/일반종 분기용 (기본: 일반종)
  final String grade;

  /// 일반종 개체 색 변이(0~3) — 호출부에서 colorVariantFor(pet)로 계산해 전달
  final int variant;

  const PetMotionThumb({
    super.key,
    required this.type,
    required this.stage,
    required this.size,
    this.grade = '',
    this.variant = 0,
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

    // 1순위: 손수 보정한 정적 포즈시트(assets/pets)가 있으면 그대로 표시.
    final posePath = poseSheetAssetFor(type, stage);
    if (posePath != null) {
      final pad = size * 0.05;
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Image.asset(
            posePath,
            width: size - pad * 2,
            height: size - pad * 2,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      );
    }

    // 2순위: AI/자체 걷기 프레임이 있으면 대표(첫) 프레임을 고퀄 정지 이미지로
    // (썸네일은 애니메이션 대신 정지 프레임 — 다중 렌더 비용 절약).
    final animKey = animKeyFor(type, stage, PixelMotion.walk);
    if (animKey != null) {
      final pad = size * 0.05;
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Image.asset(
            'assets/anim/${animKey}_0.png',
            width: size - pad * 2,
            height: size - pad * 2,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      );
    }

    final theme = SpeciesTheme.forType(type);
    final key = motionSpriteKeyForStage(type, stage, grade);
    if (key != null) {
      final frames = motionFramesFor(key, PixelMotion.walk);
      if (frames != null && frames.isNotEmpty) {
        final (dotColor, accentColor) =
            dotColorsForKey(key, type, theme, variant);
        // 설화 영물은 레퍼런스 5색 팔레트로 (테마 재도색 대신 실제 색·색변이)
        final palette = hiddenPaletteForSpriteKey(key, variant);
        // 일부 스프라이트(주작 성장기 등)는 그리드 상단에 거의 붙어 있어
        // 컨테이너 가장자리와 겹치면 잘린 것처럼 보인다 — 숨 쉴 여백 확보
        final pad = size * 0.05;
        return SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: (palette != null && palette.length >= 5)
                ? PixelSpriteView(
                    sprite: frames.first,
                    width: size - pad * 2,
                    height: size - pad * 2,
                    darkColor: palette[0],
                    dotColor: palette[1],
                    accentColor: palette[2],
                    accent2Color: palette[3],
                    accent3Color: palette[4],
                  )
                : PixelSpriteView(
                    sprite: frames.first,
                    width: size - pad * 2,
                    height: size - pad * 2,
                    dotColor: dotColor,
                    accentColor: accentColor,
                  ),
          ),
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
