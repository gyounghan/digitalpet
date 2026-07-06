# -*- coding: utf-8 -*-
"""베이비(유아기, stage 2) 수제 도트 스프라이트 모션 생성 스크립트.

원본 PNG 변형이 아니라, 다마고치 방식 그대로 16x16 도트 아트를
직접 설계해 프레임을 만든다:
  - 종별 몸체(BODY)와 엎드린 자세(LYING)를 손으로 그린 도트 아트로 정의
  - 다리는 스탬프로 그려 걷기에서 앞/뒷다리가 실제로 교차
  - 눈 4종(뜸/감음/기쁨/아픔)과 입(다뭄/벌림)을 프레임별로 교체 → 표정
  - 이펙트 글리프(Z, 반짝이, 화남, 땀, 슬래시, 속도선, 밥그릇)

아트 문법: '.' 빈칸 / '#' 진한 도트(아웃라인·눈) / 'o' 몸통 도트(테마색)
모든 스프라이트는 왼쪽을 본다 → 공격 -x, 음식은 왼쪽 아래.

사용법:
    python tool/generate_motion_data.py
미리보기:
    python tool/preview_motion.py <종> <모션> [프레임]

출력:
    lib/core/pixel/pet_motion_data.dart (PixelSprite size=16)
"""

import os
import sys

GRID = 16
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")

# ---------------------------------------------------------------------------
# 아트 그리드 기본 연산 ('.'/'#'/'o' 문자 그리드, 16x16)
# ---------------------------------------------------------------------------

EMPTY_ROW = "." * GRID


def validate(art, name):
    assert len(art) == GRID, "%s: %d행 (16행이어야 함)" % (name, len(art))
    for i, row in enumerate(art):
        assert len(row) == GRID, "%s row %d: %d칸" % (name, i, len(row))
        assert set(row) <= {".", "#", "o"}, "%s row %d: 잘못된 문자" % (name, i)


def grid(art):
    """문자열 리스트 → 가변 2차원 리스트."""
    return [list(row) for row in art]


def to_art(g):
    return ["".join(row) for row in g]


def put(g, x, y, ch):
    if 0 <= x < GRID and 0 <= y < GRID:
        g[y][x] = ch


def stamp(g, dots, ox, oy, ch="#"):
    """도트 좌표 목록을 (ox, oy) 기준으로 찍음."""
    for dx, dy in dots:
        put(g, ox + dx, oy + dy, ch)


def shift_art(g, dx, dy):
    """그리드 전체 이동 (밖은 클리핑)."""
    out = [["."] * GRID for _ in range(GRID)]
    for y in range(GRID):
        for x in range(GRID):
            if g[y][x] == ".":
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < GRID and 0 <= ny < GRID:
                out[ny][nx] = g[y][x]
    return out


def move_region(g, x0, y0, x1, y1, dx, dy):
    """사각 영역의 도트만 이동 (머리 숙임 등 부위별 변형)."""
    moved = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < GRID and 0 <= y < GRID and g[y][x] != ".":
                moved.append((x + dx, y + dy, g[y][x]))
                g[y][x] = "."
    for x, y, ch in moved:
        put(g, x, y, ch)
    return g


def top_margin(g):
    """위쪽 빈 행 개수 (점프 시 머리 잘림 방지용)."""
    n = 0
    for row in g:
        if any(ch != "." for ch in row):
            break
        n += 1
    return n


def lift_art(g, dy_up):
    """위로 이동하되 머리가 잘리지 않는 만큼만."""
    return shift_art(g, 0, -min(dy_up, top_margin(g)))


def drop_row(g, y):
    """y행을 제거하고 위 행들을 한 칸 내림 (엎드려 날숨 등 눌림 표현)."""
    out = [row[:] for row in g]
    for yy in range(y, 0, -1):
        out[yy] = out[yy - 1][:]
    out[0] = ["."] * GRID
    return out


# ---------------------------------------------------------------------------
# 표정/다리 스탬프
# ---------------------------------------------------------------------------


def draw_eye(g, ex, ey, style):
    """(ex, ey) 기준 2x2 눈. open/closed/happy/pain/angry"""
    # 눈 영역을 몸색으로 초기화
    for dy in range(2):
        for dx in range(2):
            put(g, ex + dx, ey + dy, "o")
    if style == "open":
        stamp(g, [(0, 0), (1, 0), (0, 1), (1, 1)], ex, ey)
    elif style == "closed":  # 감은 눈 — 아래쪽 가로선
        stamp(g, [(0, 1), (1, 1)], ex, ey)
    elif style == "happy":  # ^ 모양 웃는 눈
        stamp(g, [(0, 1), (1, 0)], ex, ey)
    elif style == "pain":  # >< 찡그림 — 대각 두 점
        stamp(g, [(0, 0), (1, 1)], ex, ey)
    elif style == "angry":  # 부릅뜬 눈 + 치켜올린 눈썹
        stamp(g, [(0, 0), (1, 0), (0, 1), (1, 1)], ex, ey)
        put(g, ex + 1, ey - 1, "#")


def draw_mouth(g, mx, my, style):
    """입: none(다뭄) / open(벌림 1도트)"""
    if style == "open":
        put(g, mx, my, "#")


def draw_leg(g, x, lifted, forward=0):
    """1도트 폭 다리 스탬프.

    grounded: (x,14),(x,15) 세로 2도트
    lifted:   (x+forward,13),(x+forward,14) — 한 칸 들리고 앞으로
    """
    if lifted:
        put(g, x + forward, 13, "#")
        put(g, x + forward, 14, "#")
    else:
        put(g, x, 14, "#")
        put(g, x, 15, "#")


# ---------------------------------------------------------------------------
# 종별 도트 아트 (16x16, 왼쪽을 봄)
# BODY: 다리 없는 몸체 (rows 0~13) / LYING: 엎드려 자는 자세 (눈은 코드로)
# meta: eye(2x2 좌상단), mouth, front/back 다리 x, lying_eye
# ---------------------------------------------------------------------------

SPECIES_ART = {
    # 청룡 베이비 — 뿔 2개 + 오른쪽 꼬리
    "dragon": {
        "body": [
            "................",
            "...#......#.....",
            "..#o#....#o#....",
            "..#oo####oo#....",
            ".#oooooooooo#...",
            ".#oooooooooo#...",
            "#oooooooooooo#..",
            "#oooooooooooo#..",
            "#ooooooooooooo#.",
            "#oooooooooooo##.",
            ".#ooooooooooo#o#",
            ".#oooooooooo##..",
            "..#oooooooo#....",
            "..##oooooo##....",
            "................",
            "................",
        ],
        "eye": (2, 6),
        "mouth": (0, 9),
        "front_leg": 4,
        "back_leg": 9,
        "lying": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "...#......#.....",
            "..#o#....#o#....",
            ".#oo######oo##..",
            "#oooooooooooo##.",
            "#ooooooooooooo#o",
            "#oooooooooooooo#",
            ".##############.",
        ],
        "lying_eye": (2, 13),
    },
    # 백호 베이비 — 뾰족 귀 + 등 줄무늬 + 꼬리
    "tiger": {
        "body": [
            "................",
            "..##......##....",
            ".#o#......#o#...",
            ".#oo######oo#...",
            ".#oooooooooo#...",
            "#oooooooooooo#..",
            "#oooooo#ooooo#..",
            "#oooooo#oooooo#.",
            "#ooooooooooooo#.",
            "#oooooo#ooooo##.",
            ".#ooooo#ooooo#o#",
            ".#ooooooooooo##.",
            "..#ooooooooo#...",
            "..##ooooooo##...",
            "................",
            "................",
        ],
        "eye": (2, 6),
        "mouth": (0, 9),
        "front_leg": 4,
        "back_leg": 10,
        "lying": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "..##......##....",
            ".#o#......#o#...",
            "#oo########oo##.",
            "#ooooo#oooooo#o#",
            "#ooooo#ooooooo##",
            "#oooooooooooooo#",
            ".##############.",
        ],
        "lying_eye": (2, 13),
    },
    # 주작 베이비 — 볏 + 부리 + 날개선
    "bird": {
        "body": [
            "................",
            ".......#........",
            "......#o#.......",
            ".....#oo#.......",
            "....#ooooo##....",
            "...#ooooooooo#..",
            "..#oooooooooo#..",
            ".#ooooooooooo#..",
            "##oooooooooooo#.",
            ".#ooooooooooo##.",
            "..#ooooo#ooo#o#.",
            "..#ooooo#oooo#..",
            "...#ooooo#oo#...",
            "...##ooooo##....",
            "................",
            "................",
        ],
        "eye": (4, 6),
        "mouth": (1, 8),
        "front_leg": 5,
        "back_leg": 10,
        "lying": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "......#.........",
            ".....#o#........",
            "..###oo#####....",
            ".#ooooooooooo##.",
            "#ooooooooo#oo#o#",
            "#oooooooooooooo#",
            ".##############.",
        ],
        "lying_eye": (2, 13),
    },
    # 현무 베이비 — 등딱지 무늬 + 왼쪽으로 내민 머리
    "turtle": {
        "body": [
            "................",
            "................",
            "......########..",
            ".....#oooooooo#.",
            "....#ooo##ooo#..",
            "...#ooo#oo#ooo#.",
            "...#o##oooo##o#.",
            "...#oooooooooo#.",
            ".###oooooooooo#.",
            "#oo#oooooooooo#.",
            "#ooo#ooooooooo#.",
            "#ooo#ooooooooo#.",
            ".##.#oooooooo#..",
            "....##oooooo##..",
            "................",
            "................",
        ],
        "eye": (1, 9),
        "mouth": (0, 11),
        "front_leg": 6,
        "back_leg": 11,
        "lying": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "......######....",
            ".....#o####o#...",
            "....#o#oooo#o#..",
            "...#o#oooooo#o#.",
            ".###oooooooooo#.",
            "#oo#ooooooooooo#",
            "#o#ooooooooooo#.",
            "#oooooooooooooo#",
            ".##############.",
        ],
        "lying_eye": (1, 13),
    },
}

# ---------------------------------------------------------------------------
# 이펙트 글리프 (16그리드 기준 dark 도트 좌표)
# ---------------------------------------------------------------------------

GLYPH_Z = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]
GLYPH_Z_SMALL = [(0, 0), (1, 0), (0, 1), (1, 1)]
GLYPH_SPARKLE = [(1, 0), (0, 1), (2, 1), (1, 2)]
GLYPH_ANGER = [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]
GLYPH_SWEAT = [(0, 0), (0, 1)]
GLYPH_SPEED = [(0, 0), (1, 0), (0, 3), (1, 3), (0, 6), (1, 6)]

GLYPH_FOOD_FULL = [
    (1, 0), (2, 0),
    (0, 1), (1, 1), (2, 1), (3, 1),
    (0, 2), (1, 2), (2, 2), (3, 2),
    (1, 3), (2, 3),
]
GLYPH_FOOD_HALF = [
    (0, 2), (1, 2), (2, 2), (3, 2),
    (1, 3), (2, 3),
]
GLYPH_FOOD_EMPTY = [
    (0, 2), (3, 2),
    (1, 3), (2, 3),
]
FOOD_POS = (0, 12)

# ---------------------------------------------------------------------------
# 프레임 조립
# ---------------------------------------------------------------------------


def pose(
    species,
    eye="open",
    mouth="none",
    legs="stand",  # stand / front_up / back_up / tuck / none
    dx=0,
    dy=0,
    lean=0,  # 머리(상단 절반) 가로 이동: -1 앞으로 숙임, +1 뒤로 젖힘
):
    """종 몸체 + 다리 + 표정을 조립해 아트 그리드 반환."""
    meta = SPECIES_ART[species]
    g = grid(meta["body"])

    # 다리
    front, back = meta["front_leg"], meta["back_leg"]
    if legs == "stand":
        draw_leg(g, front, False)
        draw_leg(g, back, False)
    elif legs == "front_up":
        draw_leg(g, front, True, forward=-1)
        draw_leg(g, back, False)
    elif legs == "back_up":
        draw_leg(g, front, False)
        draw_leg(g, back, True, forward=-1)
    elif legs == "tuck":  # 점프 — 양다리 웅크림
        put(g, front, 13, "#")
        put(g, back, 13, "#")

    # 표정
    ex, ey = meta["eye"]
    draw_eye(g, ex, ey, eye)
    mx, my = meta["mouth"]
    draw_mouth(g, mx, my, mouth)

    # 기울임 (상단 절반만 가로 이동)
    if lean:
        g = move_region(g, 0, 0, GRID - 1, 7, lean, 0)

    if dx or dy:
        g = shift_art(g, dx, dy)
    return g


def lying_pose(species, exhale=False):
    """엎드려 자는 자세 (눈 감음). exhale=True면 한 칸 더 눌림(날숨)."""
    meta = SPECIES_ART[species]
    g = grid(meta["lying"])
    ex, ey = meta["lying_eye"]
    stamp(g, [(0, 0), (1, 0)], ex, ey)  # 감은 눈 가로선
    if exhale:
        # 몸통 내부 행(13)을 떨어뜨려 납작해짐 — 등 아웃라인은 유지
        g = drop_row(g, 13)
    return g


def with_glyph(g, glyph, ox, oy):
    out = [row[:] for row in g]
    stamp(out, glyph, ox, oy)
    return out


# ---------------------------------------------------------------------------
# 모션 정의 — 각 함수는 아트 그리드 3프레임 반환
# ---------------------------------------------------------------------------


def motion_walk(sp):
    """걷기: 앞다리 내딛기 → 양발 서기 → 뒷다리 내딛기 (다리 실제 교차)."""
    return [
        pose(sp, legs="front_up"),
        pose(sp, legs="stand"),
        pose(sp, legs="back_up"),
    ]


def motion_eat(sp):
    """머리 숙여 한 입(눈 감고 냠) → 다시 들기, 밥그릇 줄어듦."""
    f1 = pose(sp, eye="open", mouth="open")
    f1 = with_glyph(f1, GLYPH_FOOD_FULL, *FOOD_POS)
    f2 = pose(sp, eye="closed", mouth="none", lean=-1)
    f2 = grid(to_art(move_region(f2, 0, 0, GRID - 1, 7, 0, 1)))  # 머리 아래로
    f2 = with_glyph(f2, GLYPH_FOOD_HALF, *FOOD_POS)
    f3 = pose(sp, eye="happy", mouth="open")
    f3 = with_glyph(f3, GLYPH_FOOD_EMPTY, *FOOD_POS)
    return [f1, f2, f3]


def motion_sleep(sp):
    """엎드려 눈 감고 호흡, Z가 하나씩 올라감."""
    inhale = lying_pose(sp)
    exhale = lying_pose(sp, exhale=True)
    f1 = with_glyph(inhale, GLYPH_Z_SMALL, 12, 6)
    f2 = with_glyph(exhale, GLYPH_Z_SMALL, 12, 6)
    f2 = with_glyph(f2, GLYPH_Z, 13, 2)
    f3 = with_glyph(inhale, GLYPH_Z_SMALL, 11, 7)
    f3 = with_glyph(f3, GLYPH_Z, 12, 3)
    f3 = with_glyph(f3, GLYPH_Z, 13, 0)  # 위쪽 일부 잘려도 자연스러움
    return [f1, f2, f3]


def motion_attack(sp):
    """부릅뜬 눈으로 뒤로 젖혀 준비 → 앞으로 기울며 돌진 → 입 벌려 풀 런지."""
    windup = pose(sp, eye="angry", legs="stand", lean=1)
    lunge = pose(sp, eye="angry", legs="front_up", dx=-1, lean=-1)
    strike = pose(sp, eye="angry", mouth="open", legs="back_up", dx=-2, lean=-1)
    return [windup, lunge, strike]


def motion_dodge(sp):
    """움찔 → 뒤로 크게 젖히며 물러남(속도선) → 복귀."""
    f2 = pose(sp, eye="closed", legs="back_up", dx=2, lean=1)
    f3 = pose(sp, eye="open", legs="stand", dx=1)
    return [
        pose(sp, eye="open"),
        with_glyph(f2, GLYPH_SPEED, 0, 6),
        f3,
    ]


def motion_hurt(sp):
    """>< 눈으로 움찔 + 땀 → 피격 플래시 → 휘청."""
    f1 = pose(sp, eye="pain", mouth="open", lean=1)
    f1 = with_glyph(f1, GLYPH_SWEAT, 13, 2)
    flash = pose(sp, eye="pain", dx=1)  # blink는 마스크 단계에서 처리
    f3 = pose(sp, eye="pain", mouth="open", dx=-1)
    f3 = with_glyph(f3, GLYPH_SWEAT, 14, 4)
    return [f1, ("blink", flash), f3]


def motion_angry(sp):
    """부릅뜬 눈 + 입 벌려 씩씩 + 💢, 쿵쿵 발 구르기."""
    f1 = pose(sp, eye="angry", mouth="open", legs="front_up")
    f1 = with_glyph(f1, GLYPH_ANGER, 12, 1)
    f2 = pose(sp, eye="angry", mouth="none", legs="stand", dx=1)
    f2 = with_glyph(f2, GLYPH_ANGER, 11, 0)
    f3 = pose(sp, eye="angry", mouth="open", legs="back_up")
    f3 = with_glyph(f3, GLYPH_ANGER, 13, 2)
    return [f1, f2, f3]


def motion_joy(sp):
    """^^ 눈으로 웅크렸다 점프(다리 웅크림) → 착지, 반짝이."""
    crouch = pose(sp, eye="happy", legs="stand")
    airborne = lift_art(pose(sp, eye="happy", mouth="open", legs="tuck"), 2)
    landing = pose(sp, eye="happy", mouth="open", legs="stand")
    f2 = with_glyph(airborne, GLYPH_SPARKLE, 0, 4)
    f2 = with_glyph(f2, GLYPH_SPARKLE, 13, 4)
    f3 = with_glyph(landing, GLYPH_SPARKLE, 0, 8)
    f3 = with_glyph(f3, GLYPH_SPARKLE, 13, 8)
    return [crouch, f2, f3]


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
# 아트 → 비트마스크 변환 및 Dart 출력
# ---------------------------------------------------------------------------


def art_to_masks(g, blink=False):
    """아트 그리드 → (dark_rows, body_rows). blink면 몸통 도트 제거."""
    dark_rows = []
    body_rows = []
    for y in range(GRID):
        dark = 0
        body = 0
        for x in range(GRID):
            ch = g[y][x]
            if ch == "#":
                dark |= 1 << x
            elif ch == "o" and not blink:
                body |= 1 << x
        dark_rows.append(dark)
        body_rows.append(body)
    return dark_rows, body_rows


def format_rows(rows):
    parts = ["0x%04X" % v for v in rows]
    lines = []
    for i in range(0, len(parts), 8):
        lines.append("      " + ", ".join(parts[i : i + 8]) + ",")
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    for name, meta in SPECIES_ART.items():
        validate(meta["body"], "%s.body" % name)
        validate(meta["lying"], "%s.lying" % name)

    species_frames = {}
    for species in SPECIES_ART:
        motions = {}
        for motion_name, build in MOTIONS.items():
            frames = []
            for f in build(species):
                if isinstance(f, tuple) and f[0] == "blink":
                    frames.append(art_to_masks(f[1], blink=True))
                else:
                    frames.append(art_to_masks(f))
            motions[motion_name] = frames
        species_frames[species] = motions

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(
            "// GENERATED CODE - DO NOT EDIT BY HAND\n"
            "// tool/generate_motion_data.py 로 재생성:\n"
            "//   python tool/generate_motion_data.py\n"
            "//\n"
            "// 베이비(stage 2) 수제 16x16 도트 스프라이트 모션 3프레임.\n"
            "// 다리 교차 보행, 표정(눈/입) 변화, 엎드려 호흡 수면 등\n"
            "// 다마고치 방식으로 직접 설계한 도트 아트다.\n"
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
    print("생성 완료: %s (%d개 프레임, %dx%d)" % (OUTPUT_PATH, total, GRID, GRID))
    return 0


if __name__ == "__main__":
    sys.exit(main())
