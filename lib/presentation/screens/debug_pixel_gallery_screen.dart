import 'package:flutter/material.dart';

import '../../core/pixel/pet_motion_data.dart';
import '../../core/pixel/pet_pixel_data.dart';
import '../../core/theme/species_theme.dart';
import '../widgets/pixel_motion_animation.dart';
import '../widgets/pixel_pet_image.dart';

/// [디버그 전용] 픽셀 스프라이트/모션 전체 점검 갤러리
///
/// 생성된 도트 데이터(정적 146장 + 베이비 모션 96프레임)를 한 화면에서
/// 눈으로 확인하기 위한 임시 화면. 릴리스 전 진입 버튼과 함께 삭제한다.
class DebugPixelGalleryScreen extends StatefulWidget {
  const DebugPixelGalleryScreen({super.key});

  @override
  State<DebugPixelGalleryScreen> createState() =>
      _DebugPixelGalleryScreenState();
}

class _DebugPixelGalleryScreenState extends State<DebugPixelGalleryScreen> {
  /// 성숙기 색 미리보기용 표시 접미사 (실제 스프라이트 키 아님)
  static const String _matureSuffix = ' → 성숙기';

  /// 어두운 배경(그라데이션 카드 위 흰 도트 상황) 대비 확인용 토글
  bool _darkBackground = false;

  bool _isMatureKey(String key) => key.endsWith(_matureSuffix);

  String _baseKey(String key) => _isMatureKey(key)
      ? key.substring(0, key.length - _matureSuffix.length)
      : key;

  /// 키 접두어로 종 테마 추정 (도감 실제 표시색과 동일한 규칙)
  SpeciesTheme _themeForKey(String key) {
    if (key.startsWith('tiger')) return SpeciesTheme.tiger;
    if (key.startsWith('bird')) return SpeciesTheme.bird;
    if (key.startsWith('turtle')) return SpeciesTheme.turtle;
    if (key.startsWith('dragon')) return SpeciesTheme.snake;
    return SpeciesTheme.defaultTheme;
  }

  Color _dotColorForKey(String key) {
    if (_darkBackground) return Colors.white.withValues(alpha: 0.95);
    // 털뭉치는 종 미결정 → 밝은 베이지 단색 (홈과 동일)
    if (key == 'fluff') return SpeciesTheme.fluffBody;
    if (_isMatureKey(key)) return _themeForKey(_baseKey(key)).matureBody;
    return _themeForKey(key).primary;
  }

  /// 보조색 — 어두운 배경에서는 대비를 위해 반투명 흰색
  Color _accentColorForKey(String key) {
    if (_darkBackground) return Colors.white.withValues(alpha: 0.6);
    if (key == 'fluff') return SpeciesTheme.fluffAccent;
    if (_isMatureKey(key)) return SpeciesTheme.matureAccent;
    return _themeForKey(key).spriteAccent;
  }

  Color get _tileColor =>
      _darkBackground ? const Color(0xFF232832) : DesignTokens.surface;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            _darkBackground ? const Color(0xFF171B23) : DesignTokens.bg,
        appBar: AppBar(
          title: Text('픽셀 갤러리 (${petPixelSprites.length}장 · 디버그)'),
          actions: [
            IconButton(
              tooltip: '배경 밝기 전환',
              icon: Icon(
                  _darkBackground ? Icons.light_mode : Icons.dark_mode),
              onPressed: () =>
                  setState(() => _darkBackground = !_darkBackground),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '스프라이트'),
              Tab(text: '도트 모션'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSpriteGrid(),
            _buildMotionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpriteGrid() {
    final keys = petPixelSprites.keys.toList()..sort();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final sprite = petPixelSprites[key]!;
        return Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _tileColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DesignTokens.line),
                ),
                padding: const EdgeInsets.all(6),
                child: PixelSpriteView(
                  sprite: sprite,
                  dotColor: _dotColorForKey(key),
                  accentColor: _accentColorForKey(key),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: _darkBackground ? Colors.white70 : DesignTokens.ink3,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMotionList() {
    final baseKeys = motionFrames.keys.toList()..sort();
    // 성숙기(stage 4)는 성장기('{종}2') 모션 재활용 + matureBody/matureAccent —
    // 실제 성숙기 펫 없이도 색 조합을 점검할 수 있게 미리보기 행을 덧붙인다.
    final spriteKeys = [
      ...baseKeys,
      for (final key in baseKeys.where((key) => key.endsWith('2')))
        '$key$_matureSuffix',
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: spriteKeys.length,
      itemBuilder: (context, index) {
        final spriteKey = spriteKeys[index];
        final motions = motionFrames[_baseKey(spriteKey)]!.keys.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                spriteKey,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _darkBackground ? Colors.white : DesignTokens.ink,
                ),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final motionName in motions)
                  _buildMotionTile(spriteKey, motionName),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMotionTile(String spriteKey, String motionName) {
    final motion = PixelMotion.values.firstWhere(
      (candidate) => candidate.name == motionName,
      orElse: () => PixelMotion.walk,
    );
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: _tileColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DesignTokens.line),
          ),
          padding: const EdgeInsets.all(6),
          child: PixelMotionAnimation(
            spriteKey: _baseKey(spriteKey),
            motion: motion,
            dotColor: _dotColorForKey(spriteKey),
            accentColor: _accentColorForKey(spriteKey),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          motionName,
          style: TextStyle(
            fontSize: 10,
            color: _darkBackground ? Colors.white70 : DesignTokens.ink3,
          ),
        ),
      ],
    );
  }
}
