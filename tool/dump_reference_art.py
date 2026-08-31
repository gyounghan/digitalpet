# -*- coding: utf-8 -*-
"""레퍼런스 이미지(설화 영물 컨셉아트)에서 도트 아트를 추출.

각 레퍼런스는 3스테이지(유아기·성장기·성숙기)가 좌→우로 나열돼 있다.
연결요소 분석으로 3마리를 분리 → 크롭 → (필요시 좌우반전, 게임 펫은 왼쪽을
본다) → 목표 격자로 축소 → 색을 3계조('#'dark/'o'body/'+'accent)로 양자화.

몸통색('o')은 런타임에 종 테마색으로 렌더되므로(기존 백호=청회색처럼 스타일화),
여기선 실루엣과 명암 구조를 충실히 뜨는 게 목적이다.

출력: tool/hidden_species_art.py  (HIDDEN_ART dict)
사용: python tool/dump_reference_art.py
"""

import os
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2

# 종 → (경로, 좌우반전 여부). 게임 펫은 전부 왼쪽을 본다(사신수와 통일).
# 실측(tiger 기준 렌더 비교)으로 확정한 값.
SPECIES = {
    "samjoko": ("assets/삼족오.png", False),
    "gumiho": ("assets/구미호.jpeg", False),
    "moonrabbit": ("assets/달토끼.png", True),
    "haetae": ("assets/해테.jpeg", False),
    "dokkaebi": ("assets/도깨비.png", False),
    "hwangryong": ("assets/황룡.png", False),
}

# 스테이지별 목표 격자 (유아기 32 / 성장기 36 / 성숙기 56 — 기존 규칙)
STAGE_SIZES = [32, 36, 56]

# 종별 얼굴(눈) 대략 위치 (fx, fy) 0~1 — 전부 왼쪽을 보는 기준.
# detect_eyes가 이 근방의 '봉인된 어두운 덩어리'를 눈으로 우선 선택한다.
EYE_HINT = {
    "samjoko": (0.30, 0.30),
    "gumiho": (0.30, 0.32),
    "moonrabbit": (0.40, 0.34),
    "haetae": (0.32, 0.36),
    "dokkaebi": (0.42, 0.30),
    "hwangryong": (0.30, 0.30),
}

OUTPUT_PATH = os.path.join("tool", "hidden_species_art.py")


def luminance(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


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
    """마스크에서 3마리 영역의 (x0,x1) 열 범위를 반환 (좌→우)."""
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


def region_bbox(labeled, group):
    """그룹(라벨 목록)이 차지하는 통합 bbox — 몸통 본체 + 근접 부속만.

    본체(최대 컴포넌트) 발 아래로 처지는 것(텍스트)은 제외.
    """
    sub = np.isin(labeled, group)
    ys, xs = np.where(sub)
    # 본체 = 최대 컴포넌트
    sizes = {g: int((labeled == g).sum()) for g in group}
    main = max(sizes, key=sizes.get)
    mys, mxs = np.where(labeled == main)
    main_bottom = mys.max()
    keep = []
    for g in group:
        gys, gxs = np.where(labeled == g)
        # 본체 발밑(아래로 8px 초과)에서 시작하는 조각 = 텍스트/그림자 → 제외
        if gys.min() > main_bottom + 8:
            continue
        keep.append(g)
    sub = np.isin(labeled, keep)
    ys, xs = np.where(sub)
    return xs.min(), xs.max(), ys.min(), ys.max(), sub


# 팔레트 인덱스(명암 오름차순) → ASCII 글자. dark→'#' … 최명→'%'
PALETTE_CHARS = ["#", "o", "+", "&", "%"]


def _prep_square(arr, sub, size, flip):
    """크롭·반전·정사각 패딩 후 size 격자로 축소한 (alpha, rgb) 반환."""
    ys, xs = np.where(sub)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    crop = arr[y0:y1 + 1, x0:x1 + 1].astype(np.uint8)
    cmask = sub[y0:y1 + 1, x0:x1 + 1]
    rgba = np.dstack([crop, np.where(cmask, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    side = max(im.width, im.height)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    small = sq.resize((size, size), Image.BOX)
    px = np.array(small)
    return px[..., 3] > 110, px[..., :3].astype(float)


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
    """art에서 눈 rect 추정 — "몸통에 완전히 둘러싸인" 작은 어두운 덩어리.

    눈은 얼굴(몸통) 안에 박힌 어두운 점이라, 실루엣 경계('.'에 닿음)와
    달리 8-이웃이 전부 비배경이다. 이 봉인(enclosure) 조건으로 아웃라인·
    갈기 그림자를 걸러내고, 얼굴 영역(상반부·전방[왼쪽])의 것을 고른다.

    [eye_hint] (fx, fy) 0~1 상대좌표 — 이 얼굴 위치에 가까운 후보 우선.
    실패 시 hint(또는 기본 머리 전방)에 눈을 배치한다.
    """
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
        # hint에 가까울수록 높은 점수 (+ 약간의 전방·상단 선호)
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


def _hex(c):
    return "0x{:02X}{:02X}{:02X}".format(int(c[0]), int(c[1]), int(c[2]))


def main():
    result = {}
    palettes = {}
    for species, (path, flip) in SPECIES.items():
        arr = np.array(Image.open(path).convert("RGB"))
        mask = content_mask(arr)
        labeled, groups = segment_three(mask, )
        if len(groups) != 3:
            print(f"[warn] {species}: {len(groups)}그룹 검출 (3 아님)")

        # 1) 세 스테이지 픽셀을 모아 종 고정 팔레트(5색) 산출 — 스테이지 간
        #    색이 일관되도록. 각 셀은 이 팔레트의 최근접색으로 배정된다.
        preps = []
        subs = []
        for stage_idx, group in enumerate(groups[:3]):
            size = STAGE_SIZES[stage_idx]
            _, _, _, _, sub = region_bbox(labeled, group)
            alpha, rgb = _prep_square(arr, sub, size, flip)
            preps.append((alpha, rgb, size))
            subs.append(rgb[alpha])
        palette = build_palette(subs, k=5)
        palettes[species] = [_hex(c) for c in palette]

        # 2) 스테이지별 ASCII (팔레트 최근접색)
        for stage_idx, (alpha, rgb, size) in enumerate(preps):
            art = to_ascii(alpha, rgb, palette, size)
            eyes = detect_eyes(art, size, eye_hint=EYE_HINT.get(species))
            eyes = [tuple(int(v) for v in e) for e in eyes]
            ex, ey, ew, eh = eyes[0]
            mouth = (int(max(0, ex)), int(min(size - 1, ey + eh + 2)))
            key = f"{species}{stage_idx + 1}"
            result[key] = {"body": art, "eyes": eyes, "mouth": mouth}
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
