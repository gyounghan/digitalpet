# Git Workflow 및 커밋 규격

PocketFriend 프로젝트의 Git Flow 및 커밋 메시지 규격을 정의합니다.

## 🌿 Git Flow (브랜치 전략)

### 브랜치 구조

```
main (production-ready)
  ↑
  └─ develop (개발 진행 중)
       ↑
       ├─ feature/기능명 (새로운 기능)
       ├─ bugfix/버그명 (버그 수정)
       └─ hotfix/긴급사항 (긴급 수정)
```

### 각 브랜치의 역할

| 브랜치 | 목적 | 출발점 | 병합 대상 | 예시 |
|--------|------|--------|---------|------|
| **main** | 배포 가능한 최종 코드 | - | - | (언제나 배포 가능 상태) |
| **develop** | 개발 진행 중인 코드 | main | main | (다음 릴리스를 위한 통합) |
| **feature/\*** | 새로운 기능 개발 | develop | develop | feature/mood-system, feature/battle-ui |
| **bugfix/\*** | 버그 수정 | develop | develop | bugfix/health-connect-auth, bugfix/mood-calc |
| **hotfix/\*** | 긴급 수정 (프로덕션) | main | main + develop | hotfix/critical-crash |

---

## 📝 브랜치 명명 규칙

### Feature 브랜치
```
feature/{기능명 또는 이슈번호}

예:
✓ feature/mood-system
✓ feature/pet-evolution
✓ feature/battle-screen
✓ feature/health-connect
✓ feature/widget-sync
```

### Bugfix 브랜치
```
bugfix/{버그명 또는 이슈번호}

예:
✓ bugfix/mood-calculation
✓ bugfix/health-permission
✓ bugfix/hive-migration
✓ bugfix/widget-update-delay
```

### Hotfix 브랜치
```
hotfix/{긴급-이슈명}

예:
✓ hotfix/critical-crash-startup
✓ hotfix/data-loss-issue
```

---

## 💬 커밋 메시지 규격

### 형식

```
<타입>(<범위>): <제목> (#이슈번호 선택)

<본문 - 선택>

<푸터 - 선택>
```

### 타입 (Type)

| 타입 | 설명 | 예시 |
|------|------|------|
| **feat** | 새로운 기능 | `feat(pet): 펫 mood 계산 로직 추가` |
| **fix** | 버그 수정 | `fix(health): Health Connect 권한 오류 수정` |
| **docs** | 문서 | `docs: GIT_WORKFLOW.md 추가` |
| **style** | 코드 스타일 (포맷팅, 세미콜론 등) | `style: Dart 포맷팅 정렬` |
| **refactor** | 코드 구조 개선 (기능 변경 없음) | `refactor(domain): UseCase 추상화 개선` |
| **test** | 테스트 추가/수정 | `test(pet): mood 계산 테스트 케이스 추가` |
| **chore** | 빌드, 의존성, 설정 변경 | `chore: Flutter 3.0으로 업그레이드` |
| **ci** | CI/CD 설정 | `ci: GitHub Actions 워크플로우 추가` |
| **perf** | 성능 개선 | `perf(widget): 렌더링 최적화` |

### 범위 (Scope)

프로젝트 영역을 명시 (선택사항)

```
feat(pet): ...                    # Pet 엔티티 관련
feat(domain): ...                 # Domain 레이어 전체
feat(presentation): ...           # Presentation 레이어
feat(data): ...                   # Data 레이어
feat(android): ...                # Android 네이티브 코드
feat(tests): ...                  # 테스트
feat(docs): ...                   # 문서
```

### 제목 (Subject)

- **명령형** 사용: "수정했다" (X) → "수정" (O)
- **50자 이내** (권장)
- 마침표 없음
- 한국어 또는 영어 사용 가능

**예:**
```
✓ feat(pet): 기분 상태 8단계 우선순위 로직 추가
✓ fix(health): Health Connect 권한 요청 오류 해결
✓ refactor(domain): Repository 인터페이스 정리
✗ Fixed bug in mood calculation (너무 길고 일반적)
✗ Update. (너무 짧고 불분명)
```

### 본문 (Body) - 선택사항

상세 설명이 필요할 때만 작성

```
- 변경 이유
- 변경 내용
- 영향 범위

예:
Pet mood 계산 로직을 8단계 우선순위 시스템으로 개선

기존:
- 단순 20/30 임계값 기반

개선:
- 위기(≤10) → 경고(≤25) → 수면신호(시간대) → 감정위기 → 긍정 상태 → 부분긍정 → 불균형 → 기본값
- 밤시간대(22-6시) 수면 신호 완화 (stamina ≤ 60)
- 활동 후 만족감 상태 추가

영향:
- Widget의 mood 표시 일치
- 사용자 피드백 개선
```

### 푸터 (Footer) - 선택사항

```
Closes #123
Relates to #456
Co-Authored-By: 사용자명 <이메일>
```

---

## 📋 커밋 메시지 예시

### 기능 추가

```
feat(pet): 진화 시스템 구현

- 레벨 5, 10에서 진화 단계 증가
- active/restful/balanced 3가지 진화 방향
- 활동 패턴(걸음수, 운동, 미사용 시간) 기반 방향 결정
- EvolvePetUseCase 추가
- 진화 화면 UI 추가

Closes #45
```

### 버그 수정

```
fix(health): Health Connect 권한 요청 오류 해결

Health 13.x 버전에서 requestAuthorization() 실패 문제
- AndroidManifest.xml에 ACTION_SHOW_PERMISSIONS_RATIONALE intent-filter 추가
- HealthDataSource._initialized를 static으로 변경 (인스턴스 공유)
- 권한 요청 시점 최적화 (main.dart에서 조기 요청)

Closes #12
```

### 테스트 추가

```
test(pet): mood 계산 로직 테스트 케이스 추가

- 8단계 우선순위 모두 테스트
- 경계값 테스트 (10, 25, 35, 60, 75, 80, 85, 90)
- 시간대 반영 테스트 (밤시간 stamina ≤ 60)
- 커버리지 85% 달성
```

### 문서

```
docs: GIT_WORKFLOW.md 및 커밋 규격 정의

- Git Flow 브랜치 전략 (main/develop/feature/bugfix/hotfix)
- Conventional Commits 기반 메시지 규격
- 브랜치 명명 규칙
- 예시 및 체크리스트
```

### 리팩토링

```
refactor(domain): UseCase 추상화 구조 개선

기존:
- UseCase별 상태 관리 로직 중복

개선:
- BaseUseCase 추상 클래스 도입
- 공통 로직 추출
- 각 UseCase는 비즈니스 로직에만 집중

영향: 코드 유지보수성 ↑, 중복 코드 ↓
```

---

## 🔄 작업 흐름

### 1️⃣ 새로운 기능 시작

```bash
# develop에서 최신 상태로 업데이트
git checkout develop
git pull origin develop

# feature 브랜치 생성
git checkout -b feature/기능명

# 예:
git checkout -b feature/mood-system
```

### 2️⃣ 개발 진행

```bash
# 변경 사항 확인
git status

# 코드 분석 (CLAUDE.md 규칙)
flutter analyze

# 커밋
git add .
git commit -m "feat(pet): mood 계산 로직 추가"
```

### 3️⃣ 여러 커밋이 필요한 경우

```bash
# 1번 커밋
git add lib/domain/entities/pet.dart
git commit -m "feat(pet): mood 8단계 우선순위 로직"

# 2번 커밋
git add test/domain/entities/pet_test.dart
git commit -m "test(pet): mood 테스트 케이스 추가"

# 3번 커밋
git add lib/presentation/widgets/pet_image_animation.dart
git commit -m "refactor(presentation): 펫 애니메이션 구조 정리"
```

### 4️⃣ Pull Request (develop에 병합)

```bash
# develop에서 최신 상태 확인
git pull origin develop

# feature 브랜치를 develop으로 병합
git checkout develop
git pull origin develop
git merge feature/기능명
git push origin develop

# 로컬 feature 브랜치 정리 (선택)
git branch -d feature/기능명
```

### 5️⃣ 배포 (main으로 릴리스)

```bash
# develop의 변경사항이 테스트되고 안정적일 때
git checkout main
git pull origin main
git merge develop
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main --tags
```

---

## ❌ 주의사항

### 절대 하면 안 되는 것

```bash
# ❌ main에 직접 커밋
git commit -m "..." (on main)

# ❌ 여러 기능을 한 브랜치에서 개발
feature/login-and-payment-system (X)

# ❌ develop 없이 master에서만 작업
(main과 feature만 사용하는 경우)

# ❌ 강제 푸시 (git push --force)
git push --force origin develop (X)

# ❌ 의미 없는 커밋 메시지
"Update" "Fix" "asdf" (X)
```

### 해야 할 것

```bash
# ✓ 기능별 브랜치 분리
feature/mood-system
feature/battle-ui
feature/health-connect

# ✓ 명확한 커밋 메시지
feat(pet): mood 8단계 우선순위 로직 추가

# ✓ develop으로 먼저 병합
feature → develop → main

# ✓ PR (Pull Request) 리뷰
feature 브랜치 → develop PR
자신의 코드 리뷰 → 병합
```

---

## 📊 커밋 메시지 체크리스트

커밋하기 전에 확인하세요:

```
[ ] 커밋 메시지 형식: <타입>(<범위>): <제목>
[ ] 타입 올바름: feat, fix, docs, style, refactor, test, chore, ci, perf
[ ] 제목 50자 이내
[ ] 제목 명령형 사용 (수정했다 X → 수정 O)
[ ] 제목 마침표 없음
[ ] 본문 필요하면 추가 (한 줄 공백으로 분리)
[ ] 푸터 필요하면 추가 (Closes #123 등)
[ ] 올바른 브랜치 (develop 기반, feature/bugfix 사용)
[ ] flutter analyze 통과
[ ] 관련 테스트 추가/수정됨
```

---

## 🔗 참고

- Conventional Commits: https://www.conventionalcommits.org/
- Git Flow: https://nvie.com/posts/a-successful-git-branching-model/
- Semantic Versioning: https://semver.org/

---

**최종 업데이트**: 2026-03-21
