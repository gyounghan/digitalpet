# -*- coding: utf-8 -*-
"""베이비(유아기, stage 2) 스프라이트의 모션 프레임 합성 스크립트.

tiger1/bird1/turtle1/dragon1 그리드를 프로그램으로 변형해
다마고치 LCD 방식의 모션 3프레임을 만든다:
  - 이동/찌그러뜨림 (걷기 뒤뚱, 수면 엎드림, 공격 돌진, 회피 젖힘)
  - 이펙트 글리프 오버레이 (Z, 반짝이, 화남 마크, 땀, 슬래시, 속도선, 밥그릇)

모든 스프라이트는 왼쪽을 보고 있다 → 공격은 -x 돌진, 음식은 왼쪽 아래.

사용법:
    python tool/generate_motion_data.py

출력:
    lib/core/pixel/pet_motion_data.dart
"""

import os
import sys

from generate_pixel_data import GRID, extract_sprite, format_rows

OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")
FULL_MASK = (1 << GRID) - 1

SPECIES_SOURCES = {
    "tiger": os.path.join("assets", "tiger1.png"),
    "bird": os.path.join("assets", "bird1.png"),
    "turtle": os.path.join("assets", "turtle1.png"),
    "dragon": os.path.join("assets", "dragon1.png"),
}

# ---------------------------------------------------------------------------
# 그리드 변형
# ---------------------------------------------------------------------------


def shift(sprite, dx, dy):
    """스프라이트를 (dx, dy)만큼 이동. 그리드 밖은 클리핑."""
    dark, body = sprite

    def shift_rows(rows):
        out = [0] * GRID
        for y in range(GRID):
            ny = y + dy
            if not 0 <= ny < GRID:
                continue
            mask = rows[y]
            if dx >= 0:
                mask = (mask << dx) & FULL_MASK
            else:
                mask = mask >> (-dx)
            out[ny] = mask
        return out

    return shift_rows(dark), shift_rows(body)


def squash(sprite, factor):
    """세로로 눌러 바닥에 붙임 (수면 엎드림). factor < 1.0."""
    dark, body = sprite
    new_dark = [0] * GRID
    new_body = [0] * GRID
    bottom = GRID - 1
    for y in range(GRID):
        ny = bottom - int(round((bottom - y) * factor))
        new_dark[ny] |= dark[y]
        new_body[ny] |= body[y]
    # dark가 body보다 우선 (겹치면 아웃라인 유지)
    new_body = [b & ~d for b, d in zip(new_body, new_dark)]
    return new_dark, new_body


def overlay(sprite, glyph, ox, oy):
    """dark 도트 글리프를 (ox, oy) 기준으로 오버레이."""
    dark = list(sprite[0])
    body = list(sprite[1])
    for gx, gy in glyph:
        x, y = ox + gx, oy + gy
        if 0 <= x < GRID and 0 <= y < GRID:
            dark[y] |= 1 << x
            body[y] &= ~(1 << x)
    return dark, body


def blink(sprite):
    """몸통 도트를 지워 아웃라인만 남김 (피격 깜빡임)."""
    return list(sprite[0]), [0] * GRID


# ---------------------------------------------------------------------------
# 이펙트 글리프 (dark 도트 좌표)
# ---------------------------------------------------------------------------

GLYPH_Z = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]

GLYPH_SPARKLE = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]

# 💢 스타일 — 네 방향 대각선 틱
GLYPH_ANGER = [
    (0, 0), (1, 1),
    (4, 0), (3, 1),
    (0, 4), (1, 3),
    (4, 4), (3, 3),
]

GLYPH_SWEAT = [(1, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (1, 3)]

# 두 줄 대각선 슬래시 (공격 임팩트)
GLYPH_SLASH = [
    (4, 0), (3, 1), (2, 2), (1, 3), (0, 4),
    (6, 2), (5, 3), (4, 4), (3, 5), (2, 6),
]

# 가로 속도선 3줄 (회피)
GLYPH_SPEED = [
    (0, 0), (1, 0), (2, 0),
    (0, 4), (1, 4), (2, 4),
    (0, 8), (1, 8), (2, 8),
]

# 밥그릇 (7칸 폭): 수북 → 반 → 빈 그릇+부스러기
GLYPH_FOOD_FULL = (
    [(2, 0), (3, 0), (4, 0)]
    + [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    + [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
)
GLYPH_FOOD_HALF = (
    [(2, 1), (3, 1), (4, 1)]
    + [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
)
GLYPH_FOOD_EMPTY = (
    [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
    + [(0, 1), (6, 1)]  # 부스러기
)

FOOD_POS = (1, 26)

# ---------------------------------------------------------------------------
# 모션 정의 — 각 함수는 3프레임 리스트 반환
# ---------------------------------------------------------------------------


def motion_walk(s):
    return [shift(s, -1, 0), shift(s, 0, -1), shift(s, 1, 0)]


def motion_eat(s):
    fx, fy = FOOD_POS
    return [
        overlay(s, GLYPH_FOOD_FULL, fx, fy),
        overlay(shift(s, 0, 1), GLYPH_FOOD_HALF, fx, fy),
        overlay(s, GLYPH_FOOD_EMPTY, fx, fy),
    ]


def motion_sleep(s):
    lying = squash(s, 0.7)
    f1 = overlay(lying, GLYPH_Z, 22, 7)
    f2 = overlay(f1, GLYPH_Z, 25, 4)
    f3 = overlay(f2, GLYPH_Z, 28, 1)
    return [f1, f2, f3]


def motion_attack(s):
    return [
        s,
        shift(s, -2, 0),
        overlay(shift(s, -4, 0), GLYPH_SLASH, 0, 8),
    ]


def motion_dodge(s):
    return [
        s,
        overlay(shift(s, 3, 0), GLYPH_SPEED, 0, 10),
        shift(s, 1, 0),
    ]


def motion_hurt(s):
    return [
        overlay(s, GLYPH_SWEAT, 26, 3),
        blink(shift(s, 1, 0)),
        overlay(shift(s, -1, 0), GLYPH_SWEAT, 27, 6),
    ]


def motion_angry(s):
    return [
        overlay(s, GLYPH_ANGER, 24, 2),
        overlay(shift(s, 1, 0), GLYPH_ANGER, 23, 1),
        overlay(s, GLYPH_ANGER, 25, 3),
    ]


def motion_joy(s):
    f2 = shift(s, 0, -3)
    f2 = overlay(f2, GLYPH_SPARKLE, 2, 8)
    f2 = overlay(f2, GLYPH_SPARKLE, 27, 8)
    f3 = overlay(s, GLYPH_SPARKLE, 1, 13)
    f3 = overlay(f3, GLYPH_SPARKLE, 28, 13)
    return [s, f2, f3]


MOTIONS = {
    "walk": motion_walk,
    "eat": motion_eat,
    "sleep": motion_sleep,
    "attack": motion_attack,
    "dodge": motion_dodge,
    "hurt": motion_hurt,
    "angry": motion_angry,
    "joy": motion_joy,
}

# ---------------------------------------------------------------------------


def main() -> int:
    species_frames = {}
    for species, path in SPECIES_SOURCES.items():
        base = extract_sprite(path)
        if base is None:
            print("스프라이트 추출 실패: %s" % path, file=sys.stderr)
            return 1
        species_frames[species] = {
            name: build(base) for name, build in MOTIONS.items()
        }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(
            "// GENERATED CODE - DO NOT EDIT BY HAND\n"
            "// tool/generate_motion_data.py 로 재생성:\n"
            "//   python tool/generate_motion_data.py\n"
            "//\n"
            "// 베이비(stage 2) 스프라이트의 모션 3프레임 합성 데이터.\n"
            "// 이동/찌그러뜨림 + 이펙트 글리프(Z, 반짝이, 화남 마크 등)로\n"
            "// 다마고치 LCD 방식 모션을 표현한다.\n"
            "\n"
            "import 'pet_pixel_data.dart';\n"
            "\n"
            "/// 종(species) → 모션 이름 → 3프레임 도트 스프라이트\n"
            "const Map<String, Map<String, List<PixelSprite>>> "
            "babyMotionFrames = {\n"
        )
        for species, motions in species_frames.items():
            f.write("  '%s': {\n" % species)
            for motion_name, frames in motions.items():
                f.write("    '%s': [\n" % motion_name)
                for dark, body in frames:
                    f.write(
                        "      PixelSprite(\n"
                        "        size: %d,\n"
                        "        dark: %s,\n"
                        "        body: %s,\n"
                        "      ),\n" % (GRID, format_rows(dark), format_rows(body))
                    )
                f.write("    ],\n")
            f.write("  },\n")
        f.write("};\n")

    total = sum(len(m) * 3 for m in species_frames.values())
    print("생성 완료: %s (%d개 프레임)" % (OUTPUT_PATH, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
