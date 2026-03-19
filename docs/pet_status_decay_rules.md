# 펫 수치 감소 규칙

앱 내 펫 상태(포만감/운동/수면) 감소 로직을 일관되게 유지하기 위한 기준 문서입니다.

## 1) 감소 대상 수치

- 포만감(`hunger`)
- 운동(`happiness`)
- 수면(`stamina`)

## 2) 감소 주기 및 감소량

- 감소 주기: **30분**
- 감소량: **각 수치당 1**
- 즉, 30분 경과마다 `hunger/happiness/stamina` 각각 `-1`

## 3) 계산 기준 시간

감소 계산은 일반 업데이트 시간(`lastUpdated`)이 아닌,
**감소 전용 기준 시간(`lastStatusDecayUpdated`)**을 사용한다.

이유:

- 걸음수 반영, 먹이 주기, 이름 변경 등 다른 업데이트가 `lastUpdated`를 갱신하면
  감소 시간이 초기화되어 수치 감소가 멈춘 것처럼 보일 수 있음
- 감소 로직을 독립시키기 위해 전용 기준 시간을 사용

## 4) 감소 계산 방식

1. `elapsedMinutes = now - lastStatusDecayUpdated`(분 단위)
2. `elapsedIntervals = elapsedMinutes ~/ 30`
3. `elapsedIntervals < 1`이면 감소 없음
4. 감소 적용:
   - `hunger -= elapsedIntervals`
   - `happiness -= elapsedIntervals`
   - `stamina -= elapsedIntervals`
5. 각 값은 `0..100` 범위로 clamp
6. 감소가 실제로 적용되면 `lastStatusDecayUpdated = now`로 갱신

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
