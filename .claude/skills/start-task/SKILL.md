---
name: start-task
description: 작업 시작 - 브랜치 자동 검증, 생성/이동, 작업 진행, 종료 후 자동 커밋 (자동 감지)
disable-model-invocation: false
---

# 작업 시작 및 자동 브랜치 관리

새로운 작업(기능, 버그 수정)을 시작할 때 사용합니다.

## 🔄 완전 자동 브랜치 관리 흐름

```
1️⃣ 브랜치 검증
   현재 브랜치 확인 (git branch)
   ↓
2️⃣ 잘못된 브랜치 처리
   master / main 에 있으면?
   ├─ YES → develop으로 자동 이동
   └─ NO → develop인가? → feature/bugfix에서? → 진행
   ↓
3️⃣ develop 최신화
   develop 존재 확인
   ├─ NO → develop 생성 (현재 커밋 base)
   └─ YES → git pull origin develop
   ↓
4️⃣ 작업 브랜치 생성
   /start-task feature 기능명
   → feature/기능명 생성 및 체크아웃
   ↓
5️⃣ 상태 보고
   현재 브랜치: feature/기능명 (ON)
   develop 동기화: 최신 상태
   ↓
6️⃣ 작업 진행
   Claude Code가 사용자의 지시를 따라 작업
   ↓
7️⃣ 자동 커밋 (작업 완료 후)
   git add .
   feat(scope): 커밋 메시지 자동 생성
   git commit
```

### 자동 브랜치 검증 상세 로직

#### 1️⃣ 현재 상태 확인
```bash
git branch          # 현재 브랜치 확인
git status          # 작업 상태 확인
git log -1 --oneline # 최근 커밋 확인
```

#### 2️⃣ 브랜치 검증 및 자동 교정
```
if (현재 브랜치 == "master" || "main") {
  ✓ git checkout develop  // develop으로 자동 이동
  ✓ 상태: develop (ON)
}

if (develop 브랜치 없음) {
  ✓ git branch develop    // 신규 생성
}

if (브랜치 == "develop") {
  ✓ git pull origin develop  // 최신 상태 동기화
}

if (feature/xxx 또는 bugfix/xxx 에서 작업 중) {
  ✓ 계속 진행 (이미 올바른 브랜치)
}
```

#### 3️⃣ 작업 브랜치 생성
```
입력: /start-task feature 기능명

git checkout develop
git pull origin develop
git checkout -b feature/기능명  # 또는 bugfix/버그명, hotfix/긴급-사항

예:
- /start-task feature mood-system → feature/mood-system 생성
- /start-task bugfix health-auth → bugfix/health-auth 생성
- /start-task hotfix critical-crash → hotfix/critical-crash 생성
```

#### 4️⃣ 작업 진행 (Claude Code)
```
현재 브랜치: feature/기능명 (ON)

✓ 코드 작성
✓ flutter analyze 실행 (CLAUDE.md 규칙)
✓ 테스트 작성 (필요시)
✓ 모든 변경 완료

현재 브랜치: feature/기능명 (유지)
```

#### 5️⃣ 자동 커밋 (작업 완료 후)
```
변경사항 감지
  ↓
Conventional Commits 규격 자동 적용
  ├─ feat(scope): 기능 추가
  ├─ fix(scope): 버그 수정
  ├─ test(scope): 테스트 추가
  ├─ refactor(scope): 코드 정리
  └─ docs: 문서
  ↓
git add .
git commit -m "feat(pet): mood 시스템 개선"
  ↓
커밋 완료 보고
```

## 사용 방법

### 예 1: 기능 추가 시작

```
당신: /start-task feature 기분 시스템 개선

Claude Code:
✓ 현재 브랜치: master → develop으로 이동
✓ 브랜치 생성: feature/mood-system-improve
✓ 브랜치 전환: feature/mood-system-improve (on)
✓ develop 최신 상태로 동기화
✓ 작업 시작 (다음 지시 대기)
```

### 예 2: 버그 수정

```
당신: /start-task bugfix Health Connect 권한 오류

Claude Code:
✓ 현재 브랜치 확인: feature/mood-system
✓ develop으로 이동
✓ 최신 상태 동기화: git pull origin develop
✓ 브랜치 생성: bugfix/health-connect-auth
✓ 브랜치 전환: bugfix/health-connect-auth (on)
✓ 작업 시작
```

### 예 3: 긴급 수정

```
당신: /start-task hotfix 앱 크래시 긴급 수정

Claude Code:
✓ 현재 브랜치 확인
✓ main으로 이동 (hotfix는 main에서 분기)
✓ 최신 상태 동기화
✓ 브랜치 생성: hotfix/app-crash
✓ 브랜치 전환: hotfix/app-crash (on)
✓ 작업 시작
```

## 자동 커밋

작업 완료 후 커밋이 자동으로 진행됩니다.

### 커밋 메시지 자동 생성

```
예 1: 기능 추가
당신: /start-task feature mood 시스템 개선
... (작업 진행)
작업 완료 후:
  feat(pet): mood 8단계 우선순위 시스템 개선

예 2: 버그 수정
당신: /start-task bugfix Health Connect 권한
... (작업 진행)
작업 완료 후:
  fix(health): Health Connect 권한 요청 오류 해결

예 3: 테스트 추가
당신: /start-task test pet mood 테스트
... (작업 진행)
작업 완료 후:
  test(pet): mood 계산 로직 테스트 케이스 추가
```

## 작업 중 커맨드

작업 중에 다음을 사용할 수 있습니다:

```bash
# 현재 브랜치 확인
git branch -v

# 변경사항 확인
git status
git diff

# 작업 보관 (브랜치 전환 필요할 때)
git stash
git stash pop
```

## 커밋 후 관리

### PR (Pull Request) 생성
```
작업 완료 및 커밋 후:
당신: /pr-create

Claude Code:
✓ feature 브랜치 → develop으로 PR 생성
✓ PR 제목, 설명 자동 생성
✓ PR URL 반환
```

### 브랜치 정리
```
PR 병합 완료 후:
당신: git branch -d feature/기능명

또는 원격 브랜치 정리:
당신: git push origin --delete feature/기능명
```

## ⚠️ 주의사항

### 절대 하면 안 됨
```
❌ main에서 직접 작업
❌ 여러 기능을 한 브랜치에서 개발
❌ develop 동기화 없이 작업 시작
❌ 커밋 메시지 생략
```

### 해야 할 것
```
✓ 기능/버그별 브랜치 분리
✓ develop에서 최신 동기화
✓ 작업 후 flutter analyze 통과
✓ 명확한 커밋 메시지 사용
```

## 브랜치 구조 참고

```
main (배포 가능한 최종 코드)
  ↑
  └─ develop (개발 진행 중)
       ↑
       ├─ feature/기능명
       ├─ bugfix/버그명
       └─ hotfix/긴급 (main에서 분기)
```

## 추가 정보

자세한 사항은 **[GIT_WORKFLOW.md](../../GIT_WORKFLOW.md)** 참고

---

**팁**: 작업 시작 전에 항상 `/start-task`를 사용해서 올바른 브랜치 환경을 자동으로 설정하세요.
