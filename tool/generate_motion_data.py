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
          / '+' 보조색 도트(배·부리·등딱지 등 — 원본 색에서 자동 태깅)
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

from PIL import Image

GRID = 24
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")

# 아트를 덤프할 때 사용한 원본/크롭/배치 파라미터 — accent 자동 태깅에 재사용
# (경로, 크롭 비율 (fx0,fy0,fx1,fy1) 또는 None, 리사이즈 (w,h), 그리드 y오프셋,
#  밝음 임계값 또는 None, 갈색 중간톤을 '+'로 볼지)
SPECIES_SRC = {
    "dragon": ("assets/dragon1.png", (0.13, 0.15, 0.86, 0.95), (24, 20), 3,
               0.75, False),
    "tiger": ("assets/tiger1.png", None, (24, 21), 2, 0.80, False),
    "bird": ("assets/bird1.png", (0.0, 0.0, 1.0, 0.95), (24, 20), 3,
             0.68, False),
    "turtle": ("assets/turtle1.png", (0.0, 0.0, 1.0, 0.93), (24, 20), 3,
               None, True),
}

# ---------------------------------------------------------------------------
# 아트 그리드 기본 연산 ('.'/'#'/'o' 문자 그리드, 24x24)
# ---------------------------------------------------------------------------

EMPTY_ROW = "." * GRID


def validate(art, name):
    assert len(art) == GRID, "%s: %d행 (24행이어야 함)" % (name, len(art))
    for i, row in enumerate(art):
        assert len(row) == GRID, "%s row %d: %d칸" % (name, i, len(row))
        assert set(row) <= {".", "#", "o", "+"}, (
            "%s row %d: 잘못된 문자" % (name, i)
        )


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


def apply_accent(art, species):
    """원본 PNG 색을 다시 샘플링해 'o'/'#' 셀 일부를 '+'(보조색)로 승격.

    - 밝은 영역(크림 배·흰 몸·노란 부리): luminance > light 임계값인 'o'
    - 갈색 중간톤(거북 등딱지): 0.18 <= luminance < 0.45인 '#'
    아웃라인(아주 어두움)과 눈은 dark로 유지된다.
    """
    path, frac, (w, h), y_off, light, darkmid = SPECIES_SRC[species]
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    if frac is not None:
        width, height = im.size
        im = im.crop((
            int(width * frac[0]),
            int(height * frac[1]),
            int(width * frac[2]),
            int(height * frac[3]),
        ))
        im = im.crop(im.getbbox() or (0, 0, im.width, im.height))
    small = im.resize((w, h), Image.BOX)
    px = small.load()

    out = []
    for y, row in enumerate(art):
        sy = y - y_off
        if not 0 <= sy < h:
            out.append(row)
            continue
        new_row = []
        for x, ch in enumerate(row):
            if ch in (".",) or x >= w:
                new_row.append(ch)
                continue
            r, g, b, a = px[x, sy]
            if a / 255.0 <= 0.5:
                new_row.append(ch)
                continue
            lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            if ch == "o" and light is not None and lum > light:
                new_row.append("+")
            elif ch == "#" and darkmid and 0.18 <= lum < 0.45 and r > g:
                # 갈색(붉은 계열) 중간톤만 — 어두운 초록 아웃라인은 제외
                new_row.append("+")
            else:
                new_row.append(ch)
        out.append("".join(new_row))
    return out


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


# 브레스(내뿜기) — 입 앞(-x)으로 퍼지는 콘. 'o'는 테마색, '#'은 진한 끝점
BREATH_PUFF = [
    (-2, -1, "o"), (-3, 0, "o"), (-2, 1, "o"), (-2, 0, "#"),
]
BREATH_CONE = [
    (-2, -1, "o"), (-3, -1, "o"), (-4, -2, "#"),
    (-2, 0, "o"), (-3, 0, "o"), (-4, 0, "o"), (-5, 0, "#"),
    (-2, 1, "o"), (-3, 1, "o"), (-4, 2, "#"),
    (-3, -2, "o"), (-3, 2, "o"),
]


def draw_breath(g, species, dx, dots):
    """현재 프레임의 입 위치(원본 입 + 몸 이동량) 기준으로 브레스를 찍음."""
    mx, my = SPECIES_ART[species]["mouth"]
    for ox, oy, ch in dots:
        put(g, mx + dx + ox, my + oy, ch)
    return g


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

# 밥그릇 — (dx, dy, 문자) 목록. '#' 그릇/김, '+' 밥(보조색 쌀 무더기)
_FOOD_BOWL = [
    # 그릇 (진한 사다리꼴 — rim / body / base)
    (0, 3, "#"), (1, 3, "#"), (2, 3, "#"), (3, 3, "#"), (4, 3, "#"),
    (0, 4, "#"), (1, 4, "#"), (2, 4, "#"), (3, 4, "#"), (4, 4, "#"),
    (1, 5, "#"), (2, 5, "#"), (3, 5, "#"),
]
FOOD_FULL = _FOOD_BOWL + [
    # 김 (모락모락)
    (2, 0, "#"), (4, -1, "#"),
    # 수북한 밥
    (1, 1, "+"), (2, 1, "+"), (3, 1, "+"),
    (0, 2, "+"), (1, 2, "+"), (2, 2, "+"), (3, 2, "+"), (4, 2, "+"),
]
FOOD_HALF = _FOOD_BOWL + [
    (3, 1, "#"),  # 김 (옅어짐)
    (1, 2, "+"), (2, 2, "+"), (3, 2, "+"),
]
FOOD_EMPTY = _FOOD_BOWL
FOOD_POS = (0, 17)

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


def with_chars(g, dots, ox, oy):
    """(dx, dy, 문자) 목록을 찍은 복사본 반환 (밥그릇 등 다색 글리프)."""
    out = [row[:] for row in g]
    for dx, dy, ch in dots:
        put(out, ox + dx, oy + dy, ch)
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
    밥은 보조색 쌀 무더기 + 김으로 그려 한눈에 '밥'으로 읽히게 한다.
    """
    f1 = pose(sp, eye="open", mouth="open", dx=2)
    f1 = with_chars(f1, FOOD_FULL, *FOOD_POS)
    f2 = head_bow(pose(sp, eye="closed", dx=2), 2)
    f2 = with_chars(f2, FOOD_HALF, *FOOD_POS)
    f3 = pose(sp, eye="happy", mouth="open", dx=2)
    f3 = with_chars(f3, FOOD_EMPTY, *FOOD_POS)
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
    """뒤로 움츠려 모았다가 → 앞으로 기울며 브레스 분출 → 최대 분사.

    브레스가 나갈 공간을 만들기 위해 몸을 오른쪽으로 물렸다가 내뿜는다.
    브레스의 'o' 도트는 테마색으로 렌더링 → 종별 속성 브레스처럼 보임.
    """
    windup = pose(sp, eye="angry", mouth="none", dx=3, lean=1)
    puff = pose(sp, eye="angry", mouth="open", step="front", dx=1, lean=-1)
    puff = draw_breath(puff, sp, 1, BREATH_PUFF)
    blast = pose(sp, eye="angry", mouth="open", step="back", dx=1, lean=-1)
    blast = draw_breath(blast, sp, 1, BREATH_CONE)
    return [windup, puff, blast]


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
    """>< 눈으로 움찔 → 뒤로 크게 휘청 → 비틀대며 복귀 (땀방울).

    이전의 '아웃라인만 남는 피격 플래시'는 흰 배경에서 캐릭터가
    하얗게 사라져 보여서 실제 휘청이는 포즈로 교체했다.
    """
    f1 = pose(sp, eye="pain", mouth="open", lean=1)
    f1 = with_glyph(f1, GLYPH_SWEAT, 20, 4)
    f2 = pose(sp, eye="pain", mouth="open", dx=2, lean=2)
    f2 = with_glyph(f2, GLYPH_SWEAT, 21, 3)
    f3 = pose(sp, eye="pain", dx=-1)
    f3 = with_glyph(f3, GLYPH_SWEAT, 21, 7)
    return [f1, f2, f3]


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


def art_to_masks(g):
    """아트 그리드 → (dark, body, accent) 행 마스크."""
    dark_rows = []
    body_rows = []
    accent_rows = []
    for y in range(GRID):
        dark = 0
        body = 0
        accent = 0
        for x in range(GRID):
            ch = g[y][x]
            if ch == "#":
                dark |= 1 << x
            elif ch == "o":
                body |= 1 << x
            elif ch == "+":
                accent |= 1 << x
        dark_rows.append(dark)
        body_rows.append(body)
        accent_rows.append(accent)
    return dark_rows, body_rows, accent_rows


def format_rows(rows):
    parts = ["0x%06X" % v for v in rows]
    lines = []
    for i in range(0, len(parts), 8):
        lines.append("      " + ", ".join(parts[i : i + 8]) + ",")
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    for name, meta in SPECIES_ART.items():
        validate(meta["body"], "%s.body" % name)
        # 원본 PNG 색 재샘플링으로 보조색('+') 자동 태깅
        meta["body"] = apply_accent(meta["body"], name)

    species_frames = {}
    for species in SPECIES_ART:
        motions = {}
        for motion_name, build in MOTIONS.items():
            frames = [art_to_masks(built) for built in build(species)]
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
                for dark, body, accent in frames:
                    f.write(
                        "      PixelSprite(\n"
                        "        size: %d,\n"
                        "        dark: %s,\n"
                        "        body: %s,\n"
                        "        accent: %s,\n"
                        "      ),\n"
                        % (
                            GRID,
                            format_rows(dark),
                            format_rows(body),
                            format_rows(accent),
                        )
                    )
                f.write("    ],\n")
            f.write("  },\n")
        f.write("};\n")

    total = sum(len(m) * 3 for m in species_frames.values())
    print("생성 완료: %s (%d개 프레임, %dx%d)" % (OUTPUT_PATH, total, GRID, GRID))
    return 0


if __name__ == "__main__":
    sys.exit(main())
