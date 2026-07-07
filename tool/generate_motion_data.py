# -*- coding: utf-8 -*-
"""도트 모션 생성 — 사용자 원본 캐릭터 기반 (유아기 24x24 + 성장기 28x28).

assets/{종}{1|2}.png 원본 픽셀아트를 도트 아트로 옮긴 뒤(물방울·동전·그림자
제거 등 수작업 정리), 부위별 변형으로 다마고치 방식 모션 3프레임을 만든다:
  - 걷기: 하단 다리 영역을 앞/뒤 절반으로 나눠 교차 스텝
  - 표정: 원본 눈 위치(rect)에 눈 4종(뜸/감음/^^/><) + 눈썹 + 입 벌림
  - 수면: 몸을 눌러 엎드림 + 감은 눈 + 호흡 + Z
  - 공격/회피/아픔: 상단 기울임(lean) + 돌진/젖힘
  - 이펙트 글리프 (Z, 반짝이, 화남, 땀, 속도선, 밥그릇)

그리드 크기는 아트마다 다를 수 있다 (유아기 24, 성장기 28). 모든 연산
함수는 len(g)에서 크기를 얻고, 이펙트 좌표는 24 기준값을 우측/하단
앵커로 보정한다.

아트 문법: '.' 빈칸 / '#' 진한 도트(아웃라인·눈) / 'o' 몸통 도트(테마색)
          / '+' 보조색 도트(배·부리·등딱지 등 — 원본 색에서 자동 태깅)
모든 스프라이트는 왼쪽을 본다 → 공격 -x, 음식은 왼쪽 아래.

사용법:
    python tool/generate_motion_data.py
미리보기:
    python tool/preview_motion.py <스프라이트키> <모션> [프레임]
    (예: python tool/preview_motion.py dragon2 attack)

출력:
    lib/core/pixel/pet_motion_data.dart (motionFrames — 키 '{종}{1|2}')
"""

import os
import sys

from PIL import Image

BASE = 24  # 이펙트 글리프 좌표의 기준 그리드 (24 기준값 + 앵커 보정)
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")

# 아트를 덤프할 때 사용한 원본/크롭/배치 파라미터 — accent 자동 태깅에 재사용
# path: 원본 PNG / crop: 비율 크롭 (fx0,fy0,fx1,fy1) 또는 None
# size: 리사이즈 (w,h) / off: 그리드 배치 오프셋 (x,y)
# light: 'o'를 '+'로 승격하는 밝음 임계값 또는 None
# darkmid: 갈색 중간톤 '#'를 '+'로 볼지 (거북 등딱지)
SPECIES_SRC = {
    "dragon1": dict(path="assets/dragon1.png", crop=(0.13, 0.15, 0.86, 0.95),
                    size=(24, 20), off=(0, 3), light=0.75, darkmid=False),
    "tiger1": dict(path="assets/tiger1.png", crop=None,
                   size=(24, 21), off=(0, 2), light=0.80, darkmid=False),
    "bird1": dict(path="assets/bird1.png", crop=(0.0, 0.0, 1.0, 0.95),
                  size=(24, 20), off=(0, 3), light=0.68, darkmid=False),
    "turtle1": dict(path="assets/turtle1.png", crop=(0.0, 0.0, 1.0, 0.93),
                    size=(24, 20), off=(0, 3), light=None, darkmid=True),
    # 성장기 (28x28)
    "dragon2": dict(path="assets/dragon2.png", crop=(0.0, 0.0, 1.0, 0.94),
                    size=(28, 23), off=(0, 4), light=0.75, darkmid=False),
    "tiger2": dict(path="assets/tiger2.png", crop=None,
                   size=(28, 24), off=(0, 3), light=0.80, darkmid=False),
    "bird2": dict(path="assets/bird2.png", crop=(0.0, 0.0, 1.0, 0.95),
                  size=(22, 26), off=(3, 1), light=0.68, darkmid=False),
    "turtle2": dict(path="assets/turtle2.png", crop=(0.0, 0.0, 1.0, 0.94),
                    size=(28, 20), off=(0, 7), light=None, darkmid=True),
}

# ---------------------------------------------------------------------------
# 아트 그리드 기본 연산 ('.'/'#'/'o'/'+' 문자 그리드 — 크기는 len(g)에서)
# ---------------------------------------------------------------------------


def validate(art, name):
    n = len(art)
    for i, row in enumerate(art):
        assert len(row) == n, "%s row %d: %d칸 (정사각 %d이어야 함)" % (
            name, i, len(row), n)
        assert set(row) <= {".", "#", "o", "+"}, (
            "%s row %d: 잘못된 문자" % (name, i)
        )


def grid(art):
    return [list(row) for row in art]


def put(g, x, y, ch):
    n = len(g)
    if 0 <= x < n and 0 <= y < n:
        g[y][x] = ch


def stamp(g, dots, ox, oy):
    for dx, dy in dots:
        put(g, ox + dx, oy + dy, "#")


def bbox(g):
    """도트가 있는 영역 (x0, x1, y0, y1)."""
    n = len(g)
    x0, x1, y0, y1 = n, -1, n, -1
    for y in range(n):
        for x in range(n):
            if g[y][x] != ".":
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
    return x0, x1, y0, y1


def shift_art(g, dx, dy):
    n = len(g)
    out = [["."] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            if g[y][x] == ".":
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < n and 0 <= ny < n:
                out[ny][nx] = g[y][x]
    return out


def move_region(g, x0, y0, x1, y1, dx, dy):
    """사각 영역의 도트만 이동 (다리 스텝, 머리 숙임 등)."""
    n = len(g)
    moved = []
    for y in range(max(0, y0), min(n - 1, y1) + 1):
        for x in range(max(0, x0), min(n - 1, x1) + 1):
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


def apply_accent(art, key):
    """원본 PNG 색을 다시 샘플링해 'o'/'#' 셀 일부를 '+'(보조색)로 승격.

    - 밝은 영역(크림 배·흰 몸·노란 부리): luminance > light 임계값인 'o'
    - 갈색 중간톤(거북 등딱지): 0.18 <= luminance < 0.45인 '#'
    아웃라인(아주 어두움)과 눈은 dark로 유지된다.
    """
    src = SPECIES_SRC[key]
    w, h = src["size"]
    x_off, y_off = src["off"]
    light, darkmid = src["light"], src["darkmid"]
    im = Image.open(src["path"]).convert("RGBA")
    im = im.crop(im.getbbox())
    if src["crop"] is not None:
        fx0, fy0, fx1, fy1 = src["crop"]
        width, height = im.size
        im = im.crop((
            int(width * fx0),
            int(height * fy0),
            int(width * fx1),
            int(height * fy1),
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
            sx = x - x_off
            if ch == "." or not 0 <= sx < w:
                new_row.append(ch)
                continue
            r, g, b, a = px[sx, sy]
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


def add_outline(art):
    """실루엣 바깥 한 겹을 검은 테두리('#')로 감싼다.

    원본을 도트로 줄이면 가장자리가 몸통색('o')으로 끝나 테두리가 빠진
    행이 생긴다(특히 성장기). 몸통/보조색/기존 테두리에 상하좌우로 접한
    빈칸을 '#'로 채워 전체 실루엣을 균일한 검은 테두리로 두른다.
    (대각선만 접한 칸은 제외 — 모서리가 뭉툭해지지 않게 4방향만)
    """
    n = len(art)
    g = [list(r) for r in art]
    out = [row[:] for row in g]
    solid = ("o", "+", "#")
    for y in range(n):
        for x in range(n):
            if g[y][x] != ".":
                continue
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = y + dy, x + dx
                if 0 <= nx < n and 0 <= ny < n and g[ny][nx] in solid:
                    out[y][x] = "#"
                    break
    return ["".join(r) for r in out]


def squash_art(g, factor):
    """바닥 고정 세로 눌림 (역매핑이라 구멍 없음). factor < 1.0"""
    n = len(g)
    _, _, y0, y1 = bbox(g)
    out = [["."] * n for _ in range(n)]
    for ny in range(n):
        if ny > y1:
            continue
        src = y1 - int(round((y1 - ny) / factor))
        if y0 <= src <= y1:
            out[ny] = g[src][:]
    return out


# ---------------------------------------------------------------------------
# 표정 (원본 눈 위치 rect에 스타일 오버레이)
# ---------------------------------------------------------------------------


def _clear_eye_box(g, ex, ey, pw, ph, halo=1):
    """표정을 그릴 자리를 몸통색으로 비운다.

    눈 박스 내부는 무조건 'o'로 채우고, 주변 halo px의 어두운 줄무늬/
    음영('#')만 'o'로 눌러 표정(어두운 ^/X)이 배경 줄무늬와 섞이지 않게 한다.
    실루엣 밖(빈칸 '.')·보조색('+')은 건드리지 않아 몸 형태는 유지된다.
    (tiger처럼 눈이 얼굴 줄무늬에 파묻힌 종은 halo=2로 넓게 정리해야 함)
    """
    n = len(g)
    for dy in range(-halo, ph + halo):
        for dx in range(-halo, pw + halo):
            xx, yy = ex + dx, ey + dy
            if not (0 <= xx < n and 0 <= yy < n):
                continue
            inside = 0 <= dx < pw and 0 <= dy < ph
            if inside:
                g[yy][xx] = "o"
            elif g[yy][xx] == "#":  # 주변 줄무늬만 정리 (빈칸/보조색 유지)
                g[yy][xx] = "o"


def draw_eye(g, rect, style):
    """rect=(x, y, w, h) 영역에 눈 스타일을 그림.

    happy/pain/angry는 획이 성글어 작은 눈(2x2)에선 안 보이므로 최소 3x3로
    키우고(중앙 정렬) 주변 줄무늬를 정리한 뒤 획을 굵게 그린다.
    open/closed는 면을 채워 작아도 보이므로 원본 크기 그대로 둔다.
    """
    x, y, w, h = rect
    if style in ("happy", "pain", "angry"):
        pw, ph = max(w, 3), max(h, 3)
        ex = x - (pw - w) // 2
        ey = y - (ph - h) // 2
        # 작은 눈(2x2)은 얼굴 줄무늬에 파묻히므로 주변을 2px까지 넓게 정리
        halo = 2 if min(w, h) <= 2 else 1
        _clear_eye_box(g, ex, ey, pw, ph, halo=halo)
    else:
        pw, ph, ex, ey = w, h, x, y
        for dy in range(ph):
            for dx in range(pw):
                put(g, ex + dx, ey + dy, "o")

    if style == "open":
        for dy in range(ph):
            for dx in range(pw):
                put(g, ex + dx, ey + dy, "#")
    elif style == "closed":  # 감은 눈 — 아래쪽 가로선
        for dx in range(pw):
            put(g, ex + dx, ey + ph - 1, "#")
    elif style == "happy":  # ^ 웃는 눈 (위로 볼록, 굵게)
        mid = (pw - 1) / 2.0
        for dx in range(pw):
            dy = min(int(round(abs(dx - mid))), ph - 1)
            put(g, ex + dx, ey + dy, "#")
            if dy + 1 < ph:  # 한 칸 아래도 찍어 획을 굵게
                put(g, ex + dx, ey + dy + 1, "#")
    elif style == "pain":  # >< 찡그림 (X자)
        # 박스를 몸통색으로 비우고 halo로 주변 줄무늬를 정리했으므로
        # 가는 X 두 대각선이면 배경과 구분돼 보인다.
        for dx in range(pw):
            dy = int(round(dx * (ph - 1) / max(pw - 1, 1)))
            put(g, ex + dx, ey + dy, "#")
            put(g, ex + dx, ey + (ph - 1) - dy, "#")
    elif style == "angry":  # 부릅뜬 눈 + 치켜올린 눈썹
        for dy in range(ph):
            for dx in range(pw):
                put(g, ex + dx, ey + dy, "#")
        put(g, ex + pw - 1, ey - 1, "#")
        put(g, ex + pw - 2, ey - 1, "#")


def draw_mouth(g, mx, my, style):
    if style == "open":
        put(g, mx, my, "#")
        put(g, mx + 1, my, "#")


# 브레스(내뿜기) — 몸에서 분리되어 날아가는 투사체. 'o' 테마색, '#' 진한 점
# 발사 직후의 작은 덩어리 (몸 앞에서 1~2칸 떨어짐)
BREATH_PUFF = [
    (-3, -1, "o"), (-4, -1, "o"),
    (-3, 0, "o"), (-4, 0, "o"), (-5, 0, "#"),
    (-3, 1, "o"), (-4, 1, "o"),
]
# 멀리 날아간 파이어볼 (그리드 왼쪽 끝에 절대 배치, 앞끝·튀김은 진한 점)
BREATH_BALL = [
    (1, -1, "o"), (2, -1, "o"), (3, -1, "o"),
    (0, 0, "#"), (1, 0, "o"), (2, 0, "o"), (3, 0, "o"), (4, 0, "o"),
    (1, 1, "o"), (2, 1, "o"), (3, 1, "o"),
    (1, -2, "#"), (1, 2, "#"),
]


def _breath_origin(g, my):
    """입 높이(±1행)에서 몸의 왼쪽 가장자리 x — 브레스 시작 기준점.

    tiger처럼 입이 몸 안쪽(정면 얼굴)에 있는 종도 몸 밖으로 분사되게 한다.
    """
    n = len(g)
    for y in (my, my - 1, my + 1):
        if not 0 <= y < n:
            continue
        for x in range(n):
            if g[y][x] != ".":
                return x
    return n // 2


def draw_breath_puff(g, key):
    """발사 직후 — 몸 앞에 갓 떨어져 나온 작은 덩어리."""
    my = SPECIES_ART[key]["mouth"][1]
    origin = _breath_origin(g, my)
    for ox, oy, ch in BREATH_PUFF:
        put(g, origin + ox, my + oy, ch)
    return g


def draw_breath_ball(g, key):
    """멀리 날아간 투사체 — 왼쪽 끝에 파이어볼 + 몸과의 사이에 궤적 잔상."""
    my = SPECIES_ART[key]["mouth"][1]
    origin = _breath_origin(g, my)
    for ox, oy, ch in BREATH_BALL:
        put(g, ox, my + oy, ch)
    # 궤적 잔상 (몸과 파이어볼 사이 — 간격을 두고 점점이)
    put(g, origin - 2, my, "o")
    put(g, origin - 4, my - 1, "o")
    return g


# ---------------------------------------------------------------------------
# 스프라이트별 도트 아트 — 원본 PNG를 옮긴 뒤 수작업 정리
# 키: '{종}{스테이지}' (유아기 1 = 24x24, 성장기 2 = 28x28)
# meta: body(정사각 아트), eyes(rect 목록), mouth
# ---------------------------------------------------------------------------

SPECIES_ART = {
    # 아기 청룡 — 머리 볏, 큰 눈, 크림색 배, 오른쪽 말린 꼬리 (물방울·동전 제거)
    "dragon1": {
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
    "tiger1": {
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
    "bird1": {
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
    "turtle1": {
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
    # 성장기 청룡(이무기) — 목 긴 수룡, 노란 뿔, 크림 배, 오른쪽 꼬리 지느러미
    "dragon2": {
        "body": [
            "............................",
            "............................",
            "............................",
            "............................",
            ".......++....++.............",
            ".......++#.#++#.............",
            ".....##oo###ooo#............",
            ".....#oooooooo##............",
            "...###oooooooo#o#...........",
            "...#oooooooooooo#...........",
            "..#ooooooooooooo#...........",
            "..#ooooo###ooooo#.......#...",
            "..#ooooo###ooooo#......#o#..",
            "..#ooooo###ooooo#.....#ooo#.",
            "..#oo#..#ooooo##.....#ooooo#",
            "..###..#ooooo##......#ooooo#",
            ".....##oooooo#......#oooo##.",
            "....#ooooooo#........#oooo#.",
            "...#ooooooo#.###o###..####..",
            "...#oooooo#.#ooooooo#..##...",
            "..#oooooo###ooooooo##.#oo#..",
            "..#oooooo##oooooo#o###ooo#..",
            "..#ooooooo#ooooooooo###o#...",
            "..#ooooooooo##oo#oooo#oo#...",
            ".#oooooooooo#oo#o#oooo#oo#..",
            ".#oooo######oooooooooooo#...",
            "..####......############....",
            "............................",
        ],
        "eyes": [(8, 11, 3, 3)],
        "mouth": (3, 13),
    },
    # 성장기 백호 — 몸집 커진 백호, 긴 꼬리, 줄무늬 진해짐
    "tiger2": {
        "body": [
            "............................",
            "............................",
            "............................",
            "...##........##.............",
            "..#oo#######ooo#............",
            "..#oooooo#oooooo#...........",
            "..#ooooooooooooo#...........",
            "..oooooooooooooo#...........",
            "..ooooooooooooooo...........",
            "..o##ooooo##ooooo...........",
            ".#o##ooooo##ooooo#..........",
            ".#oooo#ooooooooooo..........",
            "#ooooo##oooooooooo..........",
            ".#oooooooooooooo#...........",
            "..#ooooooooooo#o#####..#oo..",
            "...#oooooooooooooooo##.oo#..",
            "...#ooooooooooooooooo###o#o.",
            "...#ooooooooooooooo#oooooo#o",
            "...#oooooooooooooooooo#o##o#",
            "....#ooooooooooooooooo###oo#",
            "....#oooooooooooooooooo#oo#.",
            "....#o##ooooooooooooooo###o.",
            "....#oooo##oooo###oooo#.....",
            "....#oooo#oooooooo#ooo#.....",
            "...#o#ooooooooo#oo#oooo#....",
            "..#ooo########oooo###ooooo#.",
            "............................",
            "............................",
        ],
        "eyes": [(3, 9, 2, 2), (10, 9, 2, 2)],
        "mouth": (6, 12),
    },
    # 성장기 주작 — 불꽃 볏·꼬리가 커진 주황 새, 노란 부리, 날개 깃 선명
    "bird2": {
        "body": [
            "............................",
            "...........oooo.............",
            "..........ooooo.............",
            "..........oooooooo..........",
            "..........##oooooo..........",
            ".......o####o#oooo..........",
            "......##ooo###oooo..........",
            ".....#oooooo####oo..........",
            "....##oooooo####oo..........",
            "....#oooooooo#oooo..........",
            "....##oo###oo##oo...........",
            "..##oooo###oo##oo...........",
            "...####oo#ooo##oo...........",
            "....o##ooooo##ooo...........",
            "....o#ooooo####oo...........",
            "....ooooooo##oo##o..ooo.....",
            "....#oooooo#oooo#oooooo.....",
            "...#ooooooo#ooooo#o#oooo....",
            "...#ooooooo#oo#oo###oooo....",
            "...#ooooooo#oo##oo###ooo....",
            "...o#oooooo##oo##o##ooooo...",
            "...o##ooooo###ooo##oooooo...",
            "....o###o##oooooo##oooooo...",
            "....oo##oooooooooo##ooooo...",
            "....oooo##oooooo###ooooo....",
            "....oo##o#oo##o#o#####oo....",
            "....ooo#o#o##o##oooooooo....",
            "............................",
        ],
        "eyes": [(8, 10, 3, 3)],
        "mouth": (3, 11),
    },
    # 성장기 현무 — 갈색 등딱지 거북 + 오른쪽 위로 솟은 뱀 꼬리(눈 2쌍)
    "turtle2": {
        "body": [
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            ".................####.......",
            "................#oooo##.....",
            "................#o###oo#....",
            "................#o##ooo#....",
            "................##ooooo#....",
            "............####.###oo##....",
            ".##oooo##.#########.#ooo#...",
            "#oooooooo##oo########ooo#...",
            "#ooooo#ooo####o######oo##...",
            "#ooooo#ooo##############....",
            "#oooo##ooo#############o....",
            "#ooooooooo#######oo####.....",
            ".#ooooooooo#o####o#####.....",
            "..###oooooo##o#############.",
            "....#ooooooo##o#######o##o#.",
            "....#ooooooo###ooooooo##o#..",
            "...#o#oooooooo####ooo####...",
            "...#oo###oo#oooo#####ooo#...",
            "..#oooo#oo#ooooo#ooo#o#o#...",
            "..######oo#oooo#ooo##ooo#...",
            "............................",
        ],
        "eyes": [(6, 15, 2, 2), (18, 9, 2, 2)],
        "mouth": (2, 17),
    },
}

# ---------------------------------------------------------------------------
# 이펙트 글리프 (24 기준 dark 도트 좌표 — 배치 시 앵커 보정)
# ---------------------------------------------------------------------------

GLYPH_Z = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]
GLYPH_Z_SMALL = [(0, 0), (1, 0), (0, 1), (1, 1)]
GLYPH_SPARKLE = [(1, 0), (0, 1), (2, 1), (1, 2)]
GLYPH_ANGER = [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]
GLYPH_SWEAT = [(0, 0), (0, 1)]
GLYPH_SPEED = [(0, 0), (1, 0), (0, 4), (1, 4), (0, 8), (1, 8)]
GLYPH_DROOL = [(0, 0), (0, 1)]  # 입 아래로 흘리는 침 (짧게)
GLYPH_DROOL_LONG = [(0, 0), (0, 1), (0, 2)]  # 길게 늘어진 침

# 밥 상상 아이콘 — 머리 위 말풍선에 떠오르는 밥공기 (배고픔의 명확한 기호)
# '+' 밥(보조색 무더기), '#' 그릇(진한 사다리꼴)
FOOD_THOUGHT = [
    (1, 0, "+"), (2, 0, "+"), (3, 0, "+"),
    (0, 1, "#"), (1, 1, "#"), (2, 1, "#"), (3, 1, "#"), (4, 1, "#"),
    (1, 2, "#"), (2, 2, "#"), (3, 2, "#"),
]

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

# ---------------------------------------------------------------------------
# 프레임 조립
# ---------------------------------------------------------------------------


def art_size(key):
    return len(SPECIES_ART[key]["body"])


def pose(
    key,
    eye="open",
    mouth="none",
    step=None,  # None / 'front' / 'back' / 'both_up'
    dx=0,
    dy=0,
    lean=0,  # 상단 절반 가로 이동: -1 앞으로 숙임, +1 뒤로 젖힘
):
    """원본 몸체 + 표정 + 다리 스텝을 조립해 아트 그리드 반환."""
    meta = SPECIES_ART[key]
    g = grid(meta["body"])
    n = len(g)

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
        g = move_region(g, 0, 0, n - 1, head_bottom, lean, 0)

    if dx or dy:
        g = shift_art(g, dx, dy)
    return g


def lying_pose(key, factor):
    """몸을 눌러 엎드린 수면 자세 + 감은 눈 (호흡은 factor 차이로)."""
    meta = SPECIES_ART[key]
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
    n = len(g)
    x0, x1, y0, y1 = bbox(g)
    head_bottom = y0 + (y1 - y0) // 2
    return move_region(g, 0, 0, n - 1, head_bottom, -1, depth)


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
# 이펙트 좌표는 24 기준값에 r(= 크기 - 24)을 더해 우측/하단 앵커로 보정
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
    n = art_size(sp)
    food_pos = (0, n - 7)  # 그릇 바닥이 지면(n-2행 근처)에 닿게 하단 앵커
    f1 = pose(sp, eye="open", mouth="open", dx=2)
    f1 = with_chars(f1, FOOD_FULL, *food_pos)
    f2 = head_bow(pose(sp, eye="closed", dx=2), 2)
    f2 = with_chars(f2, FOOD_HALF, *food_pos)
    f3 = pose(sp, eye="happy", mouth="open", dx=2)
    f3 = with_chars(f3, FOOD_EMPTY, *food_pos)
    return [f1, f2, f3]


def motion_sleep(sp):
    """엎드려 눈 감고 호흡, Z가 하나씩 올라감."""
    r = art_size(sp) - BASE
    inhale = lying_pose(sp, 0.62)
    exhale = lying_pose(sp, 0.55)
    f1 = with_glyph(inhale, GLYPH_Z_SMALL, 17 + r, 8 + r)
    f2 = with_glyph(exhale, GLYPH_Z_SMALL, 17 + r, 8 + r)
    f2 = with_glyph(f2, GLYPH_Z, 19 + r, 4 + r)
    f3 = with_glyph(inhale, GLYPH_Z_SMALL, 16 + r, 9 + r)
    f3 = with_glyph(f3, GLYPH_Z, 18 + r, 5 + r)
    f3 = with_glyph(f3, GLYPH_Z, 20 + r, 1 + r)
    return [f1, f2, f3]


def motion_attack(sp):
    """뒤로 움츠려 모았다가 → 앞으로 기울며 브레스 분출 → 최대 분사.

    브레스가 나갈 공간을 만들기 위해 몸을 오른쪽으로 물렸다가 내뿜는다.
    브레스의 'o' 도트는 테마색으로 렌더링 → 종별 속성 브레스처럼 보임.
    """
    windup = pose(sp, eye="angry", mouth="none", dx=5, lean=1)
    puff = pose(sp, eye="angry", mouth="open", step="front", dx=4, lean=-1)
    puff = draw_breath_puff(puff, sp)
    blast = pose(sp, eye="angry", mouth="open", step="back", dx=4, lean=-1)
    blast = draw_breath_ball(blast, sp)
    return [windup, puff, blast]


def motion_dodge(sp):
    """움찔 → 뒤로 크게 젖히며 물러남(속도선) → 복귀."""
    r = art_size(sp) - BASE
    f2 = pose(sp, eye="closed", step="back", dx=3, lean=1)
    f3 = pose(sp, eye="open", dx=1)
    return [
        pose(sp, eye="open"),
        with_glyph(f2, GLYPH_SPEED, 0, 8 + r // 2),
        f3,
    ]


def motion_hurt(sp):
    """>< 눈으로 움찔 → 뒤로 크게 휘청 → 비틀대며 복귀 (땀방울).

    이전의 '아웃라인만 남는 피격 플래시'는 흰 배경에서 캐릭터가
    하얗게 사라져 보여서 실제 휘청이는 포즈로 교체했다.
    """
    # 땀방울은 몸이 닿지 않는 머리 위 상단(0~3행)에 배치 — 잘림/겹침 방지
    r = art_size(sp) - BASE
    f1 = pose(sp, eye="pain", mouth="open", lean=1)
    f1 = with_glyph(f1, GLYPH_SWEAT, 19 + r, 1)
    f2 = pose(sp, eye="pain", mouth="open", dx=1, lean=2)
    f2 = with_glyph(f2, GLYPH_SWEAT, 21 + r, 2)
    f2 = with_glyph(f2, GLYPH_SWEAT, 18 + r, 0)
    f3 = pose(sp, eye="pain", dx=-1)
    f3 = with_glyph(f3, GLYPH_SWEAT, 17 + r, 1)
    return [f1, f2, f3]


def motion_angry(sp):
    """부릅뜬 눈 + 입 벌려 씩씩 + 💢, 쿵쿵 발 구르기."""
    r = art_size(sp) - BASE
    f1 = pose(sp, eye="angry", mouth="open", step="front")
    f1 = with_glyph(f1, GLYPH_ANGER, 18 + r, 3)
    f2 = pose(sp, eye="angry", dx=1)
    f2 = with_glyph(f2, GLYPH_ANGER, 17 + r, 2)
    f3 = pose(sp, eye="angry", mouth="open", step="back")
    f3 = with_glyph(f3, GLYPH_ANGER, 19 + r, 4)
    return [f1, f2, f3]


def motion_joy(sp):
    """^^ 눈으로 살짝 숙였다 점프(다리 웅크림) → 착지, 반짝이."""
    r = art_size(sp) - BASE
    crouch = pose(sp, eye="happy", dy=1)
    airborne = lift_art(pose(sp, eye="happy", mouth="open", step="both_up"), 3)
    landing = pose(sp, eye="happy", mouth="open", dy=1)
    f2 = with_glyph(airborne, GLYPH_SPARKLE, 0, 6 + r // 2)
    f2 = with_glyph(f2, GLYPH_SPARKLE, 21 + r, 6 + r // 2)
    f3 = with_glyph(landing, GLYPH_SPARKLE, 0, 12 + r // 2)
    f3 = with_glyph(f3, GLYPH_SPARKLE, 21 + r, 12 + r // 2)
    return [crouch, f2, f3]


def motion_hungry(sp):
    """배고픔: 힘없이 축 처져 머리 위로 밥을 떠올리며 군침 흘림.

    배고픔의 명확한 기호인 '밥 상상 말풍선'을 핵심으로 한다:
      f1 힘없이 처짐(눈 감음) + 생각 점 하나 (밥 떠올리기 시작)
      f2 더 처짐 + 밥공기 아이콘 등장 + 말풍선 점 + 침
      f3 밥을 보며 눈 뜨고 군침(반짝) — 루프 시 아이콘이 피어올랐다 사라져
         '계속 밥 생각하는' 느낌을 준다.
    밥그릇을 바닥에 두는 eat과 달리 아이콘은 머리 위(상상)에 뜬다.
    """
    my = SPECIES_ART[sp]["mouth"][1]
    n = art_size(sp)
    ix, iy = n - 6, 0  # 밥 상상 아이콘 — 머리 위 오른쪽

    def drool(g):
        ox = _breath_origin(g, my) - 1  # 몸 왼쪽(입 앞) 바로 바깥
        return with_glyph(g, GLYPH_DROOL, ox, my + 1)

    # f1: 힘없이 축 처져 눈 감고 밥을 떠올리기 시작 (말풍선 점 하나)
    f1 = pose(sp, eye="closed", mouth="none", dy=1)
    f1 = with_glyph(f1, [(0, 0)], ix + 1, iy + 4)

    # f2: 더 처지고 밥공기가 떠오름 + 말풍선 꼬리 점 + 침
    f2 = pose(sp, eye="closed", mouth="open", dy=2)
    f2 = with_glyph(f2, [(0, 0), (2, 1)], ix - 2, iy + 3)
    f2 = with_chars(f2, FOOD_THOUGHT, ix, iy)
    f2 = drool(f2)

    # f3: 밥을 보며 눈 뜨고 군침 (반짝) — 아이콘 유지
    f3 = pose(sp, eye="open", mouth="open", dy=1)
    f3 = with_chars(f3, FOOD_THOUGHT, ix, iy)
    f3 = with_glyph(f3, GLYPH_SPARKLE, ix - 3, iy + 1)
    f3 = drool(f3)
    return [f1, f2, f3]


MOTIONS = {
    "walk": motion_walk,
    "eat": motion_eat,
    "sleep": motion_sleep,
    "attack": motion_attack,
    "dodge": motion_dodge,
    "hurt": motion_hurt,
    "angry": motion_angry,
    "joy": motion_joy,
    "hungry": motion_hungry,
}

# ---------------------------------------------------------------------------
# 아트 → 비트마스크 변환 및 Dart 출력
# ---------------------------------------------------------------------------


def art_to_masks(g):
    """아트 그리드 → (dark, body, accent) 행 마스크."""
    n = len(g)
    dark_rows = []
    body_rows = []
    accent_rows = []
    for y in range(n):
        dark = 0
        body = 0
        accent = 0
        for x in range(n):
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
    parts = ["0x%07X" % v for v in rows]
    lines = []
    for i in range(0, len(parts), 8):
        lines.append("      " + ", ".join(parts[i : i + 8]) + ",")
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    for key, meta in SPECIES_ART.items():
        validate(meta["body"], "%s.body" % key)
        # 원본 PNG 색 재샘플링으로 보조색('+') 자동 태깅
        meta["body"] = apply_accent(meta["body"], key)
        # 성장기(28px)는 가장자리가 몸통색으로 끝나 테두리가 빠진 곳이 많아
        # 실루엣을 검은 테두리로 감싼다 (유아기는 원본 테두리가 살아있음)
        if key.endswith("2"):
            meta["body"] = add_outline(meta["body"])

    sprite_frames = {}
    for key in SPECIES_ART:
        motions = {}
        for motion_name, build in MOTIONS.items():
            frames = [art_to_masks(built) for built in build(key)]
            motions[motion_name] = frames
        sprite_frames[key] = motions

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(
            "// GENERATED CODE - DO NOT EDIT BY HAND\n"
            "// tool/generate_motion_data.py 로 재생성:\n"
            "//   python tool/generate_motion_data.py\n"
            "//\n"
            "// 도트 모션 3프레임 — 원본 캐릭터(assets/{종}{1|2}.png)를\n"
            "// 도트 아트(유아기 24x24, 성장기 28x28)로 옮긴 뒤\n"
            "// 다리 교차/표정/호흡을 입힌 데이터.\n"
            "\n"
            "import 'pet_pixel_data.dart';\n"
            "\n"
            "/// 스프라이트 키('{종}{스테이지}') → 모션 이름 → 3프레임 도트\n"
            "const Map<String, Map<String, List<PixelSprite>>> "
            "motionFrames = {\n"
        )
        for key, motions in sprite_frames.items():
            f.write("  '%s': {\n" % key)
            size = art_size(key)
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
                            size,
                            format_rows(dark),
                            format_rows(body),
                            format_rows(accent),
                        )
                    )
                f.write("    ],\n")
            f.write("  },\n")
        f.write("};\n")

    total = sum(len(m) * 3 for m in sprite_frames.values())
    sizes = ", ".join(
        "%s=%d" % (k, art_size(k)) for k in sprite_frames
    )
    print("생성 완료: %s (%d개 프레임, %s)" % (OUTPUT_PATH, total, sizes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
