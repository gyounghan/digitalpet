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
  /// 어두운 배경(그라데이션 카드 위 흰 도트 상황) 대비 확인용 토글
  bool _darkBackground = false;

  /// 키 접두어로 종 테마색 추정 (도감 실제 표시색과 동일한 규칙)
  Color _dotColorForKey(String key) {
    if (_darkBackground) return Colors.white.withValues(alpha: 0.95);
    if (key.startsWith('tiger')) return SpeciesTheme.tiger.primary;
    if (key.startsWith('bird')) return SpeciesTheme.bird.primary;
    if (key.startsWith('turtle')) return SpeciesTheme.turtle.primary;
    if (key.startsWith('dragon')) return SpeciesTheme.snake.primary;
    return SpeciesTheme.defaultTheme.primary;
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
              Tab(text: '베이비 모션'),
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
    final speciesKeys = babyMotionFrames.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: speciesKeys.length,
      itemBuilder: (context, index) {
        final species = speciesKeys[index];
        final motions = babyMotionFrames[species]!.keys.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                species,
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
                  _buildMotionTile(species, motionName),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMotionTile(String species, String motionName) {
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
            species: species,
            motion: motion,
            dotColor: _dotColorForKey(species),
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
