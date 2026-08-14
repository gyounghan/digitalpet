# -*- coding: utf-8 -*-
"""앱 런처 아이콘 생성 스크립트 — 털뭉치 도트를 그대로 아이콘으로.

pet_motion_data.json의 fluff 모션 프레임(홈 화면에서 실제 보이는 도트)을
파싱해 인앱 렌더와 동일한 3색(dark/body/accent)으로 찍고, 따뜻한
그라데이션 배경 위에 올린다. 도트는 nearest-neighbor 확대로 또렷하게 유지.

주의: 정적 pet_pixel_data.json의 '기본이미지'는 PNG 휘도 자동분류라
밝은 베이지 몸통이 accent로 분류돼 색이 반전된다 — 모션 데이터
(수제 ASCII 원본: 'o'몸통/'+'보조/'#'아웃라인)를 써야 인앱과 같다.

생성물 (android/app/src/main/res/):
  - mipmap-{mdpi..xxxhdpi}/ic_launcher.png            레거시 (라운드 사각)
  - mipmap-{mdpi..xxxhdpi}/ic_launcher_background.png  어댑티브 배경 (108dp)
  - mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png  어댑티브 전경 (108dp)
  - mipmap-anydpi-v26/ic_launcher.xml                  어댑티브 정의
  - assets/icon/app_icon_1024.png                      마스터 (iOS/스토어용)

사용법:
    python3 tool/generate_app_icon.py
"""

import json
import os

from PIL import Image, ImageDraw

# 아이콘에 쓸 모션/프레임 — joy(웃는 표정) 1번 프레임
ICON_MOTION = "joy"
ICON_FRAME = 1

# 인앱 렌더 색상과 동일하게 유지 (lib/core/theme/species_theme.dart)
DARK = (0x14, 0x16, 0x1A, 255)    # SpeciesTheme.dotDark
BODY = (0xF4, 0xE9, 0xCE, 255)    # SpeciesTheme.fluffBody
ACCENT = (0xF2, 0xA0, 0xAE, 255)  # SpeciesTheme.fluffAccent

# 배경 그라데이션 (위 → 아래, 따뜻한 살구톤 — 베이지 몸통이 도드라지게)
BG_TOP = (0xFF, 0xC9, 0x7A)
BG_BOTTOM = (0xF0, 0x8A, 0x5C)

JSON_PATH = os.path.join(
    "android", "app", "src", "main", "assets", "pet_motion_data.json")
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


def load_fluff_sprite():
    """털뭉치 모션 프레임을 크롭된 RGBA 이미지(1px=1도트)로 반환."""
    data = json.load(open(JSON_PATH, encoding="utf-8"))
    fluff = data["fluff"]
    grid = fluff["size"]
    frame = fluff[ICON_MOTION]["f"][ICON_FRAME]
    im = Image.new("RGBA", (grid, grid), (0, 0, 0, 0))
    px = im.load()
    for y in range(grid):
        # 행 마스크는 hex 문자열 (generate_motion_data.py 출력 형식)
        dark = int(frame["d"][y], 16)
        body = int(frame["b"][y], 16)
        accent = int(frame["a"][y], 16)
        for x in range(grid):
            bit = 1 << x
            if dark & bit:
                px[x, y] = DARK
            elif accent & bit:
                px[x, y] = ACCENT
            elif body & bit:
                px[x, y] = BODY
    bbox = im.getbbox()
    return im.crop(bbox)


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
    """canvas 중앙에 sprite를 nearest로 확대해 부드러운 그림자와 함께 배치.

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

    # 바닥 그림자 (살짝 어두운 타원)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sw = int(scaled.width * 0.72)
    sh = max(6, int(scaled.height * 0.10))
    sy = cy + scaled.height - sh // 2
    sd.ellipse(
        [(size - sw) // 2, sy, (size + sw) // 2, sy + sh],
        fill=(90, 45, 25, 70))
    canvas.alpha_composite(shadow)

    canvas.alpha_composite(scaled, (cx, cy))
    return canvas


def rounded_mask(size, radius_frac):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * radius_frac), fill=255)
    return mask


def build_legacy(sprite, size):
    """레거시 아이콘 — 라운드 사각 배경 + 털뭉치."""
    im = vertical_gradient(size, BG_TOP, BG_BOTTOM)
    im = paste_sprite(im, sprite, sprite_frac=0.74, y_offset_frac=0.02)
    im.putalpha(rounded_mask(size, radius_frac=0.18))
    return im


def build_adaptive_background(size):
    return vertical_gradient(size, BG_TOP, BG_BOTTOM)


def build_adaptive_foreground(sprite, size):
    """어댑티브 전경 — 안전 영역(중앙 66dp/108dp) 안에 털뭉치만.

    0.55 × 108dp ≈ 59dp < 66dp 안전 영역 — 원형 마스크에서도 잘리지 않으면서
    최대한 크게 보이는 비율.
    """
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return paste_sprite(im, sprite, sprite_frac=0.55, y_offset_frac=0.01)


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def main():
    sprite = load_fluff_sprite()
    print(f"털뭉치 스프라이트: {sprite.width}x{sprite.height} 도트")

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
    master = paste_sprite(master, sprite, sprite_frac=0.74, y_offset_frac=0.02)
    master_path = os.path.join("assets", "icon", "app_icon_1024.png")
    master.convert("RGB").save(master_path)
    print(f"  {master_path}")


if __name__ == "__main__":
    main()
