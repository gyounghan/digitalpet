# -*- coding: utf-8 -*-
"""레퍼런스 이미지(설화 영물 마커 아트)에서 도트 아트를 추출.

각 레퍼런스(tool/refs/{종}_눈입.png — APK 번들 제외를 위해 assets/ 밖)는
3스테이지(유아기·성장기·성숙기)가
좌→우로 나열돼 있고, 사용자가 눈=마젠타(#FF00FF)·입=시안(#00FFFF) 마커를
직접 찍어 두었다. 실루엣과 눈/입 좌표가 같은 이미지에서 나오므로
자동 눈 검출의 오검출·잔상 문제가 원천적으로 없다.

처리 순서 (스테이지별):
  1. 연결요소 분석으로 3마리를 분리 → 본체(최대 컴포넌트)만 크롭
     (범례 스와치·라벨 텍스트·떠 있는 장식은 자동 제외)
  2. 마커 픽셀을 주변 캐릭터 색으로 메꿔 잔상 제거 (inpaint)
  3. 목표 격자로 축소 → 종 고정 5색 팔레트로 양자화
  4. 마커 마스크를 같은 변환으로 축소해 눈 rect·입 좌표 산출

출력: tool/hidden_species_art.py  (HIDDEN_ART / HIDDEN_PALETTE)
사용: python tool/dump_reference_art.py
"""

import os
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2

# 종 → (경로, 좌우반전 여부). 게임 펫은 전부 왼쪽을 본다(사신수와 통일).
# 마커 레퍼런스는 전부 왼쪽을 보고 그려져 반전 불필요.
SPECIES = {
    "samjoko": ("tool/refs/삼족오_눈입.png", False),
    "gumiho": ("tool/refs/구미호_눈입.png", False),
    "moonrabbit": ("tool/refs/달토기_눈입.png", False),
    "haetae": ("tool/refs/해테_눈입.png", False),
    "dokkaebi": ("tool/refs/도깨비_눈입.png", False),
    "hwangryong": ("tool/refs/황룡_눈입.png", False),
    # 동물 영물(2차) — 전부 왼쪽을 봄(반전 불필요)
    "bear": ("tool/refs/곰_눈입.png", False),
    "otter": ("tool/refs/수달_눈입.png", False),
    "owl": ("tool/refs/수리부엉이_눈입.png", False),
    "crane": ("tool/refs/두루미_눈입.png", False),
}

# 스테이지별 목표 격자 (유아기 32 / 성장기 36 / 성숙기 56 — 기존 규칙)
STAGE_SIZES = [32, 36, 56]

# 종별 얼굴(눈) 대략 위치 (fx, fy) 0~1 — 마커가 없을 때만 쓰는 폴백.
EYE_HINT = {
    "samjoko": (0.30, 0.30),
    "gumiho": (0.30, 0.32),
    "moonrabbit": (0.40, 0.34),
    "haetae": (0.32, 0.36),
    "dokkaebi": (0.42, 0.30),
    "hwangryong": (0.30, 0.30),
    "bear": (0.35, 0.30),
    "otter": (0.30, 0.30),
    "owl": (0.38, 0.32),
    "crane": (0.32, 0.20),
}

# 수동 지정 폴백 — 마커 검출이 실패한 키만 여기에 적는다 (마커가 우선).
EYE_OVERRIDE = {}
MOUTH_OVERRIDE = {}

# 수동 eye_clear 추가 — 자동 검출이 놓친 눈 옆 어두운 잔상을 얼굴색으로 지운다.
# {키: [(x, y, w, h)]}. eye_clear는 rect 내부를 주변 피부색으로 채운 뒤 눈을
# 다시 그리므로, 눈 rect를 사방 1칸 넓히면 눈 주위 1칸이 피부색으로 정리된다.
# 유아기(bear1·otter1·crane1)는 눈 주위 잔상이 남아 눈 rect+1칸을 피부색으로.
EYE_CLEAR_ADD = {
    "bear1": [(3, 13, 5, 5), (13, 13, 5, 5)],
    "otter1": [(3, 13, 5, 5), (13, 13, 5, 5)],
    # 두루미: 눈 rect+1칸을 흰 얼굴로 (유아기 눈 왼쪽 이동에 맞춰 링도 왼쪽)
    "crane1": [(12, 5, 4, 5)],
    "crane2": [(14, 3, 4, 5)],
    "crane3": [(19, 3, 3, 5)],
}

# 마커 눈 rect 미세보정 — {키: [(눈 인덱스, dx, dy, dw, dh)]}
# 인덱스는 좌→우 정렬 기준 (0=왼눈, 1=오른눈). 사용자 검수 반영.
EYE_TWEAK = {
    "gumiho3": [(0, 0, -1, 0, 1),        # 양눈 위로 1칸 확장
                (1, 0, -1, 0, 1)],
    "dokkaebi1": [(0, 0, 0, 0, 1)],      # 왼눈 아래로 1칸 확장
    "haetae2": [(1, 0, -1, 0, 1)],       # 오른눈 위로 1칸 확장
    "hwangryong1": [(1, -1, 0, 0, 0),    # 오른눈 왼쪽으로 1칸 이동
                    (0, 0, 0, 0, 1)],    # 왼눈 아래로 1칸 확장
    "hwangryong2": [(0, 0, -1, 0, 1)],   # 왼눈 위로 1칸 확장
    "hwangryong3": [(0, 0, -1, 0, 1)],   # 왼눈 위로 1칸 확장
    # ── 동물 영물(2차) 사용자 검수 반영 ──
    # 곰: 유아기 왼눈 위·오른눈 오른위 / 성장기 양눈 위 / 성숙기 양눈 오른위
    "bear1": [(0, 0, -1, 0, 1),          # 왼눈 위로 확장
              (1, 0, -1, 1, 1)],         # 오른눈 오른쪽+위로 확장
    "bear2": [(0, 0, -1, 0, 1),          # 양눈 위로 확장
              (1, 0, -1, 0, 1)],
    "bear3": [(0, 0, -1, 1, 1),          # 양눈 오른쪽+위로 확장
              (1, 0, -1, 1, 1)],
    # 수달: 전 스테이지 양눈 왼쪽+위로 확장
    "otter1": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    "otter2": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    "otter3": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    # 부엉이: 전 스테이지 양눈 왼쪽+위로 확장
    "owl1": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    "owl2": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    "owl3": [(0, -1, -1, 1, 1), (1, -1, -1, 1, 1)],
    # 두루미(옆모습 1눈): 유아기 왼쪽 이동 / 성장기 위로 / 성숙기 왼쪽+위로 확장
    "crane1": [(0, -1, 0, 0, 0)],
    "crane2": [(0, 0, -1, 0, 1)],
    "crane3": [(0, -1, -1, 1, 1)],
}

OUTPUT_PATH = os.path.join("tool", "hidden_species_art.py")


def luminance(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def marker_masks(arr):
    """눈(마젠타)·입(시안) 마커 픽셀 마스크.

    캐릭터 아트에 있는 분홍 볼터치/붉은 피부는 g가 높거나 b가 낮아
    걸리지 않도록 채도 높은 순색만 잡는다.
    """
    r = arr[..., 0].astype(int)
    g = arr[..., 1].astype(int)
    b = arr[..., 2].astype(int)
    eye = (r > 170) & (b > 170) & (g < 110)
    mouth = (g > 170) & (b > 170) & (r < 110)
    return eye, mouth


def blend_masks(arr):
    """마커 주변 안티앨리어싱 번짐(마젠타/시안 계열)까지 넓게 잡은 마스크.

    inpaint 전용 — 좌표 산출에는 쓰지 않는다. 캐릭터 고유의 분홍 볼터치·
    붉은 갈기 등은 g/b 비율 조건에 걸리지 않아 보존된다.
    """
    r = arr[..., 0].astype(int)
    g = arr[..., 1].astype(int)
    b = arr[..., 2].astype(int)
    eyeish = (r > 110) & (b > 100) & (g < r - 40) & (g < b - 30)
    mouthish = (g > 110) & (b > 110) & (r < g - 40) & (r < b - 30)
    return eyeish | mouthish


def content_mask(arr):
    """비배경(펫) 마스크.

    배경 = "코너색 근방인 밝은 영역 중 이미지 테두리에 연결된 것"만.
    → 흰 토끼 몸통처럼 아웃라인으로 둘러싸인 내부 밝은 영역은 배경에서
       제외돼 보존된다 (흰 피사체가 흰 배경에 사라지던 문제 해결).
    """
    corners = np.concatenate([
        arr[:8, :8].reshape(-1, 3), arr[:8, -8:].reshape(-1, 3),
        arr[-8:, :8].reshape(-1, 3), arr[-8:, -8:].reshape(-1, 3),
    ]).mean(axis=0)
    dist = np.sqrt(((arr.astype(int) - corners) ** 2).sum(axis=2))
    light = (dist < 36) | (arr.min(axis=2) > 236)  # 배경 후보(밝은 영역)

    # 테두리에 연결된 light 성분만 실제 배경
    labeled, n = ndimage.label(light)
    border = set(np.unique(np.concatenate([
        labeled[0, :], labeled[-1, :], labeled[:, 0], labeled[:, -1],
    ])))
    border.discard(0)
    bg = np.isin(labeled, list(border))
    return ~bg


def segment_three(mask, min_area_frac=0.0006):
    """마스크에서 3마리 영역의 컴포넌트 그룹을 반환 (좌→우)."""
    labeled, n = ndimage.label(mask)
    if n == 0:
        raise RuntimeError("내용 없음")
    areas = ndimage.sum(np.ones_like(labeled), labeled, range(1, n + 1))
    total = mask.size
    # 유효 컴포넌트(작은 반짝이/텍스트 제외)
    valid = [i + 1 for i, a in enumerate(areas) if a >= total * min_area_frac]
    # 각 컴포넌트의 x-중심
    centers = ndimage.center_of_mass(mask, labeled, valid)
    xs = sorted((c[1], lbl) for c, lbl in zip(centers, valid))
    # x-중심 기준 3그룹 클러스터 (가장 큰 간격 2개로 분할)
    xcs = [x for x, _ in xs]
    gaps = sorted(range(1, len(xcs)),
                  key=lambda i: xcs[i] - xcs[i - 1], reverse=True)[:2]
    cuts = sorted(gaps)
    groups = []
    start = 0
    for c in cuts + [len(xcs)]:
        groups.append([lbl for _, lbl in xs[start:c]])
        start = c
    return labeled, groups


def main_component(labeled, group):
    """그룹에서 본체(최대 컴포넌트)만 마스크로 반환.

    범례 스와치·라벨 텍스트·떠 있는 불꽃/반짝이/소품(달토끼 절구 등)은
    본체와 분리돼 있으므로 여기서 전부 걸러진다. 손에 쥔 방망이·붙은
    꼬리 불꽃처럼 몸에 닿은 요소는 본체 컴포넌트에 포함돼 유지된다.
    """
    sizes = {g: int((labeled == g).sum()) for g in group}
    main = max(sizes, key=sizes.get)
    return labeled == main


def stage_sub(labeled, group, marker_all):
    """스테이지 마스크 = 본체 + 본체 bbox 안의 조각 + (필요시) 봉합 복구.

    흰 몸통이 배경색과 비슷하면 얼굴 내부가 배경으로 새고(달토끼 성숙기)
    눈·코가 본체와 분리된 섬으로 남는다. 본체 bbox 안에 완전히 포함된
    조각을 합치고, 그래도 마커가 본체 밖이면 closing+fill_holes로
    아웃라인 틈을 봉합해 얼굴 내부(마커 포함)를 복구한다.
    """
    sub = main_component(labeled, group)
    ys, xs = np.where(sub)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    bbox = np.zeros_like(sub)
    bbox[y0:y1 + 1, x0:x1 + 1] = True
    if (marker_all & bbox & ~sub).sum() > 20:
        # 얼굴 누수 감지 — bbox 안에 완전히 포함된 조각(눈·코 섬)을 합치고
        # 아웃라인 틈을 봉합해 내부를 채운다. 정상 종은 이 경로를 타지
        # 않아 떠 있는 장식(반짝이·불꽃)이 섞이지 않는다.
        for g in group:
            gys, gxs = np.where(labeled == g)
            if (gys.min() >= y0 - 2 and gys.max() <= y1 + 2
                    and gxs.min() >= x0 - 2 and gxs.max() <= x1 + 2):
                sub = sub | (labeled == g)
        sub = ndimage.binary_fill_holes(
            ndimage.binary_closing(sub, structure=np.ones((7, 7))))
    return sub


def inpaint_markers(arr, sub, marker):
    """마커 클러스터를 주변 밝은 피부색(중앙값)으로 평탄하게 메꾼다.

    최근접 픽셀 복사 방식은 눈 바로 옆의 어두운 눈두덩 색을 번지게 해
    황룡처럼 눈 주변이 황토 얼룩이 되는 문제가 있었다. 클러스터마다
    주변 링에서 밝은 픽셀(상위 30% 휘도)의 중앙값 한 색으로 채워
    눈 자리가 피부색으로 매끈하게 돌아간다. 링이 전부 어두우면(삼족오
    검은 머리) 어두운 색 그대로 쓴다.
    """
    labeled, n = ndimage.label(marker & sub)
    out = arr.copy()
    for i in range(1, n + 1):
        cluster = labeled == i
        near = ndimage.binary_dilation(cluster, iterations=4) & sub
        ring = near & ~ndimage.binary_dilation(cluster, iterations=1) & ~marker
        ys, xs = np.where(ring)
        if len(ys) == 0:
            continue
        cols = arr[ys, xs].astype(float)
        lum = (0.2126 * cols[:, 0] + 0.7152 * cols[:, 1]
               + 0.0722 * cols[:, 2]) / 255.0
        cut = np.percentile(lum, 70)
        bright = cols[lum >= max(cut, 0.35)]
        use = bright if len(bright) >= 4 else cols
        fill = np.median(use, axis=0)
        area = ndimage.binary_dilation(cluster, iterations=2) & sub
        out[area] = fill
    return out


# 팔레트 인덱스(명암 오름차순) → ASCII 글자. dark→'#' … 최명→'%'
PALETTE_CHARS = ["#", "o", "+", "&", "%"]


def _prep_square(arr, sub, size, flip, masks=()):
    """크롭·반전·정사각 패딩 후 size 격자로 축소.

    반환: (alpha, rgb, 축소된 마스크 커버리지[0~1] 목록)
    masks의 각 마스크도 동일한 변환을 거쳐 격자 좌표계로 매핑된다.
    """
    ys, xs = np.where(sub)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    crop = arr[y0:y1 + 1, x0:x1 + 1].astype(np.uint8)
    cmask = sub[y0:y1 + 1, x0:x1 + 1]
    rgba = np.dstack([crop, np.where(cmask, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    side = max(im.width, im.height)
    ox, oy = (side - im.width) // 2, (side - im.height) // 2
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, (ox, oy))
    small = sq.resize((size, size), Image.BOX)
    px = np.array(small)

    scaled_masks = []
    for m in masks:
        mc = (m[y0:y1 + 1, x0:x1 + 1] & cmask).astype(np.uint8) * 255
        mim = Image.fromarray(mc, "L")
        if flip:
            mim = mim.transpose(Image.FLIP_LEFT_RIGHT)
        msq = Image.new("L", (side, side), 0)
        msq.paste(mim, (ox, oy))
        scaled_masks.append(
            np.array(msq.resize((size, size), Image.BOX)).astype(float) / 255.0)

    return px[..., 3] > 110, px[..., :3].astype(float), scaled_masks


def eyes_from_marker(cov, thresh=0.15, max_eyes=2):
    """축소된 눈 마커 커버리지에서 눈 rect 목록 산출 (좌→우)."""
    m = cov > thresh
    labeled, n = ndimage.label(m)
    if n == 0:
        return []
    clusters = []
    for i in range(1, n + 1):
        ys, xs = np.where(labeled == i)
        weight = float(cov[ys, xs].sum())
        clusters.append((weight, xs.min(), xs.max(), ys.min(), ys.max()))
    # 커버리지 큰 순으로 최대 max_eyes개 (노이즈 방지)
    clusters.sort(reverse=True)
    clusters = clusters[:max_eyes]
    size = cov.shape[0]

    def _expand(v0, v1, hi):
        # 최소 2칸 (표정 렌더 최소 크기)
        if v1 - v0 + 1 >= 2:
            return v0, v1
        if v1 + 1 < hi:
            return v0, v1 + 1
        return max(0, v0 - 1), v1

    rects = []
    for _, x0, x1, ys0, ys1 in clusters:
        x0, x1 = _expand(int(x0), int(x1), size)
        ys0, ys1 = _expand(int(ys0), int(ys1), size)
        rects.append((x0, ys0, x1 - x0 + 1, ys1 - ys0 + 1))
    rects.sort()
    return rects


def derive_eye_clear(art, eyes):
    """눈 rect 안에 남은 어두운 도트('#')와 연결된 어두운 눈두덩 자동 산출.

    황룡처럼 눈이 어두운 소켓 안에 그려진 종은 inpaint 후에도 소켓이
    rect 밖으로 남아 표정 교체 시 잔상이 된다. rect 내부 '#'에서 시작해
    주변 2칸 창 안의 연결된 '#' 덩어리를 찾아 그 bbox를 eye_clear로 쓴다.
    삼족오처럼 얼굴 전체가 어두운 종은 덩어리가 창을 가득 채우므로
    (75% 이상) 잔상이 아니라 몸색으로 보고 건너뛴다.
    """
    n = len(art)
    g = [list(r) for r in art]
    clears = []
    for (ex, ey, ew, eh) in eyes:
        wx0, wy0 = max(0, ex - 2), max(0, ey - 2)
        wx1, wy1 = min(n - 1, ex + ew + 1), min(n - 1, ey + eh + 1)
        seeds = [(x, y) for y in range(ey, min(n, ey + eh))
                 for x in range(ex, min(n, ex + ew)) if g[y][x] == "#"]
        if not seeds:
            continue
        blob = set(seeds)
        stack = list(seeds)
        while stack:
            cx, cy = stack.pop()
            for dx2, dy2 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx2, cy + dy2
                if (wx0 <= nx <= wx1 and wy0 <= ny <= wy1
                        and (nx, ny) not in blob and g[ny][nx] == "#"):
                    blob.add((nx, ny))
                    stack.append((nx, ny))
        window_area = (wx1 - wx0 + 1) * (wy1 - wy0 + 1)
        if len(blob) >= window_area * 0.75:
            continue  # 어두운 몸색(삼족오) — 잔상 아님
        bx0 = min(x for x, _ in blob)
        bx1 = max(x for x, _ in blob)
        by0 = min(y for _, y in blob)
        by1 = max(y for _, y in blob)
        cx0, cy0 = min(bx0, ex), min(by0, ey)
        cx1, cy1 = max(bx1, ex + ew - 1), max(by1, ey + eh - 1)
        if (cx0, cy0, cx1 - cx0 + 1, cy1 - cy0 + 1) != (ex, ey, ew, eh):
            clears.append((cx0, cy0, cx1 - cx0 + 1, cy1 - cy0 + 1))
    return clears


def mouth_from_marker(cov, thresh=0.10):
    """축소된 입 마커 커버리지에서 가중 중심 좌표 산출."""
    if cov.max() <= thresh:
        return None
    ys, xs = np.where(cov > thresh)
    w = cov[ys, xs]
    mx = int(round(float((xs * w).sum() / w.sum())))
    my = int(round(float((ys * w).sum() / w.sum())))
    return (mx, my)


def build_palette(stage_pixels, k=5):
    """종 전체 스테이지 픽셀에서 고정 팔레트 k색 (명암 오름차순) 산출."""
    cells = np.concatenate(stage_pixels, axis=0)
    uniq = len(np.unique(cells.astype(np.uint8).reshape(-1, 3), axis=0))
    k = min(k, max(1, uniq))
    centroids, _ = kmeans2(cells, k, minit="++", seed=7, iter=40)
    order = np.argsort(luminance(centroids))
    return centroids[order]  # (k,3) 명암 오름차순


def to_ascii(alpha, rgb, palette, size):
    """셀마다 팔레트 최근접색 인덱스 → ASCII (색은 팔레트로 보존)."""
    out = [["."] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            if not alpha[y, x]:
                continue
            d = ((palette - rgb[y, x]) ** 2).sum(axis=1)
            out[y][x] = PALETTE_CHARS[int(np.argmin(d))]
    return ["".join(r) for r in out]


def detect_eyes(art, size, eye_hint=None):
    """마커가 없을 때의 폴백 — "몸통에 완전히 둘러싸인" 작은 어두운 덩어리."""
    grid = [list(r) for r in art]
    dark = np.array([[1 if c == "#" else 0 for c in row] for row in grid])
    filled = np.array(
        [[1 if c != "." else 0 for c in row] for row in grid])  # 비배경(몸+눈)
    labeled, n = ndimage.label(dark)

    hx = (eye_hint[0] if eye_hint else 0.34) * size
    hy = (eye_hint[1] if eye_hint else 0.32) * size

    best = None
    for i in range(1, n + 1):
        ys, xs = np.where(labeled == i)
        area = len(ys)
        y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
        w, h = x1 - x0 + 1, y1 - y0 + 1
        if area > 12 or w > 5 or h > 5:  # 눈은 작다
            continue
        # 봉인 검사: 1px 팽창한 테두리가 전부 비배경이어야(=얼굴에 박힘)
        ry0, ry1 = max(0, y0 - 1), min(size, y1 + 2)
        rx0, rx1 = max(0, x0 - 1), min(size, x1 + 2)
        ring = filled[ry0:ry1, rx0:rx1]
        if ring.size == 0 or ring.min() == 0:
            continue  # 배경에 닿음 → 아웃라인/경계, 눈 아님
        cy, cx = ys.mean(), xs.mean()
        # 얼굴 영역(상반부·전방) 밖은 제외
        if not (size * 0.10 <= cy <= size * 0.62):
            continue
        if cx > size * 0.70:
            continue
        dist = ((cx - hx) ** 2 + (cy - hy) ** 2) ** 0.5
        score = -dist
        if best is None or score > best[0]:
            cxr, cyr = int(round(cx)), int(round(cy))
            best = (score, cxr - 1, cyr - 1, min(3, max(2, w)), min(3, max(2, h)))
    if best is None:
        ex, ey = int(hx) - 1, int(hy) - 1
        return [(max(0, ex), max(0, ey), 2, 2)]
    _, x, y, w, h = best
    return [(max(0, x), max(0, y), w, h)]


def normalize_eye_override(rects):
    """수동 눈 좌표를 (x, y, w, h) rect 목록으로 정규화."""
    normalized = []
    for rect in rects:
        if len(rect) == 2:
            x, y = rect
            normalized.append((x, y, 2, 2))
        elif len(rect) == 4:
            normalized.append(tuple(rect))
        else:
            raise ValueError(f"눈 좌표는 2튜플 또는 4튜플이어야 함: {rect!r}")
    return normalized


def _hex(c):
    return "0x{:02X}{:02X}{:02X}".format(int(c[0]), int(c[1]), int(c[2]))


def main():
    result = {}
    palettes = {}
    for species, (path, flip) in SPECIES.items():
        arr = np.array(Image.open(path).convert("RGB"))
        eye_m, mouth_m = marker_masks(arr)
        # 마커 픽셀도 캐릭터의 일부로 취급 (마스크가 마커 자리를 구멍 내지 않게)
        mask = content_mask(arr) | eye_m | mouth_m
        labeled, groups = segment_three(mask)
        if len(groups) != 3:
            print(f"[warn] {species}: {len(groups)}그룹 검출 (3 아님)")

        # 1) 세 스테이지 픽셀을 모아 종 고정 팔레트(5색) 산출.
        #    마커는 inpaint로 먼저 지워 팔레트가 오염되지 않는다.
        preps = []
        subs = []
        blend = blend_masks(arr)
        for stage_idx, group in enumerate(groups[:3]):
            size = STAGE_SIZES[stage_idx]
            sub = stage_sub(labeled, group, eye_m | mouth_m)
            clean = inpaint_markers(arr, sub, eye_m | mouth_m | blend)
            alpha, rgb, (eye_cov, mouth_cov) = _prep_square(
                clean, sub, size, flip, masks=(eye_m, mouth_m))
            preps.append((alpha, rgb, size, eye_cov, mouth_cov))
            subs.append(rgb[alpha])
        palette = build_palette(subs, k=5)
        palettes[species] = [_hex(c) for c in palette]

        # 2) 스테이지별 ASCII (팔레트 최근접색) + 마커 기반 눈/입
        for stage_idx, (alpha, rgb, size, eye_cov, mouth_cov) in enumerate(preps):
            art = to_ascii(alpha, rgb, palette, size)
            key = f"{species}{stage_idx + 1}"

            eyes = eyes_from_marker(eye_cov)
            src = "마커"
            if not eyes:
                if key in EYE_OVERRIDE:
                    eyes = normalize_eye_override(EYE_OVERRIDE[key])
                    src = "수동"
                else:
                    eyes = detect_eyes(art, size, eye_hint=EYE_HINT.get(species))
                    src = "자동폴백"
                print(f"[warn] {key}: 눈 마커 미검출 → {src}")
            eyes = [tuple(int(v) for v in e) for e in eyes]
            for idx, dx, dy, dw, dh in EYE_TWEAK.get(key, []):
                if idx < len(eyes):
                    ex, ey, ew, eh = eyes[idx]
                    eyes[idx] = (max(0, ex + dx), max(0, ey + dy),
                                 max(2, ew + dw), max(2, eh + dh))

            mouth = mouth_from_marker(mouth_cov)
            if mouth is None:
                if key in MOUTH_OVERRIDE:
                    mouth = MOUTH_OVERRIDE[key]
                else:
                    ex, ey, ew, eh = eyes[0]
                    mouth = (int(max(0, ex)), int(min(size - 1, ey + eh + 2)))
                print(f"[warn] {key}: 입 마커 미검출 → 폴백 {mouth}")

            item = {"body": art, "eyes": eyes, "mouth": tuple(mouth)}
            clears = derive_eye_clear(art, eyes)
            clears = list(clears) + [tuple(c) for c in EYE_CLEAR_ADD.get(key, [])]
            if clears:
                item["eye_clear"] = clears
            result[key] = item
            extra = f" eye_clear={clears}" if clears else ""
            print(f"  {key}: eyes({src})={eyes} mouth={tuple(mouth)}{extra}")
        print(f"  {species}: palette={palettes[species]}")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write("# -*- coding: utf-8 -*-\n")
        f.write('"""자동 생성 — tool/dump_reference_art.py. 직접 수정 금지."""\n\n')
        f.write("HIDDEN_ART = {\n")
        for key, d in result.items():
            f.write(f"    {key!r}: {{\n")
            f.write('        "body": [\n')
            for row in d["body"]:
                f.write(f"            {row!r},\n")
            f.write("        ],\n")
            f.write(f'        "eyes": {d["eyes"]!r},\n')
            if "eye_clear" in d:
                f.write(f'        "eye_clear": {d["eye_clear"]!r},\n')
            f.write(f'        "mouth": {tuple(d["mouth"])!r},\n')
            f.write("    },\n")
        f.write("}\n\n")
        # 종 → 팔레트 5색 (명암 오름차순: '#','o','+','&','%' 순서와 대응)
        f.write("HIDDEN_PALETTE = {\n")
        for species, cols in palettes.items():
            f.write(f"    {species!r}: [{', '.join(cols)}],\n")
        f.write("}\n")
    print(f"생성: {OUTPUT_PATH} ({len(result)}개 스프라이트, 팔레트 {len(palettes)}종)")


if __name__ == "__main__":
    main()
