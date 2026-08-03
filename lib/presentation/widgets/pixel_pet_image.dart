import 'package:flutter/material.dart';
import '../../core/pixel/pet_pixel_data.dart';
import '../../core/theme/species_theme.dart';

/// 에셋 경로 → 도트 스프라이트 키 변환
///
/// 'assets/dragon2.png' → 'dragon2'
String pixelKeyFromAssetPath(String assetPath) {
  var key = assetPath;
  final slash = key.lastIndexOf('/');
  if (slash >= 0) key = key.substring(slash + 1);
  final dot = key.lastIndexOf('.');
  if (dot >= 0) key = key.substring(0, dot);
  return key;
}

/// 에셋 경로에 대응하는 도트 스프라이트 조회 (없으면 null)
PixelSprite? pixelSpriteForAsset(String assetPath) {
  return petPixelSprites[pixelKeyFromAssetPath(assetPath)];
}

/// 도트 펫 렌더러 — 다마고치 LCD 스타일
///
/// 이미지를 디코딩하지 않고, 오프라인 생성된 좌표 데이터
/// ([petPixelSprites])의 위치에 사각 도트만 찍어 펫을 표현한다.
///
/// 3계조:
/// - dark 도트(아웃라인/눈): [darkColor]
/// - body 도트(몸통): [dotColor] — 종별 테마색을 넣는 용도
/// - accent 도트(배/부리/등딱지 등): [accentColor] — 미지정 시 [dotColor]
///
/// 스프라이트 데이터가 없는 에셋이면 [fallback] 위젯을 표시한다.
class PixelPetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;

  /// 몸통 도트 색 (종별 테마색)
  final Color dotColor;

  /// 아웃라인 도트 색
  final Color darkColor;

  /// 보조색 도트 색 (null이면 [dotColor]로 그려 기존 2계조와 동일)
  final Color? accentColor;

  /// 스프라이트 데이터가 없을 때 표시할 위젯
  final Widget? fallback;

  const PixelPetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    required this.dotColor,
    this.darkColor = SpeciesTheme.dotDark,
    this.accentColor,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = pixelSpriteForAsset(assetPath);
    if (sprite == null) {
      return SizedBox(
        width: width,
        height: height,
        child: fallback ?? const Icon(Icons.pets),
      );
    }
    return PixelSpriteView(
      sprite: sprite,
      width: width,
      height: height,
      dotColor: dotColor,
      darkColor: darkColor,
      accentColor: accentColor,
    );
  }
}

/// [PixelSprite]를 직접 받아 도트로 그리는 뷰
///
/// 에셋 경로 없이 스프라이트 객체를 그릴 때 사용 (모션 프레임 등).
class PixelSpriteView extends StatelessWidget {
  final PixelSprite sprite;
  final double? width;
  final double? height;
  final Color dotColor;
  final Color darkColor;
  final Color? accentColor;

  const PixelSpriteView({
    super.key,
    required this.sprite,
    this.width,
    this.height,
    required this.dotColor,
    this.darkColor = SpeciesTheme.dotDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _PixelSpritePainter(
            sprite: sprite,
            dotColor: dotColor,
            darkColor: darkColor,
            accentColor: accentColor ?? dotColor,
          ),
        ),
      ),
    );
  }
}

/// 비트마스크 행 데이터를 도트(사각형)로 그리는 painter
class _PixelSpritePainter extends CustomPainter {
  final PixelSprite sprite;
  final Color dotColor;
  final Color darkColor;
  final Color accentColor;

  /// 도트 사이 간격 비율 (0이면 도트가 붙어 통짜 실루엣으로 보임)
  static const double gapRatio = 0.0;

  /// 인접 도트 경계에 생기는 안티에일리어싱 흰 실선(seam)을 없애기 위한
  /// 미세 오버랩 (px) — 각 도트를 오른쪽·아래로 살짝 키워 맞물리게 한다.
  static const double _seamOverlap = 0.5;

  _PixelSpritePainter({
    required this.sprite,
    required this.dotColor,
    required this.darkColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = sprite.size;
    final cell = size.shortestSide / n;
    final inset = cell * gapRatio / 2;

    // 색상별 Path로 모아 한 번에 그린다 (drawRect 반복보다 빠름)
    final bodyPath = Path();
    final darkPath = Path();
    final accentPath = Path();

    for (var y = 0; y < n; y++) {
      final darkMask = sprite.dark[y];
      final bodyMask = sprite.body[y];
      final accentMask = y < sprite.accent.length ? sprite.accent[y] : 0;
      if (darkMask == 0 && bodyMask == 0 && accentMask == 0) continue;
      for (var x = 0; x < n; x++) {
        final bit = 1 << x;
        final isDark = (darkMask & bit) != 0;
        final isBody = (bodyMask & bit) != 0;
        final isAccent = (accentMask & bit) != 0;
        if (!isDark && !isBody && !isAccent) continue;
        final rect = Rect.fromLTWH(
          x * cell + inset,
          y * cell + inset,
          cell - inset * 2 + _seamOverlap,
          cell - inset * 2 + _seamOverlap,
        );
        (isDark ? darkPath : (isAccent ? accentPath : bodyPath)).addRect(rect);
      }
    }

    canvas.drawPath(bodyPath, Paint()..color = dotColor);
    canvas.drawPath(accentPath, Paint()..color = accentColor);
    canvas.drawPath(darkPath, Paint()..color = darkColor);
  }

  @override
  bool shouldRepaint(_PixelSpritePainter oldDelegate) {
    return oldDelegate.sprite != sprite ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.accentColor != accentColor;
  }
}
