# -*- coding: utf-8 -*-
"""tool/character/ 정적 포즈시트를 앱 번들 에셋으로 복사한다.

케어·배틀·도감 대표 이미지와 진화 팝업은 이 포즈시트를 그대로 정적 표시한다
(걷기 애니메이션 프레임은 홈 모션용으로 별도 유지). 손수 보정한 포즈시트가
곧 표시 이미지이므로, 시트를 고친 뒤 이 스크립트를 한 번 돌리면 반영된다.

입력:  tool/character/{종}_{단계}.png   (예: 구미호_유아기.png)
출력:  assets/pets/{code}_{stage}.png   (예: gumiho_2.png)
       lib/core/anim/pose_sheet_manifest.dart  (사용 가능한 키 집합)

사용:  python tool/build_pose_sheets.py
"""
import os
import shutil

SRC_DIR = os.path.join("tool", "character")
OUT_DIR = os.path.join("assets", "pets")
MANIFEST = os.path.join("lib", "core", "anim", "pose_sheet_manifest.dart")

# 한글 종명 → EvolutionType.name (없는 종은 향후용으로 복사만; Dart 매핑은 helper가 담당)
SPECIES = {
    "백호": "tiger", "주작": "bird", "청룡": "snake", "현무": "turtle",
    "삼족오": "samjoko", "구미호": "gumiho", "달토끼": "moonrabbit",
    "해태": "haetae", "지리산곰": "bear", "두꺼비": "toad",
}
STAGE = {"유아기": 2, "성장기": 3, "성숙기": 4}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = []
    for fn in sorted(os.listdir(SRC_DIR)):
        if not fn.endswith(".png"):
            continue
        stem = fn[:-4]
        parts = stem.split("_")
        if len(parts) != 2:  # 현무_성숙기_0001 같은 프레임 시트는 제외
            continue
        sp, st = parts
        if sp not in SPECIES or st not in STAGE:
            continue
        key = f"{SPECIES[sp]}_{STAGE[st]}"
        shutil.copyfile(os.path.join(SRC_DIR, fn), os.path.join(OUT_DIR, f"{key}.png"))
        keys.append(key)

    keys.sort()
    lines = [
        "// GENERATED — tool/build_pose_sheets.py 로 재생성. 손으로 고치지 말 것.",
        "// tool/character/ 포즈시트를 assets/pets/ 로 복사한 결과의 키 집합.",
        "",
        "const Set<String> poseSheetKeys = {",
    ]
    lines += [f"  '{k}'," for k in keys]
    lines += ["};", ""]
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"copied {len(keys)} pose sheets → {OUT_DIR}")
    print(f"manifest → {MANIFEST}")
    for k in keys:
        print(f"  {k}")


if __name__ == "__main__":
    main()
