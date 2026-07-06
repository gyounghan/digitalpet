# -*- coding: utf-8 -*-
"""베이비(유아기, stage 2) 도트 모션 생성 — 사용자 원본 캐릭터 기반.

assets/{dragon,tiger,bird,turtle}1.png 원본 픽셀아트를 24x24 도트 아트로
옮긴 뒤(물방울·동전·그림자 제거 등 수작업 정리), 부위별 변형으로
다마고치 방식 모션 3프레임을 만든다:
  - 걷기: 하단 다리 영역을 앞/뒤 절반으로 나눠 교차 스텝
  - 표정: 원본 눈 위치(rect)에 눈 4종(뜸/감음/^^/><) + 눈썹 + 입 벌림
  - 수면: 몸을 눌러 엎드림 + 감은 눈 + 호흡 + Z
  - 공격/회피/아픔: 상단 기울임(lean) + 돌진/젖힘
  - 이펙트 글리프 (Z, 반짝이, 화남, 땀, 속도선, 밥그릇)

아트 문법: '.' 빈칸 / '#' 진한 도트(아웃라인·눈) / 'o' 몸통 도트(테마색)
모든 스프라이트는 왼쪽을 본다 → 공격 -x, 음식은 왼쪽 아래.

사용법:
    python tool/generate_motion_data.py
미리보기:
    python tool/preview_motion.py <종> <모션> [프레임]

출력:
    lib/core/pixel/pet_motion_data.dart (PixelSprite size=24)
"""

import os
import sys

GRID = 24
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")

# ---------------------------------------------------------------------------
# 아트 그리드 기본 연산 ('.'/'#'/'o' 문자 그리드, 24x24)
# ---------------------------------------------------------------------------

EMPTY_ROW = "." * GRID


def validate(art, name):
    assert len(art) == GRID, "%s: %d행 (24행이어야 함)" % (name, len(art))
    for i, row in enumerate(art):
        assert len(row) == GRID, "%s row %d: %d칸" % (name, i, len(row))
        assert set(row) <= {".", "#", "o"}, "%s row %d: 잘못된 문자" % (name, i)


def grid(art):
    return [list(row) for row in art]


def put(g, x, y, ch):
    if 0 <= x < GRID and 0 <= y < GRID:
        g[y][x] = ch


def stamp(g, dots, ox, oy, ch="#"):
    for dx, dy in dots:
        put(g, ox + dx, oy + dy, ch)


def bbox(g):
    """도트가 있는 영역 (x0, x1, y0, y1)."""
    x0, x1, y0, y1 = GRID, -1, GRID, -1
    for y in range(GRID):
        for x in range(GRID):
            if g[y][x] != ".":
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
    return x0, x1, y0, y1


def shift_art(g, dx, dy):
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
    """사각 영역의 도트만 이동 (다리 스텝, 머리 숙임 등)."""
    moved = []
    for y in range(max(0, y0), min(GRID - 1, y1) + 1):
        for x in range(max(0, x0), min(GRID - 1, x1) + 1):
            if g[y][x] != ".":
                moved.append((x + dx, y + dy, g[y][x]))
                g[y][x] = "."
    for x, y, ch in moved:
        put(g, x, y, ch)
    return g


def top_margin(g):
    n = 0
    for row in g:
        if any(ch != "." for ch in row):
            break
        n += 1
    return n


def lift_art(g, dy_up):
    """위로 이동하되 머리가 잘리지 않는 만큼만."""
    return shift_art(g, 0, -min(dy_up, top_margin(g)))


def squash_art(g, factor):
    """바닥 고정 세로 눌림 (역매핑이라 구멍 없음). factor < 1.0"""
    _, _, y0, y1 = bbox(g)
    out = [["."] * GRID for _ in range(GRID)]
    for ny in range(GRID):
        if ny > y1:
            continue
        src = y1 - int(round((y1 - ny) / factor))
        if y0 <= src <= y1:
            out[ny] = g[src][:]
    return out


# ---------------------------------------------------------------------------
# 표정 (원본 눈 위치 rect에 스타일 오버레이)
# ---------------------------------------------------------------------------


def draw_eye(g, rect, style):
    """rect=(x, y, w, h) 영역에 눈 스타일을 그림."""
    x, y, w, h = rect
    for dy in range(h):
        for dx in range(w):
            put(g, x + dx, y + dy, "o")
    if style == "open":
        for dy in range(h):
            for dx in range(w):
                put(g, x + dx, y + dy, "#")
    elif style == "closed":  # 감은 눈 — 아래쪽 가로선
        for dx in range(w):
            put(g, x + dx, y + h - 1, "#")
    elif style == "happy":  # ^ 웃는 눈
        mid = (w - 1) / 2.0
        for dx in range(w):
            dy = int(round(abs(dx - mid) * (h - 1) / max(mid, 1)))
            put(g, x + dx, y + dy, "#")
    elif style == "pain":  # >< 찡그림 (X자)
        for dx in range(w):
            dy = int(round(dx * (h - 1) / max(w - 1, 1)))
            put(g, x + dx, y + dy, "#")
            put(g, x + dx, y + (h - 1) - dy, "#")
    elif style == "angry":  # 부릅뜬 눈 + 치켜올린 눈썹
        for dy in range(h):
            for dx in range(w):
                put(g, x + dx, y + dy, "#")
        put(g, x + w - 1, y - 1, "#")
        put(g, x + w - 2, y - 1, "#")


def draw_mouth(g, mx, my, style):
    if style == "open":
        put(g, mx, my, "#")
        put(g, mx + 1, my, "#")


# ---------------------------------------------------------------------------
# 종별 도트 아트 (24x24) — 원본 PNG를 옮긴 뒤 수작업 정리
# meta: eyes(rect 목록), mouth, 원본 유지를 위해 다리는 하단 영역 분리로 표현
# ---------------------------------------------------------------------------

SPECIES_ART = {
    # 아기 청룡 — 머리 볏, 큰 눈, 크림색 배, 오른쪽 말린 꼬리 (물방울·동전 제거)
    "dragon": {
        "body": [
            "........................",
            "........................",
            "........................",
            "........................",
            "............#o#.........",
            "..........##oo#.........",
            ".......####ooo###.......",
            ".....#oooooooooo##......",
            "....#ooooooooooooo#.....",
            "...#ooooooooooooo#......",
            "...#oooooooooooooo#.....",
            "..#o#ooooo###oooo##.....",
            "..###oooo#####ooo#......",
            "..#ooooooo###oooo#....##",
            "..#ooo#oooo#oooooo#...oo",
            "..##ooooooooooooo#....oo",
            "....#ooooooooooo#####.#o",
            "....#oooooooooooo##o###o",
            "...#oooooooooooooooooooo",
            "...#ooooooooo#oo#oo#ooo#",
            "....#oooooooo#oooo#####o",
            "....#oooooooo##oo###o#oo",
            "....##################..",
            "........................",
        ],
        "eyes": [(9, 11, 5, 3)],
        "mouth": (5, 16),
    },
    # 아기 백호 — 세모 귀, 정면 두 눈, 줄무늬, 오른쪽 꼬리
    "tiger": {
        "body": [
            "........................",
            "........................",
            "...##........##o........",
            "..#oo#######oooo#.......",
            "..#ooooooooooooo#.......",
            "..oooooooooooooo#.......",
            "..ooooooooooooo#o.......",
            "..#ooooooooooooo#.......",
            "..o##ooooo##oooo#.......",
            ".#o##ooooo##ooooo#......",
            ".#o#oo#oooo#oooooo......",
            ".ooooo##ooooooooo#......",
            ".#oooooooooooooo#.......",
            ".##oooooooooo#####......",
            "...##ooooooooooooo#..##.",
            "....oooooooooooooo#..#o#",
            "....ooooooooooooooo#.oo#",
            "....ooooooooooooooo#oooo",
            "...o#oooooooooooooo#ooo.",
            "...o#oooo#ooooooooo##oo.",
            "....o#oo#ooooo#ooo##ooo.",
            ".....#############......",
            "........................",
            "........................",
        ],
        "eyes": [(3, 8, 2, 2), (10, 8, 2, 2)],
        "mouth": (7, 12),
    },
    # 아기 주작 — 불꽃 볏/꼬리, 노란 부리, 둥근 몸 (그림자 제거)
    "bird": {
        "body": [
            "........................",
            "........................",
            "........................",
            "..............o.........",
            "..............oo........",
            "...........##oo..oo.....",
            ".......######oo##oo.....",
            ".....###oooo####o.o.....",
            "....#oooooooo##oooo.....",
            "...#oooooooooo###oo.....",
            "..#ooooooooooo##oo......",
            "..##oooo###ooo###.......",
            "..##oooo####ooo##o......",
            ".#oooooo###ooo##o.......",
            "..####ooo#ooo####.......",
            "..o#ooooooooooooo###ooo.",
            "..#ooooooooooooooo##oooo",
            ".##ooooooooo#oo######o..",
            ".o#ooooooooo#######ooo..",
            "ooo#oooooooo#######ooo#.",
            ".ooo###ooo#########oooo.",
            "....###############oo#o.",
            "......####...###........",
            "........................",
        ],
        "eyes": [(8, 11, 4, 3)],
        "mouth": (3, 12),
    },
    # 아기 현무 — 왼쪽으로 내민 머리, 큰 눈, 갈색 등딱지 (그림자 제거)
    "turtle": {
        "body": [
            "........................",
            "........................",
            "........................",
            "....#####...............",
            "...#oooo##..............",
            "..#oooooo##.............",
            ".#oooooooo##............",
            ".#ooooooooo#............",
            "#oooooooooo######.......",
            "##oooo###oo#######..##..",
            "##oooo#o#oo#########o#..",
            "#ooooo###oo#########o#..",
            "#oooooooooo#########o#..",
            "#oooooo#oooo##########..",
            ".#ooooooooo##########o..",
            ".oooooooooo##o#####o#...",
            "..##oooooooo##oo#ooo#...",
            "...o##oooooo###oooo##...",
            "....##oooooooo#######...",
            "...#o#oooo#ooo####oo#o..",
            "...#oo##oo#oooo####o#o..",
            "...########oooo#oo###...",
            "....###ooo#####oo.......",
            "........................",
        ],
        "eyes": [(6, 9, 3, 3)],
        "mouth": (3, 16),
    },
}

# ---------------------------------------------------------------------------
# 이펙트 글리프 (24그리드 기준 dark 도트 좌표)
# ---------------------------------------------------------------------------

GLYPH_Z = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]
GLYPH_Z_SMALL = [(0, 0), (1, 0), (0, 1), (1, 1)]
GLYPH_SPARKLE = [(1, 0), (0, 1), (2, 1), (1, 2)]
GLYPH_ANGER = [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]
GLYPH_SWEAT = [(0, 0), (0, 1)]
GLYPH_SPEED = [(0, 0), (1, 0), (0, 4), (1, 4), (0, 8), (1, 8)]

GLYPH_FOOD_FULL = [
    (1, 0), (2, 0), (3, 0),
    (0, 1), (1, 1), (2, 1), (3, 1), (4, 1),
    (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
    (1, 3), (2, 3), (3, 3),
]
GLYPH_FOOD_HALF = [
    (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
    (1, 3), (2, 3), (3, 3),
]
GLYPH_FOOD_EMPTY = [
    (0, 2), (4, 2),
    (1, 3), (2, 3), (3, 3),
]
FOOD_POS = (0, 18)

# ---------------------------------------------------------------------------
# 프레임 조립
# ---------------------------------------------------------------------------


def pose(
    species,
    eye="open",
    mouth="none",
    step=None,  # None / 'front' / 'back' / 'both_up'
    dx=0,
    dy=0,
    lean=0,  # 상단 절반 가로 이동: -1 앞으로 숙임, +1 뒤로 젖힘
):
    """원본 몸체 + 표정 + 다리 스텝을 조립해 아트 그리드 반환."""
    meta = SPECIES_ART[species]
    g = grid(meta["body"])

    # 표정 (기울임/이동 전에 원본 좌표 기준으로)
    for rect in meta["eyes"]:
        draw_eye(g, rect, eye)
    mx, my = meta["mouth"]
    draw_mouth(g, mx, my, mouth)

    # 다리 스텝 — 하단 3행을 앞/뒤 절반으로 나눠 들어올림
    if step:
        x0, x1, y0, y1 = bbox(g)
        xm = (x0 + x1) // 2
        leg_top = y1 - 2
        if step == "front":
            g = move_region(g, x0, leg_top, xm, y1, -1, -1)
        elif step == "back":
            g = move_region(g, xm + 1, leg_top, x1, y1, -1, -1)
        elif step == "both_up":  # 점프 시 다리 웅크림
            g = move_region(g, x0, leg_top, x1, y1, 0, -1)

    # 기울임 (상단 절반만 가로 이동)
    if lean:
        x0, x1, y0, y1 = bbox(g)
        head_bottom = y0 + (y1 - y0) // 2
        g = move_region(g, 0, 0, GRID - 1, head_bottom, lean, 0)

    if dx or dy:
        g = shift_art(g, dx, dy)
    return g


def lying_pose(species, factor):
    """몸을 눌러 엎드린 수면 자세 + 감은 눈 (호흡은 factor 차이로)."""
    meta = SPECIES_ART[species]
    g = grid(meta["body"])
    _, _, _, y1 = bbox(g)
    squashed = squash_art(g, factor)
    # 눌린 좌표계에서 감은 눈 다시 그림
    for x, y, w, h in meta["eyes"]:
        ny = y1 - int(round((y1 - (y + h - 1)) * factor))
        for dx in range(w):
            put(squashed, x + dx, ny, "#")
    return squashed


def head_bow(g, depth):
    """머리(상단 절반)를 앞(-x)·아래로 숙임 (밥먹기)."""
    x0, x1, y0, y1 = bbox(g)
    head_bottom = y0 + (y1 - y0) // 2
    return move_region(g, 0, 0, GRID - 1, head_bottom, -1, depth)


def with_glyph(g, glyph, ox, oy):
    out = [row[:] for row in g]
    stamp(out, glyph, ox, oy)
    return out


# ---------------------------------------------------------------------------
# 모션 정의 — 각 함수는 아트 그리드 3프레임 반환
# ---------------------------------------------------------------------------


def motion_walk(sp):
    """걷기: 앞다리 내딛기 → 양발 서기 → 뒷다리 내딛기."""
    return [
        pose(sp, step="front"),
        pose(sp),
        pose(sp, step="back"),
    ]


def motion_eat(sp):
    """머리 숙여 한 입(눈 감고 냠) → ^^ 눈으로 들기, 밥그릇 줄어듦.

    그릇 자리를 만들기 위해 몸을 오른쪽으로 2칸 비켜 세운다.
    """
    f1 = pose(sp, eye="open", mouth="open", dx=2)
    f1 = with_glyph(f1, GLYPH_FOOD_FULL, *FOOD_POS)
    f2 = head_bow(pose(sp, eye="closed", dx=2), 2)
    f2 = with_glyph(f2, GLYPH_FOOD_HALF, *FOOD_POS)
    f3 = pose(sp, eye="happy", mouth="open", dx=2)
    f3 = with_glyph(f3, GLYPH_FOOD_EMPTY, *FOOD_POS)
    return [f1, f2, f3]


def motion_sleep(sp):
    """엎드려 눈 감고 호흡, Z가 하나씩 올라감."""
    inhale = lying_pose(sp, 0.62)
    exhale = lying_pose(sp, 0.55)
    f1 = with_glyph(inhale, GLYPH_Z_SMALL, 17, 8)
    f2 = with_glyph(exhale, GLYPH_Z_SMALL, 17, 8)
    f2 = with_glyph(f2, GLYPH_Z, 19, 4)
    f3 = with_glyph(inhale, GLYPH_Z_SMALL, 16, 9)
    f3 = with_glyph(f3, GLYPH_Z, 18, 5)
    f3 = with_glyph(f3, GLYPH_Z, 20, 1)
    return [f1, f2, f3]


def motion_attack(sp):
    """부릅뜬 눈으로 뒤로 젖혀 준비 → 앞으로 기울며 돌진 → 입 벌려 풀 런지."""
    windup = pose(sp, eye="angry", lean=1)
    lunge = pose(sp, eye="angry", step="front", dx=-2, lean=-1)
    strike = pose(sp, eye="angry", mouth="open", step="back", dx=-3, lean=-1)
    return [windup, lunge, strike]


def motion_dodge(sp):
    """움찔 → 뒤로 크게 젖히며 물러남(속도선) → 복귀."""
    f2 = pose(sp, eye="closed", step="back", dx=3, lean=1)
    f3 = pose(sp, eye="open", dx=1)
    return [
        pose(sp, eye="open"),
        with_glyph(f2, GLYPH_SPEED, 0, 8),
        f3,
    ]


def motion_hurt(sp):
    """>< 눈으로 움찔 + 땀 → 피격 플래시 → 휘청."""
    f1 = pose(sp, eye="pain", mouth="open", lean=1)
    f1 = with_glyph(f1, GLYPH_SWEAT, 20, 4)
    flash = pose(sp, eye="pain", dx=1)  # blink는 마스크 단계에서 처리
    f3 = pose(sp, eye="pain", mouth="open", dx=-1)
    f3 = with_glyph(f3, GLYPH_SWEAT, 21, 7)
    return [f1, ("blink", flash), f3]


def motion_angry(sp):
    """부릅뜬 눈 + 입 벌려 씩씩 + 💢, 쿵쿵 발 구르기."""
    f1 = pose(sp, eye="angry", mouth="open", step="front")
    f1 = with_glyph(f1, GLYPH_ANGER, 18, 3)
    f2 = pose(sp, eye="angry", dx=1)
    f2 = with_glyph(f2, GLYPH_ANGER, 17, 2)
    f3 = pose(sp, eye="angry", mouth="open", step="back")
    f3 = with_glyph(f3, GLYPH_ANGER, 19, 4)
    return [f1, f2, f3]


def motion_joy(sp):
    """^^ 눈으로 살짝 숙였다 점프(다리 웅크림) → 착지, 반짝이."""
    crouch = pose(sp, eye="happy", dy=1)
    airborne = lift_art(pose(sp, eye="happy", mouth="open", step="both_up"), 3)
    landing = pose(sp, eye="happy", mouth="open", dy=1)
    f2 = with_glyph(airborne, GLYPH_SPARKLE, 0, 6)
    f2 = with_glyph(f2, GLYPH_SPARKLE, 21, 6)
    f3 = with_glyph(landing, GLYPH_SPARKLE, 0, 12)
    f3 = with_glyph(f3, GLYPH_SPARKLE, 21, 12)
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
    parts = ["0x%06X" % v for v in rows]
    lines = []
    for i in range(0, len(parts), 8):
        lines.append("      " + ", ".join(parts[i : i + 8]) + ",")
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    for name, meta in SPECIES_ART.items():
        validate(meta["body"], "%s.body" % name)

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
            "// 베이비(stage 2) 도트 모션 3프레임 — 원본 캐릭터(assets/*1.png)를\n"
            "// 24x24 도트 아트로 옮긴 뒤 다리 교차/표정/호흡을 입힌 데이터.\n"
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
