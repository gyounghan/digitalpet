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

# 종 → (경로, 좌우반전 필요 여부[레퍼런스가 오른쪽을 볼 때 True])
SPECIES = {
    "samjoko": ("assets/삼족오.png", False),
    "gumiho": ("assets/구미호.jpeg", True),
    "moonrabbit": ("assets/달토끼.png", False),
    "haetae": ("assets/해테.jpeg", True),
    "dokkaebi": ("assets/도깨비.png", True),
    "hwangryong": ("assets/황룡.png", False),
}

# 스테이지별 목표 격자 (유아기 32 / 성장기 36 / 성숙기 56 — 기존 규칙)
STAGE_SIZES = [32, 36, 56]

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


def detect_eyes(art, size):
    """3계조 art에서 눈 rect 추정 — 몸통에 둘러싸인 '#' 소형 덩어리(상반부·전방).

    실패하면 머리 전방 기본 위치. (왼쪽을 보므로 전방 = 왼쪽)
    """
    grid = [list(r) for r in art]
    darkmask = np.array([[1 if c == "#" else 0 for c in row] for row in grid])
    bodymask = np.array(
        [[1 if c in ("o", "+") else 0 for c in row] for row in grid])
    labeled, n = ndimage.label(darkmask)
    best = None
    for i in range(1, n + 1):
        ys, xs = np.where(labeled == i)
        area = len(ys)
        if area < 1 or area > size * 0.9:
            continue
        cy, cx = ys.mean(), xs.mean()
        # 상반부(0.15~0.55) + 전방(왼쪽 0.1~0.7)
        if not (size * 0.12 <= cy <= size * 0.58):
            continue
        if cx > size * 0.72:
            continue
        # 몸통에 둘러싸여야 눈(주변에 body 존재)
        y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
        # 눈은 작은 덩어리 — 크면 아웃라인/머리 음영 (절대 6px·30셀 상한)
        if (y1 - y0) > 6 or (x1 - x0) > 6 or area > 30:
            continue
        surround = bodymask[max(0, y0 - 1):y1 + 2, max(0, x0 - 1):x1 + 2].sum()
        if surround < 2:
            continue
        # 전방·상단 우선 점수
        score = -cx - cy * 0.5 + area * 0.3
        if best is None or score > best[0]:
            # 눈 rect는 최대 4px로 제한 (표정 교체 시 얼굴 과도 침범 방지)
            best = (score, int(cx - 1), int(cy - 1),
                    min(4, x1 - x0 + 1), min(4, y1 - y0 + 1))
    if best is None:
        # 기본: 머리 전방
        return [(int(size * 0.28), int(size * 0.26), 3, 3)]
    _, x, y, w, h = best
    return [(max(0, x), max(0, y), max(2, w), max(2, h))]


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
            eyes = detect_eyes(art, size)
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
