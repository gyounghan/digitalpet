import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';

/// 프로토타입의 .card / .pill / .meter / .top 시스템을 Flutter 위젯으로 추출.
/// 모든 위젯은 [SpeciesTheme]를 인자로 받아 종별 컬러를 따른다.

enum AppCardVariant {
  /// 일반 카드 (흰색 배경 + 부드러운 그림자)
  normal,

  /// 평면 카드 (1px 라인 보더)
  flat,

  /// 종 컬러 옅은 배경
  tinted,

  /// 종 컬러 진한 배경 (글자는 흰색)
  deep,
}

class AppCard extends StatelessWidget {
  final Widget child;
  final SpeciesTheme theme;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    required this.theme,
    this.variant = AppCardVariant.normal,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 18,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      AppCardVariant.normal => DesignTokens.surface,
      AppCardVariant.flat => DesignTokens.surface,
      AppCardVariant.tinted => theme.primarySoft,
      AppCardVariant.deep => theme.primary,
    };
    final borderRadius = BorderRadius.circular(radius);

    final decoration = BoxDecoration(
      color: gradient == null ? bg : null,
      gradient: gradient,
      borderRadius: borderRadius,
      border: variant == AppCardVariant.flat
          ? Border.all(color: DesignTokens.line, width: 1)
          : null,
      boxShadow: variant == AppCardVariant.flat
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: DesignTokens.line,
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
    );

    final body = Padding(padding: padding, child: child);

    Widget content = DecoratedBox(
      decoration: decoration,
      child: ClipRRect(borderRadius: borderRadius, child: body),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: content,
    );
  }
}

enum AppPillVariant {
  /// 흰색 + 라인 보더
  outline,

  /// 종 컬러 옅은 배경
  themed,

  /// 종 컬러 진한 배경 (글자는 흰색)
  solid,

  /// 검정색 배경 (글자는 흰색)
  dark,
}

class AppPill extends StatelessWidget {
  final String text;
  final SpeciesTheme theme;
  final AppPillVariant variant;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppPill({
    super.key,
    required this.text,
    required this.theme,
    this.variant = AppPillVariant.outline,
    this.icon,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, borderColor) = switch (variant) {
      AppPillVariant.outline => (
        DesignTokens.surface,
        DesignTokens.ink2,
        DesignTokens.line2,
      ),
      AppPillVariant.themed => (
        theme.primarySoft,
        theme.primaryDeep,
        Colors.transparent,
      ),
      AppPillVariant.solid => (
        theme.primary,
        Colors.white,
        Colors.transparent,
      ),
      AppPillVariant.dark => (
        DesignTokens.ink,
        Colors.white,
        Colors.transparent,
      ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum AppMeterTone { themed, good, warn, bad, neutral }

class AppMeter extends StatelessWidget {
  final double value;
  final double max;
  final SpeciesTheme theme;
  final AppMeterTone tone;
  final double height;
  final Color? trackColor;

  const AppMeter({
    super.key,
    required this.value,
    required this.theme,
    this.max = 100,
    this.tone = AppMeterTone.themed,
    this.height = 8,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    final fillColor = switch (tone) {
      AppMeterTone.themed => theme.primary,
      AppMeterTone.good => DesignTokens.good,
      AppMeterTone.warn => DesignTokens.warn,
      AppMeterTone.bad => DesignTokens.bad,
      AppMeterTone.neutral => DesignTokens.ink3,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: trackColor ?? const Color(0x141414CC).withValues(alpha: 0.08),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: pct,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 상단 헤더 (←, 타이틀, 우측 트레일링)
class ScreenTop extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const ScreenTop({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            _CircleButton(icon: Icons.arrow_back, onTap: onBack),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DesignTokens.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surface,
      shape: const CircleBorder(side: BorderSide(color: DesignTokens.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: DesignTokens.ink),
        ),
      ),
    );
  }
}

/// `.row` 클래스 매핑: 아이콘 + 제목/부제 + 화살표
class AppListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final SpeciesTheme theme;
  final bool tinted;
  final VoidCallback? onTap;

  const AppListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.theme,
    this.subtitle,
    this.trailing,
    this.tinted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      theme: theme,
      variant: tinted ? AppCardVariant.tinted : AppCardVariant.normal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(width: 38, height: 38, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 원형 게이지 — 목표 카드용 (CustomPainter)
class AppCircularGauge extends StatelessWidget {
  final double value;
  final double max;
  final SpeciesTheme theme;
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Widget? child;

  const AppCircularGauge({
    super.key,
    required this.value,
    required this.theme,
    this.max = 100,
    this.size = 72,
    this.strokeWidth = 8,
    this.trackColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(
              progress: pct,
              fillColor: theme.primary,
              trackColor: trackColor ?? theme.primarySoft,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  _GaugePainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708, // -π/2 (12시 방향 시작)
        progress * 6.2832, // 2π
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// `.section-title` 클래스 매핑
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: DesignTokens.ink,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
