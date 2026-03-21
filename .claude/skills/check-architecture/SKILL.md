---
name: check-architecture
description: Clean Architecture 의존성 규칙 검증. 각 레이어가 올바른 범위 내에서만 import하는지 확인
disable-model-invocation: true
---

# Clean Architecture 검증

PocketFriend의 계층 구조가 올바르게 유지되는지 검증합니다.

## 아키텍처 규칙

```
Dependency Flow (의존 방향):
Presentation → Domain ← Data
             (양방향 금지!)

레이어별 책임:
┌─ Presentation (UI)
│  ├─ screens/ — 화면 구성
│  ├─ widgets/ — UI 컴포넌트
│  └─ providers/ — Riverpod 상태 관리
│
├─ Domain (비즈니스 로직)
│  ├─ entities/ — 순수 Dart 모델
│  ├─ repositories/ — 추상 인터페이스만
│  └─ usecases/ — 비즈니스 로직
│
└─ Data (구현)
   ├─ models/ — Hive 모델 (entities 확장만 가능)
   ├─ datasources/ — 실제 데이터 소스
   ├─ repositories/ — repository 구현체
   └─ services/ — 시스템 서비스
```

## 검증 항목

### ✅ Presentation 레이어
- [ ] `lib/presentation/**/*.dart`이 `lib/data/**` import 하지 않는가?
- [ ] `lib/presentation/**/*.dart`이 `lib/data/models/**` import 하지 않는가?
- [ ] 모든 로직이 **providers** (UseCase 호출)를 통해서만 실행되는가?
- [ ] 직접 Repository 생성하지 않는가?

### ✅ Domain 레이어
- [ ] `lib/domain/**/*.dart`이 Flutter import 하지 않는가? (flutter/material.dart, widgets 등)
- [ ] 외부 패키지 (hive, riverpod, http 등) import 하지 않는가?
- [ ] 순수 Dart만 사용하는가?
- [ ] entities/repositories/usecases의 책임이 명확한가?

### ✅ Data 레이어
- [ ] `lib/data/models/**/*.dart`이 `lib/domain/entities/**`를 import하고 있는가?
- [ ] PetModel이 Pet을 extends하고 있는가?
- [ ] `@HiveType`, `@HiveField` 데코레이터가 올바르게 적용되었는가?

### ⚠️ 혼합 위험 영역
- [ ] `lib/core/**`의 상수/유틸이 어느 레이어에도 의존하지 않는가?
- [ ] presentation 화면이 data 모델을 직접 사용하지 않는가?

## 사용 예

```
당신: /check-architecture

Claude Code:
✓ 모든 Dart 파일 스캔
✓ 부정확한 import 탐지
✓ 각 레이어별 위반 항목 리스트업
✓ 수정 방안 제시
```

## 출력 형식

```
# Clean Architecture 검증 결과

## ✅ Presentation 레이어
- lib/presentation/screens/home_screen.dart
  ✓ lib/domain/** 올바르게 import
  ✓ lib/data/** import 없음

## ❌ Domain 레이어
- lib/domain/entities/pet.dart
  ✓ 순수 Dart (Flutter import 없음)
  ✓ 외부 패키지 없음

## ⚠️ Data 레이어
- lib/data/models/pet_model.dart
  ❌ Pet을 extends하지 않음! (상속 필수)
  해결: `class PetModel extends Pet { ... }`

## 📋 요약
- 총 파일 스캔: N개
- 규칙 위반: N개
- 자동 수정 불가: N개
```

## 추가 옵션

- `/check-architecture --layer domain` — Domain만 검증
- `/check-architecture --layer data` — Data만 검증
- `/check-architecture --strict` — 더 엄격한 규칙 (주석에서도 import 체크)
- `/check-architecture --fix` — 자동 수정 시도

## 예상 위반 사례

```dart
// ❌ BAD: Presentation이 Data import
import 'package:pocketfriend/data/models/pet_model.dart';

// ✅ GOOD: Domain entity 사용
import 'package:pocketfriend/domain/entities/pet.dart';

// ❌ BAD: Domain이 Flutter import
import 'package:flutter/material.dart';

// ✅ GOOD: 순수 Dart만
import 'dart:async';

// ❌ BAD: Domain이 외부 패키지 의존
import 'package:hive/hive.dart';

// ✅ GOOD: Data 레이어에서만 Hive 사용
class PetLocalDataSource {
  final Box<PetModel> box;
  // ...
}
```

---

**팁**: 새로운 파일 추가할 때마다 실행해서 구조 유지를 확인하세요.
