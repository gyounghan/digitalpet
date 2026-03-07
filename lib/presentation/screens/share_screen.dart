import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_button.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'home_screen.dart';

/// 공유 화면
/// design 폴더의 Share.tsx를 기반으로 구현
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});
  
  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen>
    with SingleTickerProviderStateMixin {
  bool copied = false;
  late AnimationController _petAnimationController;
  
  @override
  void initState() {
    super.initState();
    _petAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _petAnimationController.dispose();
    super.dispose();
  }
  
  void _handleCopy(String shareUrl) {
    Clipboard.setData(ClipboardData(text: shareUrl));
    setState(() {
      copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          copied = false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petNotifierProvider(HomeScreen.defaultPetId));
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: petAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, stackTrace) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (pet) => _buildShareContent(context, pet),
          ),
        ),
      ),
    );
  }
  
  Widget _buildShareContent(BuildContext context, pet) {
    final shareUrl = 'https://pet.app/luna-${pet.level}';
    final petName = 'Luna'; // TODO: Pet 엔티티에 name 필드 추가 필요
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // 헤더
          Column(
            children: [
              Text(
                AppStrings.shareYourPet,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.shareSubtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 프로필 카드
          GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Pet Display
                AnimatedBuilder(
                  animation: _petAnimationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        -8 * _petAnimationController.value,
                      ),
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '🌟',
                            style: TextStyle(fontSize: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.level} ${pet.level} • ${AppStrings.moodHappy}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem('${pet.happiness}%', AppStrings.shareHappy),
                    Container(
                      width: 1,
                      height: 24,
                      color: AppColors.glassBorder,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem('${pet.hunger}%', AppStrings.shareFed),
                    Container(
                      width: 1,
                      height: 24,
                      color: AppColors.glassBorder,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem('${pet.stamina}%', AppStrings.shareEnergy),
                  ],
                ),
                const SizedBox(height: 32),
                // QR Code (간단한 버전 - 실제로는 qr_flutter 패키지 사용 권장)
                Container(
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 128,
                      color: AppColors.backgroundDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Share URL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shareUrl,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _handleCopy(shareUrl),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.glassBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            copied ? Icons.check : Icons.copy,
                            color: copied
                                ? AppColors.success
                                : AppColors.textTertiary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Share Actions
          Column(
            children: [
              PetButton(
                variant: PetButtonVariant.primary,
                icon: Icons.share,
                onPressed: () {
                  // TODO: 공유 기능 구현
                },
                child: Text(AppStrings.shareToFriends),
              ),
              const SizedBox(height: 12),
              PetButton(
                variant: PetButtonVariant.secondary,
                icon: Icons.download,
                onPressed: () {
                  // TODO: 다운로드 기능 구현
                },
                child: Text(AppStrings.downloadCard),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              AppStrings.shareInfo,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.accentCyan,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
