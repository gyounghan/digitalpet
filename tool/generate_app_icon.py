# -*- coding: utf-8 -*-
"""앱 런처 아이콘 생성 스크립트 — 발자국(paw) 도트 심볼.

앱명 '갓생몬' 리브랜딩에 맞춰 펫 스프라이트 대신 심볼형 아이콘을 쓴다:
민트 그라데이션 배경 위에 크림색 동물 발자국 + 반짝이 2개.
발자국은 타원/원 마스크에서 아웃라인을 자동 추출해 그리므로
좌우 대칭과 둥근 실루엣이 보장된다. 도트는 nearest-neighbor 확대.

생성물 (android/app/src/main/res/):
  - mipmap-{mdpi..xxxhdpi}/ic_launcher.png            레거시 (라운드 사각)
  - mipmap-{mdpi..xxxhdpi}/ic_launcher_background.png  어댑티브 배경 (108dp)
  - mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png  어댑티브 전경 (108dp)
  - mipmap-anydpi-v26/ic_launcher.xml                  어댑티브 정의
  - assets/icon/app_icon_1024.png                      마스터 (iOS/스토어용)

사용법:
    python tool/generate_app_icon.py
"""

import os

from PIL import Image, ImageDraw

# 팔레트 — 인앱 도트 감성과 동일한 웜톤 (검정 대신 웜브라운 아웃라인)
OUTLINE = (0x5A, 0x44, 0x30, 255)
PAW = (0xFF, 0xF1, 0xD6, 255)      # 크림 (fluffBody 계열)
SPARKLE = (0xFF, 0xFD, 0xF2, 255)  # 반짝이 — 거의 흰색

# 배경 그라데이션 (위 → 아래) — 갓생/새 습관의 프레시 민트
BG_TOP = (0xA8, 0xE6, 0xCF)
BG_BOTTOM = (0x4C, 0xB8, 0x8A)

RES_DIR = os.path.join("android", "app", "src", "main", "res")

# 밀도별 크기: (레거시 dp48, 어댑티브 레이어 dp108)
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

MASTER = 1024

GRID = 24  # 발자국 스프라이트 도트 격자


def _in_ellipse(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def _paw_mask():
    """메인 패드 1개 + 발가락 3개 — 원/타원 합집합."""
    mask = [[False] * GRID for _ in range(GRID)]
    shapes = [
        (12.0, 16.0, 6.6, 5.0),   # 메인 패드
        (5.5, 9.5, 3.0, 3.0),     # 왼쪽 발가락
        (12.0, 6.9, 3.0, 3.0),    # 가운데 발가락
        (18.5, 9.5, 3.0, 3.0),    # 오른쪽 발가락
    ]
    for y in range(GRID):
        for x in range(GRID):
            for cx, cy, rx, ry in shapes:
                if _in_ellipse(x + 0.5, y + 0.5, cx, cy, rx, ry):
                    mask[y][x] = True
                    break
    return mask


def _outline_of(mask):
    """4방향 이웃에 빈 칸이 있으면 아웃라인."""
    edge = [[False] * GRID for _ in range(GRID)]
    for y in range(GRID):
        for x in range(GRID):
            if not mask[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < GRID and 0 <= ny < GRID) or not mask[ny][nx]:
                    edge[y][x] = True
                    break
    return edge


def _stamp_sparkle(px, cx, cy):
    """+자 5도트 반짝이."""
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        x, y = cx + dx, cy + dy
        if 0 <= x < GRID and 0 <= y < GRID:
            px[x, y] = SPARKLE


def build_paw_sprite():
    """발자국 스프라이트를 크롭된 RGBA 이미지(1px=1도트)로 반환."""
    mask = _paw_mask()
    edge = _outline_of(mask)
    im = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    px = im.load()
    for y in range(GRID):
        for x in range(GRID):
            if edge[y][x]:
                px[x, y] = OUTLINE
            elif mask[y][x]:
                px[x, y] = PAW
    # 반짝이 — 발자국 주변 여백에 배치 (갓생 달성의 반짝임)
    _stamp_sparkle(px, 21, 3)
    _stamp_sparkle(px, 2, 13)
    return im.crop(im.getbbox())


def vertical_gradient(size, top, bottom):
    im = Image.new("RGBA", (size, size))
    px = im.load()
    for y in range(size):
        t = y / (size - 1)
        r = round(top[0] + (bottom[0] - top[0]) * t)
        g = round(top[1] + (bottom[1] - top[1]) * t)
        b = round(top[2] + (bottom[2] - top[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    return im


def paste_sprite(canvas, sprite, sprite_frac, y_offset_frac=0.0):
    """canvas 중앙에 sprite를 nearest로 확대해 배치.

    [sprite_frac] 캔버스 대비 스프라이트 최대 변 비율
    [y_offset_frac] 세로 중심 보정 (+면 아래로)
    """
    size = canvas.width
    target = int(size * sprite_frac)
    scale = max(1, target // max(sprite.width, sprite.height))
    scaled = sprite.resize(
        (sprite.width * scale, sprite.height * scale), Image.NEAREST)

    cx = (size - scaled.width) // 2
    cy = (size - scaled.height) // 2 + int(size * y_offset_frac)
    canvas.alpha_composite(scaled, (cx, cy))
    return canvas


def rounded_mask(size, radius_frac):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * radius_frac), fill=255)
    return mask


def build_legacy(sprite, size):
    """레거시 아이콘 — 라운드 사각 배경 + 발자국."""
    im = vertical_gradient(size, BG_TOP, BG_BOTTOM)
    im = paste_sprite(im, sprite, sprite_frac=0.78)
    im.putalpha(rounded_mask(size, radius_frac=0.18))
    return im


def build_adaptive_background(size):
    return vertical_gradient(size, BG_TOP, BG_BOTTOM)


def build_adaptive_foreground(sprite, size):
    """어댑티브 전경 — 안전 영역(중앙 66dp/108dp) 안에 발자국만.

    0.55 × 108dp ≈ 59dp < 66dp 안전 영역 — 원형 마스크에서도 잘리지 않으면서
    최대한 크게 보이는 비율.
    """
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return paste_sprite(im, sprite, sprite_frac=0.55)


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def main():
    sprite = build_paw_sprite()
    print(f"발자국 스프라이트: {sprite.width}x{sprite.height} 도트")

    for density, (legacy_size, adaptive_size) in DENSITIES.items():
        mipmap_dir = os.path.join(RES_DIR, f"mipmap-{density}")
        os.makedirs(mipmap_dir, exist_ok=True)

        build_legacy(sprite, legacy_size).save(
            os.path.join(mipmap_dir, "ic_launcher.png"))
        build_adaptive_background(adaptive_size).save(
            os.path.join(mipmap_dir, "ic_launcher_background.png"))
        build_adaptive_foreground(sprite, adaptive_size).save(
            os.path.join(mipmap_dir, "ic_launcher_foreground.png"))
        print(f"  mipmap-{density}: legacy {legacy_size}, "
              f"adaptive {adaptive_size}")

    anydpi_dir = os.path.join(RES_DIR, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w") as f:
        f.write(ADAPTIVE_XML)
    print("  mipmap-anydpi-v26/ic_launcher.xml")

    # 마스터 1024 (iOS AppIcon/스토어 등록용 — 모서리 라운드 없이 풀블리드)
    os.makedirs(os.path.join("assets", "icon"), exist_ok=True)
    master = vertical_gradient(MASTER, BG_TOP, BG_BOTTOM)
    master = paste_sprite(master, sprite, sprite_frac=0.78)
    master_path = os.path.join("assets", "icon", "app_icon_1024.png")
    master.convert("RGB").save(master_path)
    print(f"  {master_path}")


if __name__ == "__main__":
    main()
