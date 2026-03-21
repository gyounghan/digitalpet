---
name: test-complete
description: flutter test 실행 후 결과 분석, 커버리지 확인, 테스트 미작성 영역 식별
disable-model-invocation: false
---

# Flutter 테스트 실행 및 분석

`flutter test`를 실행하고 테스트 결과를 체계적으로 분석합니다.

## 실행 과정

1. **테스트 실행**
   ```bash
   flutter test
   ```
   - 모든 테스트 실행
   - 성공/실패 결과 수집

2. **결과 분석**
   - 통과한 테스트 개수
   - 실패한 테스트 개수
   - 실패 원인 분석

3. **커버리지 리포트** (선택)
   ```bash
   flutter test --coverage
   ```
   - 각 파일별 커버리지 비율
   - 테스트되지 않은 영역 식별

4. **개선 방안 제시**
   - 미작성 테스트 케이스 추천
   - 실패 원인 및 수정 방법
   - 테스트 작성 우선순위

## 사용 예

```
당신: 테스트 실행해줘
당신: 모든 테스트 돌려봐
당신: 커버리지 포함해서 테스트해줘

Claude Code:
✓ flutter test 실행
✓ 결과 분석
✓ 실패 사항 정리
✓ 개선 방안 제시
```

## 출력 형식

```
# 🧪 Flutter 테스트 결과

## ✅ 테스트 요약
- 통과: N개 ✓
- 실패: N개 ✗
- 스킵: N개 ⏭️
- 총 실행 시간: Xs

## 📊 카테고리별 결과
### Domain Entities
  ✓ Pet.mood 계산 (8/8 통과)
  ✓ Pet.copyWith (5/5 통과)
  ✗ DailyGoals.totalScore (2/3 실패)

### Domain UseCases
  ✓ FeedPetUseCase (4/4 통과)
  ✓ EvolvePetUseCase (6/6 통과)
  ✗ BattleWithActivityUseCase (2/5 실패)

### Presentation
  ⏭️ petNotifierProvider (미작성)

## ❌ 실패한 테스트 (상세)

### 1. DailyGoals.totalScore (test/domain/entities/daily_goals_test.dart:45)
```
예상: 10점
실제: 9점
원인: 계산 로직 버그
```
해결: `totalScore` 메서드의 가중치 재검토

### 2. BattleWithActivityUseCase (test/domain/usecases/...)
```
실패 원인: Mock repository의 응답 지연
해결: when(...).thenAnswer()에 Future.delayed 추가
```

## 📈 커버리지 분석 (--coverage)

### 높은 커버리지 (>80%)
- ✓ Pet entity — 85%
- ✓ FeedPetUseCase — 90%
- ✓ PlayPetUseCase — 92%

### 중간 커버리지 (50-80%)
- 🟡 EvolvePetUseCase — 68%
- 🟡 UpdatePetStateUseCase — 72%

### 낮은 커버리지 (<50%)
- 🔴 BattleWithActivityUseCase — 45% (Mock 설정 미흡)
- 🔴 Presentation Providers — 20% (UI 테스트 필요)

### 미테스트 영역
- lib/presentation/widgets/ — 0% (위젯 테스트 별도 필요)
- lib/data/services/ — 10% (통합 테스트로 대체)

## 🎯 다음 테스트 작성 권장 사항

### 우선순위 1 (높은 ROI)
- [ ] DailyGoals.totalScore 버그 수정 + 테스트
- [ ] BattleWithActivityUseCase Mock 개선
- [ ] CalculateDailyGoalsScoreUseCase 정적 메서드 (getFeedGoalCount, etc)

### 우선순위 2
- [ ] Riverpod petNotifierProvider 테스트
- [ ] UpdatePetStateUseCase 시간 기반 로직 (fakeAsync 사용)
- [ ] Alternative*UseCase 일일 한도 테스트

### 우선순위 3
- [ ] Presentation 위젯 테스트 (Widget Test 사용)
- [ ] 통합 테스트 (여러 UseCase 조합)

## 커버리지 리포트 보기

```bash
# HTML 리포트 생성
genhtml coverage/lcov.info -o coverage/html

# 브라우저에서 열기
open coverage/html/index.html
```

## 추가 옵션

- `/test-complete --coverage` — 커버리지 포함
- `/test-complete --watch` — 파일 변경 감지해서 자동 재실행
- `/test-complete test/domain` — 특정 디렉토리만 테스트
- `/test-complete --fix` — 실패한 테스트 수정 제안

## 테스트 파일 작성 템플릿

```dart
// test/domain/entities/pet_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/domain/entities/pet.dart';

void main() {
  group('Pet Entity', () {
    test('hunger <= 10이면 hungry 반환', () {
      final pet = Pet(
        id: 'test',
        hunger: 10,
        happiness: 100,
        stamina: 100,
        level: 1,
        exp: 0,
        evolutionStage: 1,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        lastStatusDecayUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      expect(pet.mood, PetMood.hungry);
    });
  });
}
```

---

**팁**: 테스트는 배포 전에 최소 70% 이상의 커버리지 목표를 권장합니다.
