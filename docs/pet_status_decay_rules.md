# 펫 수치 감소 규칙

앱 내 펫 상태(포만감/운동/수면) 감소 로직을 일관되게 유지하기 위한 기준 문서입니다.

## 1) 감소 대상 수치

- 포만감(`hunger`)
- 운동(`happiness`)
- 수면(`stamina`)

## 2) 감소 주기 및 감소량

(`UpdatePetStateUseCase` 기준 — 코드가 원본, 이 표는 요약)

| 수치 | 감소 간격 | 낮(06~22시) | 밤(22~06시) |
|------|----------|-------------|-------------|
| `hunger` (포만감) | 60분 | -2 | -1 (절반, 최소 1) |
| `happiness` (운동) | 60분 | -1 | 감소 정지 |
| `stamina` (수면) | 40분 | -1 | 감소 정지 |

추가 배율:

- **위기 가속**: 세 수치 중 2개 이상이 10 이하면 ×2.0, 20 이하면 ×1.5
- **종별 감소 배율**: `SpeciesGrowthConfig`의 decay 배율이 곱해짐
  (진화 전 `evolutionType == null`이면 전부 ×1.0)
- 최소 갱신 간격: 10분 (그 미만 경과 시 계산 생략)

## 3) 계산 기준 시간

감소 계산은 일반 업데이트 시간(`lastUpdated`)이 아닌,
**감소 전용 기준 시간(`lastStatusDecayUpdated`)**을 사용한다.

이유:

- 걸음수 반영, 먹이 주기, 이름 변경 등 다른 업데이트가 `lastUpdated`를 갱신하면
  감소 시간이 초기화되어 수치 감소가 멈춘 것처럼 보일 수 있음
- 감소 로직을 독립시키기 위해 전용 기준 시간을 사용

## 4) 감소 계산 방식

1. `elapsedMinutes = now - lastStatusDecayUpdated`(분 단위), 10분 미만이면 생략
2. 경과 구간을 낮/밤(22~06시)으로 분 단위 분리 (`calculateDaytimeMinutes`)
3. 수치별 감소:
   - `hunger -= (낮분 ~/ 60) * 2 + (밤분 ~/ 60) * 1` (밤은 절반, 최소 1)
   - `happiness -= 낮분 ~/ 60` (밤 정지)
   - `stamina -= 낮분 ~/ 40` (밤 정지)
4. 위기 가속·종별 감소 배율을 곱한 뒤 `0..100` 범위로 clamp
5. 감소가 실제로 적용되면 `lastStatusDecayUpdated = now`로 갱신

## 5) 다른 액션과의 관계

- Feed/대체 급식/수면/운동/걸음수 반영/이름 변경은
  `lastStatusDecayUpdated`를 수정하지 않는다.
- 해당 액션은 기존처럼 `lastUpdated`만 갱신할 수 있다.

## 6) 구현 체크리스트

- [ ] `Pet` 엔티티에 `lastStatusDecayUpdated` 필드 존재
- [ ] `PetModel`/Hive Adapter에 필드 저장/복원 구현
- [ ] 기본 펫 생성 시 `lastStatusDecayUpdated` 초기화
- [ ] `UpdatePetStateUseCase`가 `lastStatusDecayUpdated` 기반으로 계산
- [ ] 감소 로직 외 코드에서 `lastStatusDecayUpdated`를 임의 변경하지 않음
