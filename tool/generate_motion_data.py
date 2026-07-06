# -*- coding: utf-8 -*-
"""베이비(유아기, stage 2) 스프라이트의 모션 프레임 합성 스크립트.

tiger1/bird1/turtle1/dragon1 그리드를 프로그램으로 변형해
다마고치 LCD 방식의 모션 3프레임을 만든다. 단순 평행이동이 아니라
부위별 변형으로 실제 움직임을 표현한다:
  - 다리 분리 스텝: 하단 다리 영역을 앞/뒤 절반으로 나눠 교차로 들어올림 (걷기)
  - 머리 숙임: 상단 머리 영역만 아래로 (밥먹기)
  - 기울임(shear): 행별 가로 이동량을 높이에 비례시켜 앞/뒤로 기울임 (공격/회피/아픔)
  - 스쿼시&스트레치: 바닥 고정 세로 스케일 (수면 호흡, 점프 준비/착지, 화남 들썩임)
  - 이펙트 글리프 오버레이 (Z, 반짝이, 화남 마크, 땀, 슬래시, 속도선, 밥그릇)

모든 스프라이트는 왼쪽을 보고 있다 → 공격은 -x 돌진, 음식은 왼쪽 아래,
걷기의 "앞다리"는 왼쪽 절반 컬럼.

사용법:
    python tool/generate_motion_data.py

출력:
    lib/core/pixel/pet_motion_data.dart
"""

import os
import sys

from generate_pixel_data import GRID, extract_sprite, format_rows

OUTPUT_PATH = os.path.join("lib", "core", "pixel", "pet_motion_data.dart")
FULL_MASK = (1 << GRID) - 1

# 모션 정의(이동량·글리프 좌표)는 32그리드 기준으로 작성되어 있다.
# GRID가 커지면 같은 비율로 확대해 시각적 진폭을 유지한다.
SCALE = GRID // 32


def sc(v):
    """32그리드 기준 좌표/이동량을 현재 GRID로 스케일."""
    return v * SCALE


def scale_glyph(glyph):
    """글리프의 각 도트를 SCALE x SCALE 블록으로 확대."""
    if SCALE == 1:
        return glyph
    out = []
    for x, y in glyph:
        for dy in range(SCALE):
            for dx in range(SCALE):
                out.append((x * SCALE + dx, y * SCALE + dy))
    return out

SPECIES_SOURCES = {
    "tiger": os.path.join("assets", "tiger1.png"),
    "bird": os.path.join("assets", "bird1.png"),
    "turtle": os.path.join("assets", "turtle1.png"),
    "dragon": os.path.join("assets", "dragon1.png"),
}

# ---------------------------------------------------------------------------
# 그리드 변형
# ---------------------------------------------------------------------------


def shift_mask(mask, dx):
    """행 비트마스크를 가로로 dx 이동 (그리드 밖 클리핑)."""
    if dx >= 0:
        return (mask << dx) & FULL_MASK
    return mask >> (-dx)


def normalize(sprite):
    """dark/body 겹침 제거 (dark 우선 — 아웃라인 유지)."""
    dark, body = sprite
    return list(dark), [b & ~d for b, d in zip(body, dark)]


def bbox(sprite):
    """도트가 있는 영역의 (min_x, max_x, min_y, max_y). 빈 스프라이트 불가."""
    dark, body = sprite
    min_x, max_x, min_y, max_y = GRID, -1, GRID, -1
    for y in range(GRID):
        mask = dark[y] | body[y]
        if not mask:
            continue
        min_y = min(min_y, y)
        max_y = max(max_y, y)
        min_x = min(min_x, (mask & -mask).bit_length() - 1)
        max_x = max(max_x, mask.bit_length() - 1)
    return min_x, max_x, min_y, max_y


def shift(sprite, dx, dy):
    """스프라이트를 (dx, dy)만큼 이동. 그리드 밖은 클리핑."""
    dark, body = sprite

    def shift_rows(rows):
        out = [0] * GRID
        for y in range(GRID):
            ny = y + dy
            if not 0 <= ny < GRID:
                continue
            out[ny] = shift_mask(rows[y], dx)
        return out

    return shift_rows(dark), shift_rows(body)


def lift(sprite, dy_up, allow_clip=None):
    """위로 dy_up 이동하되 머리 잘림은 allow_clip 도트까지만 허용."""
    if allow_clip is None:
        allow_clip = SCALE
    _, _, y0, _ = bbox(sprite)
    return shift(sprite, 0, -min(dy_up, y0 + allow_clip))


def region_shift(sprite, x0, x1, y0, y1, dx, dy):
    """(x0..x1, y0..y1) 사각 영역 안의 도트만 (dx, dy) 이동.

    이동한 도트는 기존 도트 위에 합쳐진다 (다리 들기, 머리 숙임 등
    부위별 변형용 — 겹침은 LCD 도트 스타일에서 자연스럽게 보임).
    """
    dark, body = list(sprite[0]), list(sprite[1])
    region_mask = 0
    for x in range(max(0, x0), min(GRID - 1, x1) + 1):
        region_mask |= 1 << x

    moved_dark = [0] * GRID
    moved_body = [0] * GRID
    for y in range(max(0, y0), min(GRID - 1, y1) + 1):
        d_sel = dark[y] & region_mask
        b_sel = body[y] & region_mask
        dark[y] &= ~region_mask
        body[y] &= ~region_mask
        ny = y + dy
        if not 0 <= ny < GRID:
            continue
        moved_dark[ny] |= shift_mask(d_sel, dx)
        moved_body[ny] |= shift_mask(b_sel, dx)

    for y in range(GRID):
        dark[y] |= moved_dark[y]
        body[y] |= moved_body[y]
    return normalize((dark, body))


def shear_x(sprite, max_dx):
    """높이에 비례해 행을 가로로 밀어 기울임.

    max_dx > 0: 머리가 +x(뒤)로 → 뒤로 젖힘,
    max_dx < 0: 머리가 -x(앞)로 → 앞으로 숙임/돌진 자세.
    바닥 행은 고정(0), 머리 행이 최대 이동.
    """
    dark, body = sprite
    _, _, y0, y1 = bbox(sprite)
    height = max(1, y1 - y0)
    new_dark = [0] * GRID
    new_body = [0] * GRID
    for y in range(GRID):
        if y0 <= y <= y1:
            dx = round(max_dx * (y1 - y) / height)
        else:
            dx = 0
        new_dark[y] = shift_mask(dark[y], dx)
        new_body[y] = shift_mask(body[y], dx)
    return new_dark, new_body


def stretch_y(sprite, factor):
    """바닥 고정 세로 스케일 (factor < 1 눌림, > 1 늘어남).

    역매핑(타깃 행 → 소스 행)이라 늘일 때 구멍이 생기지 않는다.
    늘어날 때 머리 잘림은 SCALE 도트까지만 허용하도록 factor를 자동 캡.
    """
    dark, body = sprite
    _, _, y0, y1 = bbox(sprite)
    height = y1 - y0
    if factor > 1.0 and height > 0:
        max_factor = 1.0 + (y0 + SCALE) / height
        factor = min(factor, max_factor)

    new_dark = [0] * GRID
    new_body = [0] * GRID
    for ny in range(GRID):
        if ny > y1:
            continue
        src = y1 - int(round((y1 - ny) / factor))
        if y0 <= src <= y1:
            new_dark[ny] |= dark[src]
            new_body[ny] |= body[src]
    return new_dark, new_body


def squash(sprite, factor):
    """세로로 눌러 바닥에 붙임 (stretch_y의 별칭, factor < 1.0)."""
    return stretch_y(sprite, factor)


def legs_box(sprite):
    """다리 영역 계산: (x0, x1, leg_top, y1, x_mid).

    하단 약 22% 높이를 다리로 보고, bbox 가운데 컬럼으로 앞/뒤를 나눈다.
    """
    x0, x1, y0, y1 = bbox(sprite)
    leg_h = max(2 * SCALE, round((y1 - y0 + 1) * 0.22))
    leg_top = y1 - leg_h + 1
    x_mid = (x0 + x1) // 2
    return x0, x1, leg_top, y1, x_mid


def step_pose(sprite, lead):
    """걷기 스텝 포즈 — 한쪽 다리를 들어 앞(-x)으로 내딛는 자세.

    lead='front': 앞다리(왼쪽 절반, 진행 방향 쪽)를 들어올림
    lead='back' : 뒷다리(오른쪽 절반)를 들어올림
    """
    x0, x1, leg_top, y1, x_mid = legs_box(sprite)
    step_up = sc(1)
    step_fwd = -sc(1)
    if lead == "front":
        return region_shift(sprite, x0, x_mid, leg_top, y1, step_fwd, -step_up)
    return region_shift(sprite, x_mid + 1, x1, leg_top, y1, step_fwd, -step_up)


def head_bow(sprite, depth):
    """머리 영역(상단 약 45%)만 앞(-x)·아래로 숙임 (밥먹기)."""
    x0, x1, y0, y1 = bbox(sprite)
    head_bottom = y0 + max(2 * SCALE, round((y1 - y0 + 1) * 0.45)) - 1
    return region_shift(sprite, x0, x1, y0, head_bottom, -sc(1), depth)


def overlay(sprite, glyph, ox, oy):
    """dark 도트 글리프를 (ox, oy) 기준으로 오버레이."""
    dark = list(sprite[0])
    body = list(sprite[1])
    for gx, gy in glyph:
        x, y = ox + gx, oy + gy
        if 0 <= x < GRID and 0 <= y < GRID:
            dark[y] |= 1 << x
            body[y] &= ~(1 << x)
    return dark, body


def blink(sprite):
    """몸통 도트를 지워 아웃라인만 남김 (피격 깜빡임)."""
    return list(sprite[0]), [0] * GRID


# ---------------------------------------------------------------------------
# 이펙트 글리프 (dark 도트 좌표)
# ---------------------------------------------------------------------------

GLYPH_Z = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]

GLYPH_SPARKLE = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]

# 💢 스타일 — 네 방향 대각선 틱
GLYPH_ANGER = [
    (0, 0), (1, 1),
    (4, 0), (3, 1),
    (0, 4), (1, 3),
    (4, 4), (3, 3),
]

GLYPH_SWEAT = [(1, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (1, 3)]

# 두 줄 대각선 슬래시 (공격 임팩트)
GLYPH_SLASH = [
    (4, 0), (3, 1), (2, 2), (1, 3), (0, 4),
    (6, 2), (5, 3), (4, 4), (3, 5), (2, 6),
]

# 가로 속도선 3줄 (회피)
GLYPH_SPEED = [
    (0, 0), (1, 0), (2, 0),
    (0, 4), (1, 4), (2, 4),
    (0, 8), (1, 8), (2, 8),
]

# 밥그릇 (7칸 폭): 수북 → 반 → 빈 그릇+부스러기
GLYPH_FOOD_FULL = (
    [(2, 0), (3, 0), (4, 0)]
    + [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    + [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
)
GLYPH_FOOD_HALF = (
    [(2, 1), (3, 1), (4, 1)]
    + [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
)
GLYPH_FOOD_EMPTY = (
    [(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]
    + [(1, 3), (2, 3), (3, 3), (4, 3), (5, 3)]
    + [(0, 1), (6, 1)]  # 부스러기
)

# 32그리드 기준 글리프를 현재 GRID 배율로 확대
GLYPH_Z = scale_glyph(GLYPH_Z)
GLYPH_SPARKLE = scale_glyph(GLYPH_SPARKLE)
GLYPH_ANGER = scale_glyph(GLYPH_ANGER)
GLYPH_SWEAT = scale_glyph(GLYPH_SWEAT)
GLYPH_SLASH = scale_glyph(GLYPH_SLASH)
GLYPH_SPEED = scale_glyph(GLYPH_SPEED)
GLYPH_FOOD_FULL = scale_glyph(GLYPH_FOOD_FULL)
GLYPH_FOOD_HALF = scale_glyph(GLYPH_FOOD_HALF)
GLYPH_FOOD_EMPTY = scale_glyph(GLYPH_FOOD_EMPTY)

FOOD_POS = (sc(1), sc(26))

# ---------------------------------------------------------------------------
# 모션 정의 — 각 함수는 3프레임 리스트 반환
# ---------------------------------------------------------------------------


def motion_walk(s):
    """걷기 사이클: 앞다리 스텝 → 패싱(양발 모으고 몸 올라감) → 뒷다리 스텝."""
    return [
        step_pose(s, "front"),
        lift(s, sc(1), allow_clip=0),
        step_pose(s, "back"),
    ]


def motion_eat(s):
    """머리를 그릇 쪽으로 숙였다 들며 밥이 줄어드는 사이클."""
    fx, fy = FOOD_POS
    return [
        overlay(head_bow(s, sc(1)), GLYPH_FOOD_FULL, fx, fy),
        overlay(head_bow(s, sc(3)), GLYPH_FOOD_HALF, fx, fy),
        overlay(s, GLYPH_FOOD_EMPTY, fx, fy),
    ]


def motion_sleep(s):
    """엎드린 자세로 호흡(들숨/날숨) + Z가 하나씩 올라감."""
    inhale = stretch_y(s, 0.70)
    exhale = stretch_y(s, 0.63)
    f1 = overlay(inhale, GLYPH_Z, sc(22), sc(7))
    f2 = overlay(exhale, GLYPH_Z, sc(22), sc(7))
    f2 = overlay(f2, GLYPH_Z, sc(25), sc(4))
    f3 = overlay(inhale, GLYPH_Z, sc(22), sc(7))
    f3 = overlay(f3, GLYPH_Z, sc(25), sc(4))
    f3 = overlay(f3, GLYPH_Z, sc(28), sc(1))
    return [f1, f2, f3]


def motion_attack(s):
    """웅크려 준비(뒤로 젖힘) → 앞으로 기울며 돌진 → 풀 런지 + 슬래시."""
    windup = shear_x(stretch_y(s, 0.93), sc(1))
    lunge = shear_x(shift(s, sc(-2), 0), -sc(1))
    strike = shear_x(shift(s, sc(-4), 0), -sc(2))
    return [
        windup,
        lunge,
        overlay(strike, GLYPH_SLASH, 0, sc(8)),
    ]


def motion_dodge(s):
    """몸을 뒤로 기울이며 물러났다 복귀."""
    lean_back = shear_x(shift(s, sc(3), 0), sc(2))
    recover = shear_x(shift(s, sc(1), 0), sc(1))
    return [
        s,
        overlay(lean_back, GLYPH_SPEED, 0, sc(10)),
        recover,
    ]


def motion_hurt(s):
    """뒤로 움찔(기울임) + 땀 → 피격 플래시 → 휘청이며 복귀."""
    recoil = shear_x(s, sc(1))
    stagger = shear_x(shift(s, sc(-1), 0), sc(1))
    return [
        overlay(recoil, GLYPH_SWEAT, sc(26), sc(3)),
        blink(shift(s, sc(1), 0)),
        overlay(stagger, GLYPH_SWEAT, sc(27), sc(6)),
    ]


def motion_angry(s):
    """씩씩대며 부풀었다 쿵 내려찍는 들썩임 + 💢 마크 떨림."""
    puffed = stretch_y(s, 1.08)
    stomp = shift(stretch_y(s, 0.93), sc(1), 0)
    return [
        overlay(puffed, GLYPH_ANGER, sc(24), sc(2)),
        overlay(stomp, GLYPH_ANGER, sc(23), sc(1)),
        overlay(puffed, GLYPH_ANGER, sc(25), sc(3)),
    ]


def motion_joy(s):
    """스쿼시&스트레치 점프: 웅크림 → 쭉 늘어나며 점프 → 착지 눌림."""
    crouch = stretch_y(s, 0.85)
    airborne = lift(stretch_y(s, 1.10), sc(3))
    landing = stretch_y(s, 0.92)
    f2 = overlay(airborne, GLYPH_SPARKLE, sc(2), sc(8))
    f2 = overlay(f2, GLYPH_SPARKLE, sc(27), sc(8))
    f3 = overlay(landing, GLYPH_SPARKLE, sc(1), sc(13))
    f3 = overlay(f3, GLYPH_SPARKLE, sc(28), sc(13))
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


def main() -> int:
    species_frames = {}
    for species, path in SPECIES_SOURCES.items():
        base = extract_sprite(path)
        if base is None:
            print("스프라이트 추출 실패: %s" % path, file=sys.stderr)
            return 1
        species_frames[species] = {
            name: [normalize(frame) for frame in build(base)]
            for name, build in MOTIONS.items()
        }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(
            "// GENERATED CODE - DO NOT EDIT BY HAND\n"
            "// tool/generate_motion_data.py 로 재생성:\n"
            "//   python tool/generate_motion_data.py\n"
            "//\n"
            "// 베이비(stage 2) 스프라이트의 모션 3프레임 합성 데이터.\n"
            "// 이동/찌그러뜨림 + 이펙트 글리프(Z, 반짝이, 화남 마크 등)로\n"
            "// 다마고치 LCD 방식 모션을 표현한다.\n"
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
    print("생성 완료: %s (%d개 프레임)" % (OUTPUT_PATH, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
