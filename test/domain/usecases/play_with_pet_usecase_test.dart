import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';
import 'package:pocketfriend/domain/usecases/play_with_pet_usecase.dart';

Pet _pet({int happiness = 40, bool isDead = false}) => Pet(
      id: 'p',
      name: '테스트',
      hunger: 50,
      happiness: happiness,
      stamina: 50,
      exp: 0,
      level: 5,
      evolutionStage: 2,
      lastUpdated: 0,
      lastStatusDecayUpdated: 0,
      isDead: isDead,
    );

void main() {
  const usecase = PlayWithPetUseCase();

  test('탭 수 × 2 만큼 행복이 오른다', () {
    final r = usecase(_pet(happiness: 40), 5);
    expect(r.happiness, 40 + 5 * PlayWithPetUseCase.happinessPerHit);
  });

  test('행복은 100을 넘지 않는다', () {
    final r = usecase(_pet(happiness: 95), 20);
    expect(r.happiness, 100);
  });

  test('0회 이하는 변화 없음', () {
    final r = usecase(_pet(happiness: 40), 0);
    expect(r.happiness, 40);
  });

  test('사망(긴 잠) 상태에서는 변화 없음', () {
    final r = usecase(_pet(happiness: 40, isDead: true), 10);
    expect(r.happiness, 40);
  });
}
