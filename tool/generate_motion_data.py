# -*- coding: utf-8 -*-
"""도트 모션 생성 — 사용자 원본 캐릭터 기반
(유아기 32 + 성장기 36 + 성숙기 56 + 털뭉치 40).

assets/{종}{1|2}.png 원본 픽셀아트를 도트 아트로 옮긴 뒤(물방울·동전·그림자
제거 등 수작업 정리), 부위별 변형으로 다마고치 방식 모션 3프레임을 만든다:
  - 걷기: 하단 다리 영역을 앞/뒤 절반으로 나눠 교차 스텝
  - 표정: 원본 눈 위치(rect)에 눈 4종(뜸/감음/^^/><) + 눈썹 + 입 벌림
  - 수면: 몸을 눌러 엎드림 + 감은 눈 + 호흡 + Z
  - 공격/회피/아픔: 상단 기울임(lean) + 돌진/젖힘
  - 이펙트 글리프 (Z, 반짝이, 화남, 땀, 속도선, 밥그릇)

아트 소스는 유아기 24·성장기 28이지만 TARGET_SIZE대로 32·36으로 업스케일
한다(눈은 scale_eye로 위치만 스케일+크기 축소). 모든 연산 함수는 len(g)에서
크기를 얻고, 이펙트 좌표는 24 기준값을 우측/하단 앵커로 보정한다.

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

import json
import os
import sys

from PIL import Image

BASE = 24  # 이펙트 글리프 좌표의 기준 그리드 (24 기준값 + 앵커 보정)
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")

# 안드로이드 홈 위젯이 앱과 동일한 도트 모션을 네이티브로 렌더하기 위한 JSON.
# 위젯은 정지 이미지라 모션별 대표 프레임(가운데=index 1) 1장만 내보낸다.
WIDGET_JSON_PATH = os.path.join(
    "android", "app", "src", "main", "assets", "pet_motion_data.json"
)

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
    # 성숙기 (원본 {종}3.png → 52칸 덤프, 56 그리드 배치 — 덤프 파라미터와 동일)
    "dragon3": dict(path="assets/dragon3.png", crop=(0.0, 0.0, 1.0, 0.96),
                    size=(52, 47), off=(2, 6), light=0.75, darkmid=False),
    "tiger3": dict(path="assets/tiger3.png", crop=(0.0, 0.0, 1.0, 0.95),
                   size=(52, 41), off=(2, 12), light=0.80, darkmid=False),
    "bird3": dict(path="assets/bird3.png", crop=(0.0, 0.0, 1.0, 0.97),
                  size=(52, 44), off=(2, 9), light=0.68, darkmid=False),
    "turtle3": dict(path="assets/turtle3.png", crop=(0.0, 0.0, 1.0, 0.95),
                    size=(52, 44), off=(2, 9), light=None, darkmid=True),
    # 털뭉치(stage 1) — 단색 크림이라 보조색 태깅 없이 몸통색 단색으로
    "fluff": dict(path="assets/기본이미지.png", crop=None, size=(24, 24),
                  off=(0, 0), light=None, darkmid=False),
}

# 스테이지별 목표 그리드 크기 (아트 소스 크기와 다르면 업스케일)
# 유아기 24→32, 성장기 28→36. 털뭉치(40)·성숙기(56 덤프)는 그대로.
TARGET_SIZE = {
    "dragon1": 32, "tiger1": 32, "bird1": 32, "turtle1": 32,
    "dragon2": 36, "tiger2": 36, "bird2": 36, "turtle2": 36,
    "dragon3": 56, "tiger3": 56, "bird3": 56, "turtle3": 56,
    "fluff": 40,
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


def upscale_art(art, target):
    """char 그리드를 최근접 이웃으로 target x target 정사각 확대.

    승인된 유아기(24)·성장기(28) 아트를 디자인 변경 없이 32/36으로 키운다.
    실루엣/테두리 위상은 보존되고 일부 행·열이 복제될 뿐이다.
    """
    n = len(art)
    if target == n:
        return [row for row in art]
    out = []
    for ty in range(target):
        sy = ty * n // target
        src = art[sy]
        out.append("".join(src[tx * n // target] for tx in range(target)))
    return out


def scale_point(pt, n, target):
    """입 좌표 (x, y)를 n→target 비율로 스케일."""
    x, y = pt
    return (x * target // n, y * target // n)


def scale_eye(rect, n, target):
    """눈은 위치만 스케일하고 크기는 원본보다 작게 유지.

    업스케일 비율로 눈을 통째로 키우면 큰 검은 블록이 돼 무섭다. 또 원본
    눈 자체가 살짝 크므로 중심만 새 그리드로 옮기고 폭·높이는 ~0.7배로
    줄여(최소 2) 더 작고 귀엽게 만든다.
    """
    x, y, w, h = rect
    cx = (x + w / 2.0) * target / n
    cy = (y + h / 2.0) * target / n
    nw = max(2, int(round(w * 0.7)))
    nh = max(2, int(round(h * 0.7)))
    nx = int(round(cx - nw / 2.0))
    ny = int(round(cy - nh / 2.0))
    return (nx, ny, nw, nh)


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


def draw_eye(g, rect, style, group_cx=None, frontal=True):
    """rect=(x, y, w, h) 영역에 눈 스타일을 그림.

    happy/pain/angry는 획이 성글어 작은 눈(2x2)에선 안 보이므로 최소 3x3로
    키우고(중앙 정렬) 주변 줄무늬를 정리한 뒤 획을 굵게 그린다.
    open/closed는 면을 채워 작아도 보이므로 원본 크기 그대로 둔다.
    """
    x, y, w, h = rect
    n = len(g)
    # 표정 최소 크기는 그리드에 비례 — 32그리드의 3px 비율을 유지해
    # 성숙기(56)에서도 ^ / X 가 또렷하게 보이도록 키운다.
    min_dim = 5 if n >= 48 else 3
    if style in ("happy", "pain", "angry"):
        pw, ph = max(w, min_dim), max(h, min_dim)
        ex = x - (pw - w) // 2
        ey = y - (ph - h) // 2
        # 작은 눈(2x2)·큰 그리드(덤프 노이즈 아트)는 주변을 2px까지 넓게 정리
        halo = 2 if min(w, h) <= 2 or n >= 48 else 1
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
        # 큰 눈(털뭉치): 타원 눈망울 + 반짝이로 촉촉하게 (작은 눈은 뭉개지므로 제외).
        if pw >= 6 and ph >= 7:
            # 36 그리드 큰 눈 — 사각 채움을 타원으로 깎고 큰/작은 하이라이트 2점
            cx0, cy0 = (pw - 1) / 2.0, (ph - 1) / 2.0
            for dy in range(ph):
                for dx in range(pw):
                    nx = (dx - cx0) / (pw / 2.0)
                    ny = (dy - cy0) / (ph / 2.0)
                    if nx * nx + ny * ny > 1.0:
                        put(g, ex + dx, ey + dy, "o")  # 타원 밖은 몸통색
            for hy in range(1, 4):  # 왼쪽 위 큰 반짝이
                for hx in range(2, 4):
                    put(g, ex + hx, ey + hy, "o")
            put(g, ex + pw - 3, ey + ph - 4, "o")  # 오른쪽 아래 작은 반짝이
            put(g, ex + pw - 4, ey + ph - 4, "o")
        elif pw >= 5 and ph >= 5:
            for cx, cy in ((0, 0), (pw - 1, 0), (0, ph - 1), (pw - 1, ph - 1)):
                put(g, ex + cx, ey + cy, "o")
            put(g, ex + 1, ey + 1, "o")
            put(g, ex + 2, ey + 1, "o")
    elif style == "closed":  # 감은 눈 — 가운데 가로 실선 '-' (모든 캐릭터 공통)
        lw = max(pw, min_dim)
        lx = ex - (lw - pw) // 2
        ly = ey + ph // 2
        halo = 2 if min(pw, ph) <= 2 or n >= 48 else 1
        _clear_eye_box(g, lx, ly - 1, lw, 3, halo=halo)
        for dx in range(lw):
            put(g, lx + dx, ly, "#")
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
    elif style == "angry":  # 화난 눈 — 안쪽이 처진 사선
        # 정면 얼굴(frontal): 눈 그룹 중심으로 왼/오른을 나눠 왼눈 \, 오른눈 /.
        # 옆모습(주작·청룡·현무): 앞쪽(왼쪽)이 아래로 처진 / 로 통일(눈 개수 무관).
        ec = ex + pw / 2.0
        ref = group_cx if group_cx is not None else len(g) / 2.0
        if frontal:
            side = "left" if ec < ref - 0.5 else ("right" if ec > ref + 0.5 else "single")
        else:
            side = "right"  # / 로 통일
        mid = (pw - 1) / 2.0
        for dx in range(pw):
            t = dx / (pw - 1) if pw > 1 else 0.0
            if side == "left":
                frac = t              # \  : 안쪽(오른쪽) 아래
            elif side == "right":
                frac = 1.0 - t        # /  : 앞쪽(왼쪽) 아래
            else:
                frac = 1.0 - abs(dx - mid) / mid if mid > 0 else 1.0  # \/ 가운데 처짐
            yy = ey + int(round(frac * (ph - 1)))
            put(g, ex + dx, yy, "#")
            if yy + 1 < ey + ph:
                put(g, ex + dx, yy + 1, "#")


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
            "..#o#oooooooooooo##.....",
            "..###oooooooooooo#......",
            "..#oooooooooooooo#....##",
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
        "eyes": [(10, 10, 4, 4)],
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
            "..##oooooooooo###.......",
            "..##ooooooooooo##o......",
            ".#oooooooooooo##o.......",
            "..####ooooooo####.......",
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
        "eyes": [(8, 11, 4, 4)],
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
            "#ooooooooooo##########..",
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
    # 털뭉치(stage 1) — 아기 같은 동글동글 크림 뭉치 + 뾰족 귀(정적 이미지와
    # 동일한 실루엣 — 귀가 없으면 머리가 잘린 것처럼 보인다) + 큰 두 눈 + 작은 입
    "fluff": {
        "body": [
            "........................................",
            "........................................",
            "........................................",
            "........................................",
            "...........oo..............oo...........",
            "..........oooo............oooo..........",
            "..........oooo............oooo..........",
            "..........oooo............oooo..........",
            "..........oooo..oooooooo..oooo..........",
            ".........oooooooooooooooooooooo.........",
            ".........oooooooooooooooooooooo.........",
            ".........oooooooooooooooooooooo.........",
            "........oooooooooooooooooooooooo........",
            "......oooooooooooooooooooooooooooo......",
            "......oooooooooooooooooooooooooooo......",
            ".....oooooooooooooooooooooooooooooo.....",
            "....oooooooooooooooooooooooooooooooo....",
            "....oooooooooooooooooooooooooooooooo....",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooooooooooooooooooooooooooooooo...",
            "...oooooo++++oooooooooooooo++++oooooo...",
            "...ooooo++++++oooooooooooo++++++ooooo...",
            "...oooooo++++oo#ooo#ooo#ooo++++oooooo...",
            "...ooooooooooooo#o#o#o#oooooooooooooo...",
            "....ooooooooooooo#ooo#oooooooooooooo....",
            "....oooooooooooooooooooooooooooooooo....",
            ".....oooooooooooooooooooooooooooooo.....",
            "......oooooooooooooooooooooooooooo......",
            ".......oooooooooooooooooooooooooo.......",
            "........oooooooooooooooooooooooo........",
            ".........oooooooooooooooooooooo.........",
            "............oooooooooooooooo............",
            "...............oooooooooo...............",
            "........................................",
            "........................................",
        ],
        "eyes": [(10, 18, 6, 7), (24, 18, 6, 7)],
        "mouth": (18, 28),
    },
    # 성숙기 백호 — 원본 tiger3.png 덤프(52×41) · 왼쪽 얼굴, 줄무늬, 말린 꼬리
    "tiger3": {
        "body": [
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            ".....###o..........###..................................",
            ".....ooo##.######.oooo#.................................",
            "....#oooooooo#ooo#oooo#o................................",
            "....#ooooooooooooooooo#o................................",
            "....#ooooooooooooooooo#o................................",
            "....oooooooooooooooooooo................................",
            "....#oooooooooooooooooo#................................",
            "....ooooooooooooooooooo#................................",
            "....ooooooooooooooooooo#................................",
            "....ooooooooooooooooooo#o...............................",
            "...#ooooooooooooooooooooo#..............................",
            "...#ooooooooooooooooooooo#..............................",
            "...#oooooooooooooooo#ooo#o..............................",
            "..#oo#oooo#oooooooooooooo#..............................",
            "...#ooooo###oooooooooooo#o..............................",
            "...ooooooooooooooooooooo#.......######..................",
            "...##ooooooooooooooooooo########oo#ooo##................",
            "....##ooooooooooooooooooooo#ooooooo#oo#o##..............",
            ".....##ooooooooooooo###oooo#ooo#oooooo#oo##.............",
            "......#ooooooooooooooooooooo#ooo#ooo#ooooo##............",
            "......#oooooooooooooooooo#oo#ooo#ooooooooo#o#...........",
            "......##ooooooooooooooooo#oo#ooo#ooooooooo#o#...........",
            ".......ooooooooo##oooooo#ooooooo#oooooooooo#o#..........",
            ".......oooooooo##ooooooo#ooooooo#oooooooooo#o#..........",
            ".......#oooooo#ooooooooooooooooo#oooooooooo###..........",
            ".......#ooooooooooooooooooooooo#oooooooooo##o#o.........",
            ".......#ooooooooooooooooooooooooooooooooo#o#ooo.........",
            "........#oooooooooooooooooooooooooooooooooo####.........",
            "........#ooooooooooooooooooooooooooooooooooo#o#...###...",
            ".........#ooooooooooooooooooooooooooooooooo#oo#o.##o#o..",
            "..........#ooooooooooooooo#oooooo#ooooooooo#oo#oo#oo#o..",
            "..........#ooooooooooo#ooo#ooooo###oooooooo###oo##oo#...",
            "...........#oooooo#o##oooo#######o##ooooo#oo#oo#oooo#...",
            "...........o####o##ooooooo#ooo#ooooooooooooo#ooooooo....",
            "...........oooooo##ooo#oo##...#oooo##oooo.ooo##oo##.....",
            "...........#ooooo##oooooo#....o####oo##.....o####o......",
            "...........#oooooo#oooooo#.....#ooooo#o#....o#o.........",
            "...........#oooo###ooooo#o....#oooooo#ooo...ooo.........",
            "..........oooooo#ooooooo#....#oooooooo#oooooooo.........",
            ".........#ooooo#ooooooooooooo########o#oooooo#o.o.......",
            "........ooo#####o#o#oo##ooooooooooooo##o#o#oo#oooo......",
            "........................................................",
            "........................................................",
            "........................................................",
        ],
        "eyes": [(4, 20, 3, 3), (14, 20, 3, 3)],
        "mouth": (9, 25),
    },
    # 성숙기 주작 — 원본 bird3.png 덤프(52×44) · 활짝 편 양 날개, 볏, 불꽃 꼬리
    "bird3": {
        "body": [
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            ".....#...........................................##.....",
            "....#o#o........................................oo#.....",
            "....#oo#.......................................#ooo.....",
            "....#ooo#....................................#oooo#.....",
            "....o#ooo#o.................................#oooooo.....",
            "...###oooo###..............................#oooo##o###..",
            "..#oo##oooo####.........................###ooooo#oooo#..",
            "..#ooo#oooo#####.......................####ooooooooo#o..",
            "..##ooooooo##o##..........oo...........#o##oooooooo#o...",
            "...o#oooooo##oo#.........#ooooo.......##oo##oooooo###...",
            "..####ooooo#ooo##......##oooooo.......#oo##oooooo##o##..",
            "..#oooooooo##oo##......oo##oo#ooo....#oo##oooooooooo#o..",
            "...#oooooo#o##o##.....####oo#ooo#....#oo#oo#ooooooo#o...",
            "....#ooooo#ooooo#.....###oo#o##o.....#oooo##oooooo#o....",
            "....##oooooooooo##...#oooo####oo.....#ooo##oooooo####...",
            "...####oooo###oo##..##ooooooo####...#ooo####oooooooo#...",
            "...##oooooo#oooo##..##ooooooo###o...#ooooo#oooooooo#....",
            "....###ooo####oo##..#oooooooo##o....#ooo####ooo###o.....",
            ".....o###oo###ooo#.#ooooooooo##.....#ooo####ooo###......",
            "......oooooo###oo##o###oooooo##....#ooo####oooooo##.....",
            "......#ooooo#####o#oo##ooooo###...#ooo######ooooo#......",
            ".......##########oo#o#ooooooo#o.##ooo###########o.......",
            "........o##oo######o##ooooooo###ooo#######ooooo#o.......",
            "........#ooo##########oooooooo#oooo########ooo#o........",
            ".........#####o######oooooooooooo######oo#####o.........",
            "...........##oo#####ooooooooooooo######ooo###...........",
            "...........#oo######ooooooooooo######o###ooo##..........",
            "............####o###oooooooooooo#####oo#####o...........",
            "..............#oo###ooooooooooo####o###oo#o.............",
            "..............####o#ooooooooooo#####o#o##o.....#o.o.....",
            ".................###ooooooooooo###o###o.....#o##ooo.....",
            "....................#ooooooooooo###o......#####oooo.....",
            "....................#oooooooooooo####...##o##ooooo......",
            "....................##ooooooo#o#############ooooooooo...",
            ".....................####o############oooooo##ooooooo...",
            "......................######################oooooooo....",
            "......................####################ooooooooo.....",
            ".......................##########o#o##ooooooooooooo.....",
            "........................###...###..##o#oooooooooooo.....",
            ".......................###....#o#...o#o########..o......",
            "....................####o#....#o#.....o##o##............",
            ".................o####oo##ooo##o##ooooo.................",
            "...............ooo###oo##oooo##o#o#ooooooo..............",
            "................ooooo##oooo####o###oooooo...............",
            "........................................................",
            "........................................................",
            "........................................................",
        ],
        "eyes": [(24, 26, 3, 3)],
        "mouth": (20, 26),
        "wings": [(2, 9, 18, 32, "right"), (36, 9, 53, 36, "left")],
    },
    # 성숙기 현무 — 원본 turtle3.png 덤프(52×44) · 등딱지+뱀, 거북 머리 왼쪽
    "turtle3": {
        "body": [
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "......................########..........................",
            "....................##ooooooo###........................",
            "..................##ooooooooooo##.......................",
            "................##oooooo#oooooooo##.....................",
            "...............#oooooooooooooooooo##....................",
            "..............#oooooooooooooo#oooooo#...................",
            "..............#ooooooooooooo#oooooo##...................",
            "..............#ooooooooooooooooooooo##..................",
            "..............#o##ooooooooo##oooooooo#..................",
            "..............##oooooooo###o##ooooooo#..................",
            "...............o#########....#oooooooo#.................",
            "..............##o.............#ooooooo#.................",
            "..............#..............#oooooo###.................",
            "............###..............oooooo#o#..................",
            "............###............#ooooooo##o..................",
            ".............o#...........#ooooooooo#...................",
            "........................ooooooooo#o##...................",
            ".......................ooooooooooo##....................",
            "......................#ooooooo####......................",
            "....................##oooooo######..........o..####.....",
            "...................##oooooo#########.......###ooooo#....",
            ".......#####.....#####oooo############....#o#ooooooo#...",
            ".....#oooooo##..####oo#################...#ooooo##oo##..",
            "...##oooooooo######oooo##ooo###########o...ooooooo###o..",
            "...#oooooooooo######oo###o##o########oo#...#ooooooo##o..",
            "...#ooooooooooo#################oo####o##...#oooo#oo##..",
            "..#oooooooooooo##################oo#######...##o#o####..",
            "..#oooooooooooo###################o#######o...#o###o##..",
            "..#oo#ooooooooo########o#o#################...#oo#......",
            "...#o#oooooooooo#########o#################.#oo#o#......",
            "...#ooooooooooooo#oo###########oo####o######oo#o#o......",
            "....###oooooooooo##oo########oo#############o#ooo.......",
            "......o###ooooo#o##ooo########oo#############ooo#.......",
            ".........ooooooo#o###ooo###################o##o#........",
            ".........oooooooooo###ooo#################oo###.........",
            ".........oooooooooo#####ooo##############oo##o..........",
            ".........#ooooooooo#o####ooooo#o####ooooo#####..........",
            "........###ooooooo#ooo######ooooooooooo#####o#..........",
            "........#o##ooooooooooo##################oooo#o.........",
            "........#ooo##oooo#oooooo############o###ooooo#.........",
            "........oooo########ooooo############oo#oooooo#.........",
            ".......#ooooo##...#oooooo##oo#ooooo##oo#oooooo##........",
            ".......oooooo#o.oo#oooooo##oo#######ooo#oooooo##........",
            "......o#######o.o.#oooooo##ooooooooooooo#######oo.......",
            "........................................................",
            "........................................................",
            "........................................................",
        ],
        "eyes": [(10, 34, 3, 3), (21, 14, 3, 3)],
        "mouth": (4, 37),
    },
    # 성숙기 청룡 — 원본 dragon3.png 덤프(52×47) · 뿔·여의주·S자 몸통·꼬리 지느러미
    "dragon3": {
        "body": [
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
            ".....................##........##.......................",
            "....................#oo#....##.oo#......................",
            "....................#oo#....oo#oo#......................",
            "....................#oo#....oooo#.......................",
            ".................#o#oo#o#o##ooo#........................",
            ".................#oooo##oo#ooo#o#.......................",
            "..................#oo####ooo##o#####....................",
            ".................##oooo#ooo#ooo#ooo#....................",
            ".................##ooooooo#ooo#ooo##....................",
            "................o#oooo##o#oo##ooo####...................",
            "................ooooooo##oooooo##oooo#..................",
            "...............#oooooooooooooo#ooooo#...................",
            "...............#oooooooooooooo..ooo##...................",
            "...............#oooooooooooo..ooooo#....................",
            "...............##oooooooooooooo#oooo#...................",
            "...............#ooooooooooooo...oooo#...................",
            "..............##oooooooooo.....oooo##...................",
            "..............#ooo#o..oo....ooooo###....................",
            "..............#oooooo....#...##oooo#....................",
            "....oooo#......#oooooooooo##..#ooo##....................",
            "...oooooo.......#####oooooooooo###.............##.......",
            "..#oooooo#.........#ooooooo#o#oooooo.......##.#oo#......",
            "..#oooooo#........#oooooooooooo####......##oo##ooo##....",
            "..#oooooo#........ooooooooo#ooo#........oooooooooooo#...",
            "...#ooooo#......#oooooooooo#oo##......#ooooooooooooo#...",
            "...##ooo###....#oooooooooo#oo#.......#oooooooo#ooooo#...",
            "....####oo#...#ooooooooooo#oo#........####oooooooooo#...",
            "....ooo#o#...#ooooooooooo####..##..##....##ooooooooo#...",
            ".....#o#o##..ooooooooooo##o#..#o###oo###...##oooooooo#..",
            "......##oo##ooooooooooo####..#ooooo##ooo#....######oo#..",
            ".......#ooo#oooooooooo##...##oo#oooooo####.......####...",
            ".......#oo#ooooooooooo##..#oo#oooooooooo###.......###...",
            "........###oooooooooo##..##ooooooooooooooo##......#o#...",
            "........##ooooooooooo######oooooooooo#oooo###....#oo#...",
            ".........#ooooooooooo#####ooooooooooooooooo###..##oo#...",
            ".........#oooooooooooo##oooooooo#oooooooooo######oo##...",
            "..........#ooooooooooooooooooo#oooo#ooooooooooooo##o....",
            "..........#oooooooooooooooooooooo###ooooooooooooo#oo....",
            "...........#ooooooooooooooo###oo#...##oooooo####ooo#....",
            "...........#ooooooooooooooo#ooo#.....#oooooooooooo#.....",
            "........oooo#ooooooooo####ooo##ooooooo##oooooooo##o.....",
            ".....oooooooo##ooooooooooooo#ooooooooooo########oooo....",
            "......oooooooooo###########oooooooooooooooooooooooo.....",
            ".........ooooooooooooooooooooooooooooooo................",
            "........................................................",
            "........................................................",
            "........................................................",
            "........................................................",
        ],
        "eyes": [(22, 22, 3, 3)],
        "mouth": (16, 21),
    },
}

# ---------------------------------------------------------------------------
# 일반종(normal 성숙기) — 사신수 '{종}3' 아트에서 신수 요소만 제거한 변형.
# "모두가 사신수가 되진 않는다": 잘 못 키우면 그냥 새/뱀/호랑이/거북이 된다.
# 형태 = 신수 요소 제거, 색 = 앱에서 자연색 팔레트로 주입(SpeciesTheme.naturalDot).
# ---------------------------------------------------------------------------

# 제거할 신수 요소 영역 (x0, y0, x1, y1 — 포함). 비면 형태 동일(색만 다름).
NORMAL_STRIP = {
    # 성장기(stage3) — 효과가 작아 대부분 색만, 청룡 여의주·현무 뱀 제거
    "dragon2": [(20, 10, 28, 22)],                   # 이무기 여의주 제거
    "turtle2": [(13, 6, 27, 12), (20, 12, 27, 27)],  # 등 뒤 뱀(머리·목·꼬리) 제거
    "bird2": [], "tiger2": [],
    # 성숙기(stage4) — 신수 요소 뚜렷
    "turtle3": [(9, 6, 42, 24), (39, 24, 55, 37), (42, 37, 55, 45)],  # 등 뒤 뱀 제거
    "dragon3": [(0, 24, 11, 43)],                    # 왼손 여의주 + 팔 제거
    # 황룡 일반종 — dragon과 동일 스트립 (여의주 제거)
    "hwangryong2": [(20, 10, 28, 22)],
    "hwangryong3": [(0, 24, 11, 43)],
    "bird3": [(13, 47, 43, 55)],                     # 하단 불꽃 꼬리 제거
    "tiger3": [],                                    # 형태 동일 (색만)
}
# 일반종에서 빼는 눈(신수 부속의 눈) 인덱스
NORMAL_DROP_EYES = {"turtle2": {1}, "turtle3": {1}}  # 뱀 눈 제거


# ---------------------------------------------------------------------------
# 설화 영물(히든 종) 아트 — 레퍼런스 컨셉아트에서 추출 (tool/dump_reference_art.py).
# 프로그램 파생(과거 tiger/dragon 몸통 편집)은 실제 형태와 안 맞아 폐기.
# 색은 3계조로 이미 태깅돼 SPECIES_SRC(PNG 재샘플링) 불필요 —
# 'o'는 런타임에 종 테마색으로 렌더된다(기존 백호=청회색과 동일한 스타일화).
# ---------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hidden_species_art import HIDDEN_ART  # noqa: E402

for _k, _v in HIDDEN_ART.items():
    SPECIES_ART[_k] = {
        "body": list(_v["body"]),
        "eyes": [tuple(e) for e in _v["eyes"]],
        "mouth": tuple(_v["mouth"]),
    }
    TARGET_SIZE[_k] = len(_v["body"])


def _make_normal_forms():
    """사신수/신수 아트에서 신수 요소를 제거한 '{종}2n'·'{종}3n' 일반종 아트 파생."""
    bases = ("tiger2", "bird2", "turtle2", "dragon2",
             "tiger3", "bird3", "turtle3", "dragon3",
             # 히든 종 — 신수 요소 스트립 없음(색만 다른 일반종 라인)
             "samjoko2", "samjoko3", "gumiho2", "gumiho3",
             "moonrabbit2", "moonrabbit3", "haetae2", "haetae3",
             "dokkaebi2", "dokkaebi3", "hwangryong2", "hwangryong3")
    for base in bases:
        src = SPECIES_ART[base]
        n = len(src["body"])
        body = [list(r) for r in src["body"]]
        for x0, y0, x1, y1 in NORMAL_STRIP.get(base, []):
            for y in range(max(0, y0), min(n, y1 + 1)):
                for x in range(max(0, x0), min(n, x1 + 1)):
                    body[y][x] = "."
        drop = NORMAL_DROP_EYES.get(base, set())
        eyes = [e for i, e in enumerate(src["eyes"]) if i not in drop]
        key = base + "n"  # tiger3 → tiger3n, tiger2 → tiger2n
        SPECIES_ART[key] = {
            "body": ["".join(r) for r in body],
            "eyes": eyes,
            "mouth": src["mouth"],
        }
        if "wings" in src:
            SPECIES_ART[key]["wings"] = src["wings"]
        if base in SPECIES_SRC:  # 재샘플링 없는 히든 종은 건너뜀
            SPECIES_SRC[key] = SPECIES_SRC[base]  # 같은 PNG로 보조색 자동 태깅
        TARGET_SIZE[key] = TARGET_SIZE[base]


_make_normal_forms()

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


def flap_wings(g, wings, amount):
    """날개를 전단(shear)으로 퍼덕임 — 몸쪽 고정, 바깥일수록 크게 이동.

    wings: [(x0, y0, x1, y1, inner)] — inner는 몸에 붙은 쪽('left'/'right').
    amount < 0 위로, > 0 아래로. 열마다 이동량이 점진적이라 찢김이 없다.
    (주작 성숙기처럼 날개를 편 아트가 '고정된 날개'로 보이지 않게 한다)
    """
    if not amount:
        return g
    n = len(g)
    out = [["."] * n for _ in range(n)]
    moved = [[False] * n for _ in range(n)]
    for x0, y0, x1, y1, inner in wings:
        span = max(1, x1 - x0)
        for x in range(max(0, x0), min(n, x1 + 1)):
            dist = (x1 - x) / span if inner == "right" else (x - x0) / span
            dy = round(amount * dist)
            for y in range(max(0, y0), min(n, y1 + 1)):
                if g[y][x] != ".":
                    ny = y + dy
                    if 0 <= ny < n:
                        out[ny][x] = g[y][x]
                    moved[y][x] = True
    for y in range(n):
        for x in range(n):
            if not moved[y][x] and g[y][x] != "." and out[y][x] == ".":
                out[y][x] = g[y][x]
    return out


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
    # 화난/사선 눈의 좌우 판별 기준은 그리드 중심이 아니라 눈 그룹 중심
    # (캐릭터마다 눈이 한쪽으로 치우쳐 있어 그리드 중심을 쓰면 좌우가 틀림).
    eye_rects = meta["eyes"]
    group_cx = sum(x + w / 2.0 for (x, y, w, h) in eye_rects) / len(eye_rects)
    # 정면 얼굴(백호·털뭉치)은 화난 눈을 \ / 로, 옆모습(주작·청룡·현무 — 왼쪽을
    # 봐 앞쪽이 왼쪽)은 항상 / 로 그린다.
    frontal = key.startswith("tiger") or key == "fluff"
    for rect in eye_rects:
        draw_eye(g, rect, eye, group_cx=group_cx, frontal=frontal)
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

    # 날개 플랩 — wings 메타가 있는 종(주작 성숙기)은 스텝과 함께
    # 날개를 퍼덕여 '펼친 채 고정'으로 보이지 않게 한다
    if meta.get("wings") and step:
        amount = {"front": -2, "back": 2, "both_up": -3}[step]
        g = flap_wings(g, meta["wings"], amount)

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
    # 눌린 좌표계에서 감은 눈 '-' 다시 그림 (주변 정리로 노이즈에 안 묻히게)
    for x, y, w, h in meta["eyes"]:
        ny = y1 - int(round((y1 - (y + h - 1)) * factor))
        lw = max(w, 5 if len(squashed) >= 48 else 3)
        lx = x - (lw - w) // 2
        _clear_eye_box(squashed, lx, ny - 1, lw, 3, halo=1)
        for dx in range(lw):
            put(squashed, lx + dx, ny, "#")
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
    """걷기: 앞다리 내딛기 → 양발 서기 → 뒷다리 내딛기.

    털뭉치(fluff)는 다리가 없으므로 다리 스텝 대신 통통 튀며 이동한다:
    웅크림 → 눈웃음으로 폴짝(위로) → 착지하며 살짝 납작(squash).
    """
    if sp == "fluff":
        crouch = squash_art(pose(sp, eye="open"), 0.92)
        hop = pose(sp, eye="happy", mouth="open", dy=-1)
        land = squash_art(pose(sp, eye="open"), 0.84)
        return [crouch, hop, land]
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
    # 털뭉치는 다리가 없어 스텝 대신 몸통을 웅크렸다(눌림) 앞으로 내민다.
    # 몸집이 40그리드를 꽉 채워 큰 dx는 볼·귀가 화면 밖으로 잘리므로 이동폭 축소.
    legs = sp != "fluff"
    back = 2 if sp == "fluff" else 5
    fwd = 2 if sp == "fluff" else 4
    lw = 0 if sp == "fluff" else 1
    windup = pose(sp, eye="angry", mouth="none", dx=back, lean=lw)
    if not legs:
        windup = squash_art(windup, 0.9)
    puff = pose(sp, eye="angry", mouth="open",
                step="front" if legs else None, dx=fwd, lean=-lw)
    puff = draw_breath_puff(puff, sp)
    blast = pose(sp, eye="angry", mouth="open",
                 step="back" if legs else None, dx=fwd, lean=-lw)
    blast = draw_breath_ball(blast, sp)
    return [windup, puff, blast]


def motion_dodge(sp):
    """움찔 → 뒤로 크게 젖히며 물러남(속도선) → 복귀.

    털뭉치는 다리가 없어 스텝 대신 몸 전체가 옆으로 젖혀 피한다.
    """
    r = art_size(sp) - BASE
    legs = sp != "fluff"
    # 털뭉치는 몸집이 커 큰 이동은 화면 밖으로 잘리므로 이동폭을 줄인다
    f2 = pose(sp, eye="closed", step="back" if legs else None,
              dx=2 if sp == "fluff" else 3, lean=0 if sp == "fluff" else 1)
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
    # 털뭉치는 몸집이 커 큰 lean/dx는 볼·귀가 화면 밖으로 잘리므로 휘청폭 축소.
    r = art_size(sp) - BASE
    big = sp != "fluff"
    f1 = pose(sp, eye="pain", mouth="open", lean=1)
    f1 = with_glyph(f1, GLYPH_SWEAT, 19 + r, 1)
    f2 = pose(sp, eye="pain", mouth="open",
              dx=1 if big else 0, lean=2 if big else 1)
    f2 = with_glyph(f2, GLYPH_SWEAT, 21 + r, 2)
    f2 = with_glyph(f2, GLYPH_SWEAT, 18 + r, 0)
    f3 = pose(sp, eye="pain", dx=-1)
    f3 = with_glyph(f3, GLYPH_SWEAT, 17 + r, 1)
    return [f1, f2, f3]


def motion_angry(sp):
    """부릅뜬 눈 + 입 벌려 씩씩 + 💢.

    다리 있는 종은 쿵쿵 발 구르기, 털뭉치는 다리가 없어 좌우로 부르르 떤다.
    """
    r = art_size(sp) - BASE
    if sp == "fluff":
        f1 = pose(sp, eye="angry", mouth="open", lean=-1)
        f1 = with_glyph(f1, GLYPH_ANGER, 18 + r, 3)
        f2 = pose(sp, eye="angry")
        f2 = with_glyph(f2, GLYPH_ANGER, 17 + r, 2)
        f3 = pose(sp, eye="angry", mouth="open", lean=1)
        f3 = with_glyph(f3, GLYPH_ANGER, 19 + r, 4)
        return [f1, f2, f3]
    f1 = pose(sp, eye="angry", mouth="open", step="front")
    f1 = with_glyph(f1, GLYPH_ANGER, 18 + r, 3)
    f2 = pose(sp, eye="angry", dx=1)
    f2 = with_glyph(f2, GLYPH_ANGER, 17 + r, 2)
    f3 = pose(sp, eye="angry", mouth="open", step="back")
    f3 = with_glyph(f3, GLYPH_ANGER, 19 + r, 4)
    return [f1, f2, f3]


def motion_joy(sp):
    """^^ 눈으로 살짝 숙였다 점프 → 착지, 반짝이.

    다리 있는 종은 다리를 웅크려 점프, 털뭉치는 몸 전체가 납작 웅크렸다
    통째로 솟았다 착지한다(다리 없음).
    """
    r = art_size(sp) - BASE
    if sp == "fluff":
        crouch = squash_art(pose(sp, eye="happy"), 0.9)
        airborne = pose(sp, eye="happy", mouth="open", dy=-2)
        landing = squash_art(pose(sp, eye="happy", mouth="open"), 0.85)
    else:
        crouch = pose(sp, eye="happy", dy=1)
        airborne = lift_art(
            pose(sp, eye="happy", mouth="open", step="both_up"), 3)
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


def format_rows(rows, n):
    hex_width = (n + 3) // 4  # 그리드 크기에 맞춘 hex 자릿수 (32→8, 36→9)
    parts = ["0x%0*X" % (hex_width, v) for v in rows]
    lines = []
    for i in range(0, len(parts), 8):
        lines.append("      " + ", ".join(parts[i : i + 8]) + ",")
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    for key, meta in SPECIES_ART.items():
        validate(meta["body"], "%s.body" % key)
        # 원본 PNG 색 재샘플링으로 보조색('+') 자동 태깅
        # (성숙기 '{종}3'는 아트에 '+'를 직접 박아 SPECIES_SRC가 없다)
        if key in SPECIES_SRC:
            meta["body"] = apply_accent(meta["body"], key)
        # 승인된 유아기(24)·성장기(28) 아트를 32/36으로 업스케일 (디자인 유지)
        # 눈은 scale_eye로 위치만 옮기고 크기는 줄여(무섭지 않게), 입은 비율 스케일
        src_n = len(meta["body"])
        target = TARGET_SIZE.get(key, src_n)
        if target != src_n:
            meta["body"] = upscale_art(meta["body"], target)
            meta["eyes"] = [scale_eye(r, src_n, target) for r in meta["eyes"]]
            meta["mouth"] = scale_point(meta["mouth"], src_n, target)
        # 성장기(28px)·성숙기(56 덤프)·털뭉치는 가장자리가 몸통색으로 끝나
        # 테두리가 빠지므로 실루엣을 검은 테두리로 감싼다
        # (유아기는 원본 테두리가 살아있음)
        if key.endswith(("2", "3", "n")) or key == "fluff":
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
            "// 도트 아트로 옮긴 뒤 32(유아기)·36(성장기)·24(털뭉치) 그리드로\n"
            "// 업스케일하고 다리 교차/표정/호흡을 입힌 데이터.\n"
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
                            format_rows(dark, size),
                            format_rows(body, size),
                            format_rows(accent, size),
                        )
                    )
                f.write("    ],\n")
            f.write("  },\n")
        f.write("};\n")

    write_widget_json(sprite_frames)

    total = sum(len(m) * 3 for m in sprite_frames.values())
    sizes = ", ".join(
        "%s=%d" % (k, art_size(k)) for k in sprite_frames
    )
    print("생성 완료: %s (%d개 프레임, %s)" % (OUTPUT_PATH, total, sizes))
    print("위젯 JSON: %s" % WIDGET_JSON_PATH)
    return 0


def write_widget_json(sprite_frames):
    """홈 위젯용 모션 JSON — 스프라이트 키 → 모션 → 프레임 3장 전부.

    앱(pet_motion_data.dart)과 동일한 좌표. 위젯은 RemoteViews ViewFlipper로
    프레임을 순환 재생하므로 모션별 전 프레임("f" 배열)을 담는다.
    행 마스크는 부호없는 hex 문자열.
    """
    root = {}
    for key, motions in sprite_frames.items():
        size = art_size(key)
        entry = {"size": size}
        for motion_name, frames in motions.items():
            entry[motion_name] = {
                "f": [
                    {
                        "d": ["%X" % v for v in dark],
                        "b": ["%X" % v for v in body],
                        "a": ["%X" % v for v in accent],
                    }
                    for dark, body, accent in frames
                ]
            }
        root[key] = entry
    os.makedirs(os.path.dirname(WIDGET_JSON_PATH), exist_ok=True)
    with open(WIDGET_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(root, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    sys.exit(main())
