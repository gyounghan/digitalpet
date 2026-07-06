# -*- coding: utf-8 -*-
"""assets/*.png -> 64x64 도트 좌표 데이터(Dart) 생성 스크립트.

각 이미지를 투명 영역 기준으로 크롭 -> 정사각 패딩 -> 64x64 다운샘플한 뒤
셀을 3계조로 분류한다:
  - dark:   불투명 + 어두움 (아웃라인/눈 등) -> 진한 도트
  - accent: 불투명 + 매우 밝음 (배/부리 등 보조색 영역) -> 보조색 도트
  - body:   그 외 불투명 -> 테마색 도트

행별 GRID비트 비트마스크(List<int>)로 저장해 런타임에는 이미지 디코딩 없이
CustomPainter로 도트만 찍는다 (다마고치 LCD 스타일).

주의: GRID=64면 행 마스크가 64비트 전체를 쓰므로 최상위 비트(x=63)가 켜진
행은 Dart에서 음수 리터럴로 해석된다. 비트 연산(&, |)만 쓰므로 무해하다.

사용법:
    python tool/generate_pixel_data.py

출력:
    lib/core/pixel/pet_pixel_data.dart
"""

import os
import sys
import glob

from PIL import Image

GRID = 64
ALPHA_THRESHOLD = 0.5  # 셀 평균 알파가 이 값보다 크면 도트 on
DARK_LUMINANCE = 0.45  # 이 값보다 어두우면 dark 도트
ACCENT_LUMINANCE = 0.78  # 이 값보다 밝으면 accent(보조색) 도트
HEX_WIDTH = GRID // 4  # 행 마스크 hex 자릿수 (64그리드 → 16자리)
VALUES_PER_LINE = 8 if GRID <= 32 else 4
ASSETS_DIR = "assets"
OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_pixel_data.dart")


def luminance(r: int, g: int, b: int) -> float:
    """sRGB 상대 휘도 (0.0~1.0 근사)."""
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def extract_sprite(path: str):
    """이미지 하나를 (darkRows, bodyRows, accentRows) 비트마스크 튜플로 변환.

    완전 투명 이미지는 None 반환.
    """
    im = Image.open(path).convert("RGBA")

    bbox = im.getbbox()  # 알파 0이 아닌 영역
    if bbox is None:
        return None
    im = im.crop(bbox)

    # 정사각 패딩 (중앙 정렬) — 종횡비 유지한 채 GRID 그리드에 맞춤
    side = max(im.width, im.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))

    small = square.resize((GRID, GRID), Image.BOX)
    pixels = small.load()

    dark_rows = []
    body_rows = []
    accent_rows = []
    for y in range(GRID):
        dark_mask = 0
        body_mask = 0
        accent_mask = 0
        for x in range(GRID):
            r, g, b, a = pixels[x, y]
            if a / 255.0 <= ALPHA_THRESHOLD:
                continue
            lum = luminance(r, g, b)
            if lum < DARK_LUMINANCE:
                dark_mask |= 1 << x
            elif lum > ACCENT_LUMINANCE:
                accent_mask |= 1 << x
            else:
                body_mask |= 1 << x
        dark_rows.append(dark_mask)
        body_rows.append(body_mask)
        accent_rows.append(accent_mask)

    if not any(dark_rows) and not any(body_rows) and not any(accent_rows):
        return None
    return dark_rows, body_rows, accent_rows


def format_rows(rows) -> str:
    """비트마스크 리스트를 Dart 리터럴 문자열로 (hex, 줄바꿈 포함)."""
    parts = ["0x%0*X" % (HEX_WIDTH, v) for v in rows]
    lines = []
    for i in range(0, len(parts), VALUES_PER_LINE):
        lines.append(
            "      " + ", ".join(parts[i : i + VALUES_PER_LINE]) + ","
        )
    return "[\n" + "\n".join(lines) + "\n    ]"


def main() -> int:
    png_paths = sorted(glob.glob(os.path.join(ASSETS_DIR, "*.png")))
    if not png_paths:
        print("assets/*.png 없음", file=sys.stderr)
        return 1

    entries = []
    skipped = []
    for path in png_paths:
        key = os.path.splitext(os.path.basename(path))[0]
        result = extract_sprite(path)
        if result is None:
            skipped.append(key)
            continue
        entries.append((key,) + result)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(
            "// GENERATED CODE - DO NOT EDIT BY HAND\n"
            "// tool/generate_pixel_data.py 로 재생성:\n"
            "//   python tool/generate_pixel_data.py\n"
            "//\n"
            "// assets/*.png 를 %dx%d 도트 그리드로 변환한 좌표 데이터.\n"
            "// dark = 아웃라인(어두운 픽셀), body = 몸통(중간 밝기),\n"
            "// accent = 보조색(매우 밝은 픽셀 — 배/부리/불꽃 등).\n"
            "// 각 리스트는 행(y)별 비트마스크 — bit x가 1이면 (x, y)에 도트.\n"
            "\n"
            "/// 도트 스프라이트 한 장 — 이미지 디코딩 없이 좌표로만 렌더링\n"
            "class PixelSprite {\n"
            "  /// 그리드 한 변 크기 (도트 개수)\n"
            "  final int size;\n"
            "\n"
            "  /// 어두운(아웃라인) 도트 — 행별 비트마스크\n"
            "  final List<int> dark;\n"
            "\n"
            "  /// 몸통 도트 — 행별 비트마스크 (테마색)\n"
            "  final List<int> body;\n"
            "\n"
            "  /// 보조색 도트 — 행별 비트마스크 (배/부리/등딱지 등,\n"
            "  /// accentColor 미지정 시 body와 같은 색으로 렌더링)\n"
            "  final List<int> accent;\n"
            "\n"
            "  const PixelSprite({\n"
            "    required this.size,\n"
            "    required this.dark,\n"
            "    required this.body,\n"
            "    this.accent = const [],\n"
            "  });\n"
            "}\n"
            "\n"
            "/// 에셋 파일명(확장자 제외) -> 도트 스프라이트\n"
            "const Map<String, PixelSprite> petPixelSprites = {\n" % (GRID, GRID)
        )
        for key, dark_rows, body_rows, accent_rows in entries:
            f.write(
                "  '%s': PixelSprite(\n"
                "    size: %d,\n"
                "    dark: %s,\n"
                "    body: %s,\n"
                "    accent: %s,\n"
                "  ),\n"
                % (
                    key,
                    GRID,
                    format_rows(dark_rows),
                    format_rows(body_rows),
                    format_rows(accent_rows),
                )
            )
        f.write("};\n")

    print("생성 완료: %s (%d개 스프라이트)" % (OUTPUT_PATH, len(entries)))
    if skipped:
        print("건너뜀 (빈 이미지): %s" % ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
