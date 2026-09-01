import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/species_theme.dart';
import '../../domain/entities/evolution_type.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/species_reveal_narrator.dart';
import '../widgets/pixel_motion_animation.dart';

/// 종 결정 풀스크린 연출 — "당신의 생활이 {사신수}를 깨웠어요"
///
/// 2단계 진화(Lv5 종 결정) 직후 1회만 노출된다 (HomeScreen이 관리).
/// 어두운 무대 위에 종 테마 글로우 + 도트 모션 + 판정 근거 2줄을
/// 순차 페이드로 보여준다. 근거 문구는 [SpeciesRevealNarrator]가
/// 실제 진화 판정과 같은 축 점수로 생성한다.
class SpeciesRevealScreen extends StatefulWidget {
  final Pet pet;

  const SpeciesRevealScreen({super.key, required this.pet});

  @override
  State<SpeciesRevealScreen> createState() => _SpeciesRevealScreenState();
}

class _SpeciesRevealScreenState extends State<SpeciesRevealScreen>
    with SingleTickerProviderStateMixin {
  static const Color _stageBg = Color(0xFF16181F);

  late final AnimationController _controller;
  late final Animation<double> _spriteFade;
  late final Animation<double> _spriteScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _reasonFade;
  late final Animation<double> _footerFade;

  late final SpeciesRevealStory _story;

  @override
  void initState() {
    super.initState();
    _story = SpeciesRevealNarrator.narrate(widget.pet);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _spriteFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _spriteScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.58, curve: Curves.easeOut),
    );
    _reasonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
    );
    _footerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SpeciesTheme.forType(_story.type);
    final spriteKey =
        motionSpriteKeyForStage(_story.type, 2) ?? 'fluff';
    final (dotColor, accentColor) =
        dotColorsForKey(spriteKey, _story.type, theme, widget.pet.colorVariant);

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
                  // 글로우 무대 + 도트 스프라이트
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
                            colorVariant: widget.pet.colorVariant,
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
                          _story.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: _reasonFade,
                    child: Column(
                      children: [
                        for (final line in _story.reasonLines) ...[
                          _reasonRow(line, theme),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _story.personality,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.glow,
                          ),
                        ),
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
                          AppStrings.speciesRevealConfirm,
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
            _story.type.isHiddenSpecies
                ? AppStrings.hiddenSpeciesRevealBadge
                : AppStrings.speciesRevealBadge,
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

  Widget _reasonRow(String line, SpeciesTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.5),
          child: Icon(Icons.circle, size: 5, color: theme.glow),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
