import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pet_provider.dart';
import '../widgets/status_bar.dart';
import '../../core/utils/evolution_helper.dart';

/// 홈 화면
/// Pet의 상태를 표시하고 Feed/Play/Sleep 액션을 수행할 수 있는 메인 화면
class HomeScreen extends ConsumerWidget {
  /// 기본 Pet ID
  /// 실제 앱에서는 사용자가 선택한 Pet ID를 사용
  static const String defaultPetId = 'default-pet';
  
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pet 상태를 관리하는 Notifier 가져오기
    final petAsync = ref.watch(petNotifierProvider(defaultPetId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pet'),
        centerTitle: true,
      ),
      body: petAsync.when(
        // 로딩 중
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        // 에러 발생
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(petNotifierProvider(defaultPetId).notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        // 데이터 로드 완료
        data: (pet) => _buildPetContent(context, ref, pet),
      ),
    );
  }
  
  /// Pet 콘텐츠 빌드
  /// 
  /// Pet 정보와 상태바, 액션 버튼을 표시
  Widget _buildPetContent(BuildContext context, WidgetRef ref, pet) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // Pet 이미지 (진화 단계에 따라 변경)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: EvolutionHelper.getEvolutionBackgroundColor(pet.evolutionStage),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: EvolutionHelper.getEvolutionColor(pet.evolutionStage),
                width: 3,
              ),
            ),
            child: Icon(
              EvolutionHelper.getEvolutionIcon(pet.evolutionStage),
              size: 100,
              color: EvolutionHelper.getEvolutionColor(pet.evolutionStage),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 진화 단계 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: EvolutionHelper.getEvolutionColor(pet.evolutionStage).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: EvolutionHelper.getEvolutionColor(pet.evolutionStage),
                width: 2,
              ),
            ),
            child: Text(
              EvolutionHelper.getEvolutionStageName(pet.evolutionStage),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EvolutionHelper.getEvolutionColor(pet.evolutionStage),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Pet 정보
          Text(
            'Level ${pet.level}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 상태바들
          StatusBar(
            label: 'Hunger',
            value: pet.hunger,
            color: Colors.orange,
          ),
          
          StatusBar(
            label: 'Happiness',
            value: pet.happiness,
            color: Colors.pink,
          ),
          
          StatusBar(
            label: 'Stamina',
            value: pet.stamina,
            color: Colors.blue,
          ),
          
          const SizedBox(height: 32),
          
          // 액션 버튼들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Feed 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(petNotifierProvider(defaultPetId).notifier).feed();
                  },
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Feed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                
                // Play 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(petNotifierProvider(defaultPetId).notifier).play();
                  },
                  icon: const Icon(Icons.sports_esports),
                  label: const Text('Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                
                // Sleep 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(petNotifierProvider(defaultPetId).notifier).sleep();
                  },
                  icon: const Icon(Icons.bedtime),
                  label: const Text('Sleep'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
