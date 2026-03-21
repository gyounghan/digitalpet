---
name: analyze-flutter
description: flutter analyze 실행 후 문제점 분류, 우선순위 정렬, 개선 방안 제시
disable-model-invocation: true
---

# Flutter 코드 분석

`flutter analyze`를 실행하고 결과를 체계적으로 정리합니다.

## 실행 과정

1. **분석 실행**
   - `flutter analyze` 명령 실행
   - 모든 오류/경고/정보 수집

2. **분류 (우선순위 기준)**
   - 🔴 **ERROR** — 즉시 수정 필요 (컴파일 불가)
   - 🟠 **WARNING** — 빠른 수정 (runtime 문제 가능성)
   - 🟡 **INFO** — 권장 수정 (코드 품질 개선)
   - 🟢 **Ignored** — 무시 가능 (설정으로 비활성화된 항목)

3. **분석**
   - 각 카테고리별 이슈 개수
   - 반복되는 패턴 찾기 (예: 미사용 import가 10개라면 전체 정책 검토)
   - 근본 원인 파악

4. **개선 방안 제시**
   - 우선순위 제시
   - 각 이슈별 해결 방법
   - 자동 수정 가능 여부 판단
   - 한 번에 여러 개를 수정할 수 있는 패턴 제안

## 사용 예

```
당신: /analyze-flutter

Claude Code:
✓ flutter analyze 실행
✓ 결과 분류 및 우선순위 정렬
✓ 근본 원인 분석
✓ 자동 수정 가능한 항목 식별
✓ 수정 방안 제시
```

## 출력 형식

```
# Flutter Analyze 결과

## 📊 요약
- 총 이슈: N개
- ERROR: N개 🔴
- WARNING: N개 🟠
- INFO: N개 🟡
- 분석 시간: X초

## 🔴 ERROR (즉시 수정)
### 1. [파일경로:라인] 이슈명
문제: ...
영향: 컴파일 불가
해결 방법:
```

## 추가 기능

- 특정 파일만 분석: `/analyze-flutter lib/domain`
- 이전 분석과 비교: `/analyze-flutter --compare-last`
- 상세 리포트 생성: `/analyze-flutter --detailed`

---

**팁**: 매번 코드 변경 후 실행하면 문제를 빠르게 발견할 수 있습니다.
