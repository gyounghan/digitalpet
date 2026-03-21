---
name: commit-work
description: 작업 완료 후 GIT_WORKFLOW.md 규격에 맞게 커밋 메시지 작성 및 커밋
disable-model-invocation: false
---

# 커밋 자동화

작업 완료 후 Conventional Commits 규격에 맞게 자동으로 커밋합니다.

## 자동 동작

```
변경사항 감지
  ↓
파일 변경 내용 분석
  ↓
커밋 타입 판단
  ├─ 기능 추가 → feat
  ├─ 버그 수정 → fix
  ├─ 테스트 → test
  ├─ 리팩토링 → refactor
  ├─ 문서 → docs
  └─ 기타 → chore
  ↓
커밋 메시지 자동 생성
  ├─ <타입>(<범위>): <제목>
  ├─ 본문 (필요시)
  └─ 푸터 (이슈 번호 등)
  ↓
git add .
  ↓
git commit -m "..."
  ↓
커밋 완료 및 결과 보고
```

## 사용 방법

### 방법 1: 자동 감지 (권장)

작업 완료 후 자동으로 커밋됩니다:

```
당신: 펫 mood 시스템 개선 완료했어

Claude Code:
✓ 변경사항 분석
✓ 커밋 메시지 생성:
  feat(pet): mood 8단계 우선순위 시스템 개선

  - 기존 단순 임계값 → 8단계 우선순위 로직
  - 밤시간대(22-6시) 수면 신호 완화
  - 활동 후 만족감 상태 추가

✓ git add . && git commit
✓ 커밋 완료
```

### 방법 2: 수동 지정

```
당신: /commit-work

Claude Code:
다음 정보를 입력하세요:
1. 작업 타입: feat/fix/test/refactor/docs/chore
2. 범위 (scope): pet, health, widget 등
3. 제목: 50자 이내
4. 본문: (선택)
5. 이슈 번호: (선택) Closes #123
```

### 방법 3: 명시적 메시지

```
당신: /commit-work feat(health) Health Connect 권한 요청 오류 해결

Claude Code:
✓ 커밋 메시지 형식 검증
✓ git commit -m "fix(health): Health Connect 권한 요청 오류 해결"
✓ 커밋 완료
```

## 커밋 타입 가이드

### feat — 새로운 기능
```
당신: mood 계산 로직에 8단계 우선순위 추가 완료

✓ 자동 감지: feat(pet)
✓ 커밋: feat(pet): mood 8단계 우선순위 로직 추가
```

### fix — 버그 수정
```
당신: Health Connect 권한 오류 고쳤어

✓ 자동 감지: fix(health)
✓ 커밋: fix(health): Health Connect 권한 요청 오류 해결
```

### test — 테스트 추가
```
당신: Pet.mood 테스트 케이스 작성 완료

✓ 자동 감지: test(pet)
✓ 커밋: test(pet): mood 계산 로직 테스트 케이스 추가
```

### refactor — 코드 구조 개선
```
당신: UseCase 추상화 구조 정리했어

✓ 자동 감지: refactor(domain)
✓ 커밋: refactor(domain): UseCase 추상 클래스 구조 정리
```

### docs — 문서
```
당신: GIT_WORKFLOW.md 작성 완료

✓ 자동 감지: docs
✓ 커밋: docs: GIT_WORKFLOW.md 및 커밋 규격 정의
```

### chore — 빌드, 의존성 등
```
당신: Flutter 버전 업그레이드했어

✓ 자동 감지: chore
✓ 커밋: chore: Flutter 3.0으로 업그레이드
```

## 커밋 메시지 형식

### 기본 형식
```
<타입>(<범위>): <제목>

<본문>

<푸터>
```

### 예시 1: 기능 추가
```
feat(pet): mood 8단계 우선순위 로직 추가

기존:
- 단순 20/30 임계값 기반

개선:
- 위기(≤10) → 경고(≤25) → 수면신호 → 감정위기 → 긍정상태 → 부분긍정 → 불균형 → 기본값
- 밤시간대(22-6시) 수면 신호 완화 (stamina ≤ 60)
- 활동 후 만족감 상태 추가 (happiness ≥ 75)

영향:
- Widget과 앱 mood 표시 일치
- 사용자 경험 개선
```

### 예시 2: 버그 수정
```
fix(health): Health Connect 권한 요청 오류 해결

원인:
- health 13.x 버전의 requestAuthorization() 실패
- AndroidManifest에 필수 intent-filter 누락

해결:
- AndroidManifest.xml에 ACTION_SHOW_PERMISSIONS_RATIONALE 추가
- HealthDataSource._initialized를 static으로 변경
- 권한 요청 시점 최적화

테스트:
- 실기기 Android 13, 14, 15 테스트 완료
```

### 예시 3: 테스트
```
test(pet): mood 계산 로직 테스트 케이스 추가

테스트 항목:
- 8단계 우선순위 모두 (happy, hungry, sleepy, etc)
- 경계값 (10, 25, 35, 60, 75, 80, 85, 90)
- 시간대 반영 (밤시간 stamina ≤ 60)
- 복합 조건 (불균형 감지)

커버리지: 85% 달성
```

## 커밋 전 체크리스트

자동으로 확인됩니다:

```
[ ] 변경사항 확인: git status
[ ] 코드 분석: flutter analyze 통과
[ ] 테스트: 관련 테스트 통과 (필요시)
[ ] 브랜치: develop 또는 feature/bugfix 브랜치 (hotfix는 main)
[ ] 메시지: Conventional Commits 형식
[ ] 제목: 50자 이내, 마침표 없음, 명령형
[ ] 파일: 모든 변경사항 포함
```

## 성공 메시지

```
✓ Commit successful!

Branch: feature/mood-system
Commit: a1b2c3d4
Message: feat(pet): mood 8단계 우선순위 로직 추가

Next steps:
1. /pr-create (develop에 PR 생성)
2. 코드 리뷰 및 피드백
3. 병합 후 배포 준비
```

## 실패 시 대응

### 커밋 메시지 형식 오류
```
✗ Invalid commit message format
✗ Expected: <type>(<scope>): <subject>

수정 후 재시도:
/commit-work
```

### git 오류
```
✗ Git error: 파일 충돌

대응:
1. 충돌 파일 확인: git status
2. 충돌 해결
3. git add . && git commit --continue
```

### 단계별 커밋 필요 시
```
당신: /commit-work step 1 feat(pet) mood 로직

당신: /commit-work step 2 test(pet) mood 테스트

당신: /commit-work step 3 docs mood 시스템 문서

→ 각각 독립적인 커밋으로 생성
```

## 팁

```
✓ 작은 커밋: 한 번에 한 기능/버그만 (리뷰 용이)
✓ 명확한 메시지: "Update" 같은 일반적 표현 피하기
✓ 본문 활용: 무엇을 했는지 + 왜 했는지
✓ 이슈 링크: Closes #123 형식으로 PR과 이슈 연결
```

---

**자동 감지 스킬 활성화**: `disable-model-invocation: false`
→ 작업 완료 후 자동으로 적절한 커밋이 생성될 수 있습니다.

**수동 제어 필요시**: `/commit-work` 직접 호출
