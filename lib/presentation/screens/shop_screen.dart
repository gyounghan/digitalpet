import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../providers/active_pet_provider.dart';
import '../widgets/app_design.dart';
import '../widgets/mock_ui_widgets.dart';
import '../../core/theme/species_theme.dart';
import '../../domain/entities/pet.dart';
import '../../domain/entities/shop_item.dart';

/// 상점 화면 — 코인으로 소비 아이템을 산다 (벌기→쓰기 루프의 소비처).
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  IconData _iconFor(ShopItemEffect effect) {
    switch (effect) {
      case ShopItemEffect.snack:
        return Icons.cookie;
      case ShopItemEffect.energy:
        return Icons.bolt;
      case ShopItemEffect.battleTicket:
        return Icons.sports_kabaddi;
      case ShopItemEffect.revive:
        return Icons.water_drop;
    }
  }

  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    String petId,
    ShopItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(petNotifierProvider(petId).notifier).purchase(item);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.success ? DesignTokens.ink : DesignTokens.bad,
        content: Text(
          result.success
              ? '${item.name} 구매 완료! (-${item.price} 코인)'
              : (result.failureReason ?? '구매할 수 없어요'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(activePetIdProvider);
    final petAsync = ref.watch(petNotifierProvider(petId));

    return Scaffold(
      backgroundColor: MockUI.screenTop,
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('오류: $e',
                style: const TextStyle(color: DesignTokens.bad)),
          ),
          data: (pet) => _buildContent(context, ref, petId, pet),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, String petId, Pet pet) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: MockScreenTop(
            eyebrow: '상점',
            title: '펫 용품',
            trailing: MockCoinPill('${pet.coins} 코인'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            children: [
              for (final item in shopCatalog)
                _buildItemCard(context, ref, petId, pet, item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, String petId,
      Pet pet, ShopItem item) {
    final affordable = pet.coins >= item.price;
    final reviveBlocked =
        item.effect == ShopItemEffect.revive && !pet.isDead;
    final consumableBlocked =
        item.effect != ShopItemEffect.revive && pet.isDead;
    final enabled = affordable && !reviveBlocked && !consumableBlocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        theme: SpeciesTheme.forType(pet.evolutionType),
        padding: const EdgeInsets.all(14),
        child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MockUI.goldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(item.effect),
                    color: MockUI.lineStrong, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: DesignTokens.ink)),
                    const SizedBox(height: 2),
                    Text(item.description,
                        style: const TextStyle(
                            fontSize: 12, color: DesignTokens.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    enabled ? () => _buy(context, ref, petId, item) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MockUI.lineStrong,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: MockUI.meterTrack,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text('${item.price}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
      ),
    );
  }
}
