import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/species_theme.dart';
import '../../domain/entities/evolution_type.dart';
import '../../domain/entities/pet.dart';
import '../widgets/pixel_motion_animation.dart';

/// 진화 풀스크린 연출 — 3단계(성장기)·4단계(성숙기) 도달 순간
///
/// 2단계(종 결정)는 [SpeciesRevealScreen]이 전담하고, 이 화면은 그 이후
/// 단계 전이를 담당한다. 어두운 무대 + 테마 글로우 위에 새 형태의 도트
/// 모션(joy)을 띄우고 단계 라벨·형태 이름을 순차 페이드로 보여준다.
/// 노출 판정(기기에서 마지막으로 본 단계와 비교)은 HomeScreen이 관리.
class EvolutionRevealScreen extends StatefulWidget {
  final Pet pet;

  const EvolutionRevealScreen({super.key, required this.pet});

  @override
  State<EvolutionRevealScreen> createState() => _EvolutionRevealScreenState();
}

class _EvolutionRevealScreenState extends State<EvolutionRevealScreen>
    with SingleTickerProviderStateMixin {
  static const Color _stageBg = Color(0xFF16181F);

  late final AnimationController _controller;
  late final Animation<double> _spriteFade;
  late final Animation<double> _spriteScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _spriteFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _spriteScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.38, 0.7, curve: Curves.easeOut),
    );
    _footerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 새 형태의 이름 (예: 봉황, 백호) — 매핑이 없으면 null
  String? get _formName {
    final pet = widget.pet;
    final species = pet.evolutionType?.name;
    if (species == null) return null;
    if (pet.evolutionStage == 3) {
      return AppStrings.stage3Names[species]?[pet.evolutionGrade];
    }
    if (pet.evolutionStage == 4) {
      return AppStrings.stage4Names[species]?[pet.evolutionGrade];
    }
    return null;
  }

  bool get _isMythical =>
      widget.pet.evolutionStage == 4 && widget.pet.evolutionGrade == 'mythical';

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final theme = SpeciesTheme.forType(pet.evolutionType);
    final spriteKey = motionSpriteKeyForStage(
            pet.evolutionType, pet.evolutionStage, pet.evolutionGrade) ??
        'fluff';
    final (dotColor, accentColor) =
        dotColorsForKey(spriteKey, pet.evolutionType, theme, pet.colorVariant);
    final stageLabel = AppStrings.stageLabels[pet.evolutionStage] ?? '';
    final formName = _formName;

    return Scaffold(
      backgroundColor: _stageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _spriteFade,
                    child: ScaleTransition(
                      scale: _spriteScale,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              theme.glow.withValues(alpha: 0.4),
                              theme.glow.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Center(
                          child: PixelMotionAnimation(
                            spriteKey: spriteKey,
                            motion: PixelMotion.joy,
                            width: 210,
                            height: 210,
                            dotColor: dotColor,
                            accentColor: accentColor,
                            colorVariant: pet.colorVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _titleFade,
                    child: Column(
                      children: [
                        _badge(theme),
                        const SizedBox(height: 12),
                        Text(
                          '${pet.name}, $stageLabel로 진화했어요!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        if (formName != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            '이제 $formName의 모습이에요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.glow,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _footerFade,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          AppStrings.evolutionRevealConfirm,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(SpeciesTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.glow.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: theme.glow),
          const SizedBox(width: 5),
          Text(
            _isMythical
                ? (widget.pet.evolutionType?.isHiddenSpecies == true
                    ? AppStrings.evolutionRevealBadgeHiddenMythical
                    : AppStrings.evolutionRevealBadgeMythical)
                : AppStrings.evolutionRevealBadge,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: theme.glow,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
