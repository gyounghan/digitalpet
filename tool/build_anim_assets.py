# -*- coding: utf-8 -*-
"""AI/자체 제작 모션 프레임(PNG)을 앱 번들 에셋으로 정리한다.

입력(한글 파일명 {종}_{단계}_{모션}_{프레임}.png):
  - tool/animaition/ : 자체 제작 (최우선)
  - tool/pixellab/   : PixelLab AI 제작 (차선)
(스프라이트 도트는 프레임이 없을 때 런타임 폴백 — 3순위)

조합(종·단계·모션)마다 우선순위(자체 > AI)로 한 소스를 골라 프레임 전체를
assets/anim/{키}_{i}.png (88×88 투명)로 복사하고, 프레임 수·소스를 Dart
매니페스트로 굽는다. 키 = {EvolutionType.name}_{stage}_{motion}.

사용: python tool/build_anim_assets.py
"""
import os
import re
import shutil

SELF_DIR = "tool/animaition"
AI_DIR = "tool/pixellab"
OUT_DIR = os.path.join("assets", "anim")
MANIFEST = os.path.join("lib", "core", "anim", "anim_manifest.dart")

# 한글 → 코드 키
SPECIES = {
    "백호": "tiger", "주작": "bird", "청룡": "snake", "현무": "turtle",
    "삼족오": "samjoko", "구미호": "gumiho", "달토끼": "moonrabbit",
    "해태": "haetae", "지리산곰": "bear", "두꺼비": "toad",
}
STAGE = {"유아기": 2, "성장기": 3, "성숙기": 4}
MOTION = {
    "걷기": "walk", "먹기": "eat", "자기": "sleep", "화남": "angry",
    "기쁨": "joy", "배고픔": "hungry", "피격": "hurt", "회피": "dodge",
    "포효": "attack",
}


def collect(root):
    """root → {(species,stage,motion): [정렬된 파일경로]}"""
    out = {}
    if not os.path.isdir(root):
        return out
    for fn in os.listdir(root):
        if not fn.endswith(".png"):
            continue
        parts = fn[:-4].split("_")
        if len(parts) < 4:
            continue
        sp, st, mo, fr = parts[0], parts[1], parts[2], parts[3]
        if sp not in SPECIES or st not in STAGE or mo not in MOTION:
            continue
        key = (SPECIES[sp], STAGE[st], MOTION[mo])
        out.setdefault(key, []).append((int(re.sub(r"\D", "", fr) or 0),
                                        os.path.join(root, fn)))
    for k in out:
        out[k].sort()
    return out


def main():
    self_map = collect(SELF_DIR)
    ai_map = collect(AI_DIR)

    # 우선순위: 자체 > AI
    keys = set(self_map) | set(ai_map)
    chosen = {}  # key -> (source, [paths])
    for k in keys:
        if k in self_map:
            chosen[k] = ("self", [p for _, p in self_map[k]])
        else:
            chosen[k] = ("ai", [p for _, p in ai_map[k]])

    # 출력 폴더 초기화
    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR)

    counts = {}   # "tiger_2_walk" -> frame count
    sources = {}  # "tiger_2_walk" -> "self"/"ai"
    for (sp, st, mo), (src, paths) in sorted(chosen.items()):
        key = f"{sp}_{st}_{mo}"
        for i, p in enumerate(paths):
            shutil.copyfile(p, os.path.join(OUT_DIR, f"{key}_{i}.png"))
        counts[key] = len(paths)
        sources[key] = src

    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write("// GENERATED — tool/build_anim_assets.py 로 재생성. 직접 수정 금지.\n")
        f.write("//\n")
        f.write("// 키: {EvolutionType.name}_{stage}_{motion} → 프레임 수.\n")
        f.write("// 소스 우선순위: 자체(self) > AI(ai) > 도트 폴백(런타임).\n\n")
        f.write("/// 모션 프레임 애니메이션이 존재하는 (종·단계·모션) → 프레임 수.\n")
        f.write("const Map<String, int> animFrameCounts = {\n")
        for k in sorted(counts):
            f.write(f"  '{k}': {counts[k]},\n")
        f.write("};\n\n")
        f.write("/// 각 키의 프레임 출처('self'=자체, 'ai'=AI). 디버그·표기용.\n")
        f.write("const Map<String, String> animFrameSource = {\n")
        for k in sorted(sources):
            f.write(f"  '{k}': '{sources[k]}',\n")
        f.write("};\n")

    total = sum(counts.values())
    n_self = sum(1 for s in sources.values() if s == "self")
    print(f"생성: {OUT_DIR} — 조합 {len(counts)}개 / 프레임 {total}장 "
          f"(자체 {n_self}, AI {len(counts) - n_self})")
    print(f"매니페스트: {MANIFEST}")


if __name__ == "__main__":
    main()
