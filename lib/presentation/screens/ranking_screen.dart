import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/pixel_pet_image.dart';
import '../../core/theme/species_theme.dart';
import '../../core/utils/pet_image_helper.dart';
import '../../data/datasources/ranking_remote_datasource.dart';
import '../../domain/entities/evolution_type.dart';
import 'home_screen.dart';

/// 랭킹 화면 - 프로토타입 디자인 + 서버 연동
///
/// 데이터 소스:
/// - 서버 GET /ranking/me/:deviceId — TOP3 + 내 주변 5명
/// - 서버 unreachable 시 안내 배너 + 비어있는 리스트 (오프라인 폴백)
///
/// 친구/레벨대 탭은 현재 서버 미지원 → "준비 중" 배너로 안내.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  /// 0=친구(준비중), 1=전체(서버), 2=레벨대(준비중)
  int _tabIndex = 1;
  Future<_RankingData>? _future;
  String? _loadedDeviceId;

  Future<_RankingData> _load() async {
    final datasource = ref.read(rankingRemoteDatasourceProvider);
    final deviceIdSource = ref.read(deviceIdDatasourceProvider);
    final deviceId = await deviceIdSource.getOrCreateDeviceId();
    _loadedDeviceId = deviceId;
    final response = await datasource.getAroundMe(deviceId);
    if (response == null) {
      return _RankingData.offline();
    }
    return _RankingData(
      top3: response.top3,
      surrounding: response.surrounding,
      me: response.me,
      totalCount: response.totalCount,
      isOffline: false,
    );
  }

  Future<_RankingData> _getFuture() {
    return _future ??= _load();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (pet) {
            final theme = SpeciesTheme.forType(pet.evolutionType);
            final canPop = Navigator.of(context).canPop();
            return Column(
              children: [
                ScreenTop(
                  title: '랭킹',
                  onBack: canPop ? () => Navigator.of(context).pop() : null,
                  trailing: GestureDetector(
                    onTap: _refresh,
                    child: AppPill(
                      text: '새로고침',
                      theme: theme,
                      variant: AppPillVariant.themed,
                      icon: Icons.refresh,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_RankingData>(
                    future: _getFuture(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: theme.primary),
                        );
                      }
                      final data = snapshot.data ?? _RankingData.offline();
                      return _buildList(theme, data, pet);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(SpeciesTheme theme, _RankingData data, dynamic pet) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        _buildTabBar(theme),
        const SizedBox(height: 12),
        if (_tabIndex != 1) ...[
          _comingSoonBanner(theme),
        ] else if (data.isOffline) ...[
          _offlineBanner(theme),
        ] else ...[
          if (data.top3.length >= 3) _buildPodium(data.top3, theme),
          const SizedBox(height: 12),
          if (data.surrounding.isEmpty)
            _emptyBanner(theme, pet)
          else
            _buildRankingList(data.surrounding, theme),
          const SizedBox(height: 12),
          _totalCountFooter(data.totalCount, theme),
        ],
      ],
    );
  }

  Widget _buildTabBar(SpeciesTheme theme) {
    const labels = ['친구', '전체', '레벨대'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : DesignTokens.ink3,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPodium(List<RankingEntryDto> top3, SpeciesTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Podium(entry: _toRow(top3[1]), height: 70, theme: theme),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Podium(
              entry: _toRow(top3[0]), height: 94, crown: true, theme: theme),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Podium(entry: _toRow(top3[2]), height: 56, theme: theme),
        ),
      ],
    );
  }

  Widget _buildRankingList(List<RankingEntryDto> list, SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.flat,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            _RankingRow(entry: _toRow(list[i]), theme: theme),
            if (i < list.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: DesignTokens.line,
                indent: 14,
                endIndent: 14,
              ),
          ],
        ],
      ),
    );
  }

  Widget _totalCountFooter(int total, SpeciesTheme theme) {
    return Center(
      child: Text(
        '총 $total명 등록',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: DesignTokens.ink3,
        ),
      ),
    );
  }

  Widget _offlineBanner(SpeciesTheme theme) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, color: theme.primaryDeep, size: 18),
              const SizedBox(width: 8),
              Text(
                '서버 연결 실패',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '랭킹 서버에 연결할 수 없습니다.\n'
            '인터넷 연결을 확인하고 새로고침해주세요.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.primaryDeep,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBanner(SpeciesTheme theme, dynamic pet) {
    return AppCard(
      theme: theme,
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: theme.primaryDeep, size: 18),
              const SizedBox(width: 8),
              Text(
                '등록된 펫을 찾지 못했어요',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '온라인 배틀을 한 번이라도 진행하면\n랭킹에 자동 등록됩니다 (배틀 탭 → 온라인 대전).',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.primaryDeep,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoonBanner(SpeciesTheme theme) {
    final label = _tabIndex == 0 ? '친구' : '레벨대';
    return AppCard(
      theme: theme,
      variant: AppCardVariant.tinted,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: theme.primaryDeep, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label 랭킹은 준비 중입니다',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _RowEntry _toRow(RankingEntryDto dto) {
    final isMine = dto.isMine ||
        (_loadedDeviceId != null && dto.deviceId == _loadedDeviceId);
    return _RowEntry(
      rank: dto.rank,
      name: dto.name,
      level: dto.level,
      rp: dto.rp,
      type: dto.evolutionType,
      stage: dto.evolutionStage,
      isMine: isMine,
    );
  }
}

class _RankingData {
  final List<RankingEntryDto> top3;
  final List<RankingEntryDto> surrounding;
  final RankingEntryDto? me;
  final int totalCount;
  final bool isOffline;

  const _RankingData({
    required this.top3,
    required this.surrounding,
    required this.me,
    required this.totalCount,
    required this.isOffline,
  });

  factory _RankingData.offline() => const _RankingData(
        top3: [],
        surrounding: [],
        me: null,
        totalCount: 0,
        isOffline: true,
      );
}

class _Podium extends StatelessWidget {
  final _RowEntry entry;
  final double height;
  final bool crown;
  final SpeciesTheme theme;

  const _Podium({
    required this.entry,
    required this.height,
    required this.theme,
    this.crown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crown)
          Icon(Icons.emoji_events, size: 20, color: theme.primary)
        else
          const SizedBox(height: 20),
        const SizedBox(height: 4),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 2),
          child: _buildPetThumb(entry, 40),
        ),
        const SizedBox(height: 4),
        Text(
          entry.name,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: DesignTokens.ink,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Lv.${entry.level} · ${entry.rp}',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: DesignTokens.ink3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: entry.rank == 1 ? theme.primary : theme.primarySoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: entry.rank == 1 ? Colors.white : theme.primaryDeep,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  final _RowEntry entry;
  final SpeciesTheme theme;

  const _RankingRow({required this.entry, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: entry.isMine ? theme.primarySoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              entry.rank <= 3 ? '${entry.rank}위' : '#${entry.rank}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: entry.isMine ? theme.primaryDeep : DesignTokens.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildPetThumb(entry, 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isMine) ...[
                      const SizedBox(width: 6),
                      AppPill(
                        text: '나',
                        theme: theme,
                        variant: AppPillVariant.solid,
                        fontSize: 9,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${SpeciesTheme.labelFor(entry.type)} · Lv.${entry.level}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.ink3,
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${entry.rp}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: entry.isMine ? theme.primaryDeep : DesignTokens.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const TextSpan(
                  text: ' RP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 펫 썸네일 (서버 응답의 evolutionStage 사용)
Widget _buildPetThumb(_RowEntry entry, double size) {
  final path = getEvolutionImagePath(entry.type, entry.stage);
  if (path == null) {
    return Icon(Icons.pets, size: size, color: DesignTokens.ink3);
  }
  // 각 엔트리의 종별 테마색 도트로 렌더링
  return PixelPetImage(
    assetPath: path,
    width: size,
    height: size,
    dotColor: SpeciesTheme.forType(entry.type).primary,
    fallback: Icon(Icons.pets, size: size, color: DesignTokens.ink3),
  );
}

class _RowEntry {
  final int rank;
  final String name;
  final int level;
  final int rp;
  final EvolutionType? type;
  final int stage;
  final bool isMine;

  const _RowEntry({
    required this.rank,
    required this.name,
    required this.level,
    required this.rp,
    required this.type,
    required this.stage,
    required this.isMine,
  });
}
