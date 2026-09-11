# -*- coding: utf-8 -*-
"""Generate missing or corrected sleep/eat PNG animation clips from character art.

The source of truth for file names is:
  캐릭터_성장단계_행위_00001.png

By default existing action clips are preserved. The --redo-sleep mode refreshes
generated sleep clips while keeping the hand-made sleep references intact.
"""

from __future__ import annotations

import argparse
import math
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT_DIR = Path(__file__).resolve().parents[1]
ANIMATION_DIR = ROOT_DIR / "tool" / "animaition"
CHARACTER_DIR = ROOT_DIR / "tool" / "character"
FRAME_COUNT = 8
TARGET_ACTIONS = ("먹기", "자기")
SLEEP_ACTION = "자기"
HANDMADE_SLEEP_CLIPS = frozenset({("구미호", "유아기"), ("백호", "유아기")})
STAGE_ORDER = ("유아기", "성장기", "성숙기")
ACTION_ORDER = ("걷기", "먹기", "자기", "기쁨", "화남", "포효")
FILENAME_RE = re.compile(r"^(.+?)_(유아기|성장기|성숙기)(?:_(.+?)_(\d+))?\.png$")


@dataclass(frozen=True)
class CharacterSource:
    character: str
    stage: str
    path: Path


@dataclass(frozen=True)
class ClipPlan:
    character: str
    stage: str
    action: str
    source_path: Path
    frame_paths: tuple[Path, ...]


@dataclass(frozen=True)
class SleepProfile:
    scale_x: float
    scale_y: float
    angle: float
    eyes: tuple[tuple[float, float], ...]
    z_anchor: tuple[float, float]
    breath_anchor: tuple[float, float]
    eye_stroke: tuple[int, int, int, int] = (54, 38, 32, 255)
    z_color: tuple[int, int, int] = (93, 138, 208)
    x_offset_ratio: float = 0.0
    baseline_offset_ratio: float = 0.025
    breath: float = 0.035


DEFAULT_SLEEP_PROFILE = SleepProfile(
    scale_x=1.16,
    scale_y=0.58,
    angle=-3.0,
    eyes=((0.43, 0.45), (0.55, 0.45)),
    z_anchor=(0.72, 0.08),
    breath_anchor=(0.62, 0.48),
)

SLEEP_PROFILES = {
    "구미호": SleepProfile(
        scale_x=1.18,
        scale_y=0.56,
        angle=-4.0,
        eyes=((0.39, 0.46), (0.50, 0.46)),
        z_anchor=(0.72, 0.04),
        breath_anchor=(0.62, 0.45),
        z_color=(114, 148, 211),
    ),
    "달토끼": SleepProfile(
        scale_x=1.18,
        scale_y=0.52,
        angle=-5.0,
        eyes=((0.42, 0.48), (0.55, 0.48)),
        z_anchor=(0.70, 0.03),
        breath_anchor=(0.65, 0.44),
        eye_stroke=(67, 48, 80, 255),
        z_color=(118, 147, 224),
    ),
    "두꺼비": SleepProfile(
        scale_x=1.18,
        scale_y=0.55,
        angle=-1.0,
        eyes=((0.40, 0.43), (0.58, 0.43)),
        z_anchor=(0.72, 0.06),
        breath_anchor=(0.64, 0.42),
        eye_stroke=(56, 49, 31, 255),
        z_color=(105, 159, 131),
    ),
    "백호": SleepProfile(
        scale_x=1.17,
        scale_y=0.56,
        angle=-3.0,
        eyes=((0.42, 0.46), (0.54, 0.46)),
        z_anchor=(0.72, 0.04),
        breath_anchor=(0.62, 0.46),
        eye_stroke=(58, 45, 62, 255),
        z_color=(111, 139, 206),
    ),
    "삼족오": SleepProfile(
        scale_x=1.16,
        scale_y=0.54,
        angle=3.0,
        eyes=((0.47, 0.44), (0.57, 0.45)),
        z_anchor=(0.72, 0.03),
        breath_anchor=(0.62, 0.42),
        eye_stroke=(238, 153, 66, 255),
        z_color=(225, 132, 48),
        baseline_offset_ratio=0.015,
    ),
    "주작": SleepProfile(
        scale_x=1.18,
        scale_y=0.53,
        angle=-3.0,
        eyes=((0.45, 0.44), (0.56, 0.45)),
        z_anchor=(0.72, 0.03),
        breath_anchor=(0.63, 0.42),
        eye_stroke=(75, 39, 20, 255),
        z_color=(236, 139, 45),
        baseline_offset_ratio=0.015,
    ),
    "지리산곰": SleepProfile(
        scale_x=1.16,
        scale_y=0.57,
        angle=-2.0,
        eyes=((0.42, 0.45), (0.55, 0.45)),
        z_anchor=(0.72, 0.04),
        breath_anchor=(0.62, 0.45),
        eye_stroke=(52, 32, 23, 255),
        z_color=(119, 151, 207),
    ),
    "청룡": SleepProfile(
        scale_x=1.12,
        scale_y=0.58,
        angle=4.0,
        eyes=((0.47, 0.43),),
        z_anchor=(0.74, 0.02),
        breath_anchor=(0.63, 0.42),
        eye_stroke=(27, 64, 105, 255),
        z_color=(74, 156, 219),
        x_offset_ratio=-0.015,
        breath=0.03,
    ),
    "해태": SleepProfile(
        scale_x=1.17,
        scale_y=0.56,
        angle=-3.0,
        eyes=((0.42, 0.46), (0.54, 0.46)),
        z_anchor=(0.72, 0.04),
        breath_anchor=(0.62, 0.45),
        eye_stroke=(38, 60, 91, 255),
        z_color=(120, 151, 220),
    ),
    "현무": SleepProfile(
        scale_x=1.15,
        scale_y=0.55,
        angle=-1.0,
        eyes=((0.43, 0.44), (0.57, 0.44)),
        z_anchor=(0.73, 0.05),
        breath_anchor=(0.64, 0.42),
        eye_stroke=(35, 55, 31, 255),
        z_color=(95, 156, 133),
    ),
}


def normalize_name(value: str) -> str:
    return unicodedata.normalize("NFC", value)


def stage_rank(stage: str) -> tuple[int, str]:
    try:
        return STAGE_ORDER.index(stage), stage
    except ValueError:
        return len(STAGE_ORDER), stage


def action_rank(action: str) -> tuple[int, str]:
    try:
        return ACTION_ORDER.index(action), action
    except ValueError:
        return len(ACTION_ORDER), action


def character_sources() -> list[CharacterSource]:
    sources: list[CharacterSource] = []
    for path in CHARACTER_DIR.iterdir():
        if path.suffix.lower() != ".png":
            continue
        match = FILENAME_RE.match(normalize_name(path.name))
        if not match:
            continue
        character, stage = match.group(1), match.group(2)
        sources.append(CharacterSource(character, stage, path))
    return sorted(sources, key=lambda item: (item.character, stage_rank(item.stage)))


def existing_action_keys() -> set[tuple[str, str, str]]:
    keys: set[tuple[str, str, str]] = set()
    for path in ANIMATION_DIR.iterdir():
        if path.suffix.lower() != ".png":
            continue
        match = FILENAME_RE.match(normalize_name(path.name))
        if not match or match.group(3) is None:
            continue
        keys.add((match.group(1), match.group(2), normalize_name(match.group(3))))
    return keys


def frame_name(character: str, stage: str, action: str, index: int) -> str:
    return f"{character}_{stage}_{action}_{index:05d}.png"


def build_missing_plans() -> list[ClipPlan]:
    existing = existing_action_keys()
    plans: list[ClipPlan] = []
    for source in character_sources():
        for action in sorted(TARGET_ACTIONS, key=action_rank):
            if (source.character, source.stage, action) in existing:
                continue
            frame_paths = tuple(
                ANIMATION_DIR / frame_name(source.character, source.stage, action, index)
                for index in range(1, FRAME_COUNT + 1)
            )
            plans.append(ClipPlan(source.character, source.stage, action, source.path, frame_paths))
    return plans


def build_sleep_redo_plans() -> list[ClipPlan]:
    plans: list[ClipPlan] = []
    for source in character_sources():
        if (source.character, source.stage) in HANDMADE_SLEEP_CLIPS:
            continue
        frame_paths = tuple(
            ANIMATION_DIR / frame_name(source.character, source.stage, SLEEP_ACTION, index)
            for index in range(1, FRAME_COUNT + 1)
        )
        plans.append(ClipPlan(source.character, source.stage, SLEEP_ACTION, source.path, frame_paths))
    return plans


def sleep_profile_for(character: str, stage: str) -> SleepProfile:
    profile = SLEEP_PROFILES.get(character, DEFAULT_SLEEP_PROFILE)
    if stage == "유아기" and character not in {"달토끼"}:
        return SleepProfile(
            scale_x=profile.scale_x + 0.03,
            scale_y=max(0.50, profile.scale_y - 0.02),
            angle=profile.angle,
            eyes=profile.eyes,
            z_anchor=profile.z_anchor,
            breath_anchor=profile.breath_anchor,
            eye_stroke=profile.eye_stroke,
            z_color=profile.z_color,
            x_offset_ratio=profile.x_offset_ratio,
            baseline_offset_ratio=profile.baseline_offset_ratio,
            breath=profile.breath,
        )
    return profile


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    return bbox


def transform_sprite(
    image: Image.Image,
    *,
    scale_x: float,
    scale_y: float,
    angle: float,
    offset_x: int,
    offset_y: int,
) -> Image.Image:
    bbox = alpha_bbox(image)
    cropped = image.crop(bbox)
    new_size = (
        max(1, round(cropped.width * scale_x)),
        max(1, round(cropped.height * scale_y)),
    )
    resample = Image.Resampling.NEAREST
    transformed = cropped.resize(new_size, resample)
    if angle:
        transformed = transformed.rotate(angle, resample=resample, expand=True)

    canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
    base_x = bbox[0] + (cropped.width - transformed.width) // 2 + offset_x
    base_y = bbox[1] + cropped.height - transformed.height + offset_y
    canvas.alpha_composite(transformed, (base_x, base_y))
    return canvas


def generate_sleep_pose(source: Image.Image, profile: SleepProfile, frame_index: int) -> Image.Image:
    bbox = alpha_bbox(source)
    cropped = source.crop(bbox)
    phase = frame_index / FRAME_COUNT * math.tau
    inhale = math.sin(phase)

    scale_x = profile.scale_x * (1.0 - profile.breath * 0.35 * inhale)
    scale_y = profile.scale_y * (1.0 + profile.breath * inhale)
    new_size = (
        max(1, round(cropped.width * scale_x)),
        max(1, round(cropped.height * scale_y)),
    )
    resample = Image.Resampling.NEAREST
    transformed = cropped.resize(new_size, resample)
    angle = profile.angle + math.sin(phase + math.pi / 4) * 0.55
    transformed = transformed.rotate(angle, resample=resample, expand=True)

    canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_center_x = bbox[0] + cropped.width / 2
    baseline = min(
        source.height,
        bbox[3] + round(source.height * profile.baseline_offset_ratio) + round(math.cos(phase) * source.height * 0.004),
    )
    base_x = round(source_center_x - transformed.width / 2 + source.width * profile.x_offset_ratio)
    base_y = round(baseline - transformed.height)
    base_x = max(0, min(source.width - transformed.width, base_x))
    base_y = max(0, min(source.height - transformed.height, base_y))
    canvas.alpha_composite(transformed, (base_x, base_y))
    return canvas


def average_cover_color(image: Image.Image, center: tuple[int, int], radius: int) -> tuple[int, int, int, int]:
    cx, cy = center
    pixels: list[tuple[int, int, int, int]] = []
    fallback_pixels: list[tuple[int, int, int, int]] = []
    for y in range(max(0, cy - radius * 2), min(image.height, cy + radius * 2 + 1)):
        for x in range(max(0, cx - radius * 2), min(image.width, cx + radius * 2 + 1)):
            pixel = image.getpixel((x, y))
            if pixel[3] < 120:
                continue
            fallback_pixels.append(pixel)
            if max(pixel[:3]) > 70 and sum(pixel[:3]) > 190:
                pixels.append(pixel)
    sample = pixels or fallback_pixels
    if not sample:
        return (235, 224, 210, 210)
    red = sum(pixel[0] for pixel in sample) // len(sample)
    green = sum(pixel[1] for pixel in sample) // len(sample)
    blue = sum(pixel[2] for pixel in sample) // len(sample)
    return (red, green, blue, 230)


def draw_closed_eyes(image: Image.Image, bbox: tuple[int, int, int, int], profile: SleepProfile) -> None:
    draw = ImageDraw.Draw(image)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    if width <= 0 or height <= 0:
        return

    stroke_width = max(1, round(min(width, height) * 0.035))
    eye_width = max(4, round(width * 0.095))
    eye_height = max(3, round(height * 0.115))
    for eye_x, eye_y in profile.eyes:
        x = round(bbox[0] + width * eye_x)
        y = round(bbox[1] + height * eye_y)
        cover = average_cover_color(image, (x, y), max(2, eye_width // 2))
        draw.ellipse(
            (x - eye_width, y - eye_height, x + eye_width, y + eye_height),
            fill=cover,
        )
        draw.arc(
            (x - eye_width, y - eye_height, x + eye_width, y + eye_height),
            start=20,
            end=160,
            fill=profile.eye_stroke,
            width=stroke_width,
        )


def draw_sleep_effect(
    draw: ImageDraw.ImageDraw,
    size: tuple[int, int],
    bbox: tuple[int, int, int, int],
    profile: SleepProfile,
    frame_index: int,
) -> None:
    width, height = size
    bbox_width = bbox[2] - bbox[0]
    bbox_height = bbox[3] - bbox[1]
    phase = frame_index / FRAME_COUNT
    base_x = round(bbox[0] + bbox_width * profile.z_anchor[0])
    base_y = round(bbox[1] + bbox_height * profile.z_anchor[1] - height * 0.045 * phase)
    red, green, blue = profile.z_color
    stroke = max(1, round(min(width, height) * 0.014))

    for tier in range(3):
        offset = tier * round(min(width, height) * 0.06)
        scale = 1.0 - tier * 0.22
        z_width = max(4, round(width * 0.055 * scale))
        z_height = max(4, round(height * 0.05 * scale))
        x = base_x + offset // 2
        y = base_y - offset
        alpha = max(55, round(175 * (1.0 - phase * 0.50) * scale))
        color = (red, green, blue, alpha)
        points = [
            (x, y),
            (x + z_width, y),
            (x, y + z_height),
            (x + z_width, y + z_height),
        ]
        draw.line(points[:2], fill=color, width=stroke)
        draw.line(points[1:3], fill=color, width=stroke)
        draw.line(points[2:], fill=color, width=stroke)

    bubble_phase = math.sin(frame_index / FRAME_COUNT * math.tau)
    breath_x = round(bbox[0] + bbox_width * profile.breath_anchor[0] + bubble_phase * width * 0.012)
    breath_y = round(bbox[1] + bbox_height * profile.breath_anchor[1] - phase * height * 0.035)
    radius = max(2, round(min(width, height) * (0.025 + phase * 0.01)))
    draw.ellipse(
        (breath_x - radius, breath_y - radius, breath_x + radius, breath_y + radius),
        fill=(207, 238, 235, max(45, round(112 * (1.0 - phase * 0.35)))),
        outline=(132, 196, 205, max(50, round(150 * (1.0 - phase * 0.25)))),
        width=max(1, stroke),
    )


def draw_food_effect(draw: ImageDraw.ImageDraw, size: tuple[int, int], frame_index: int) -> None:
    width, height = size
    progress = frame_index / (FRAME_COUNT - 1)
    mouth_x = width * 0.58
    mouth_y = height * 0.58
    start_x = width * 0.82
    start_y = height * 0.72
    x = round(start_x + (mouth_x - start_x) * progress)
    y = round(start_y + (mouth_y - start_y) * progress + math.sin(progress * math.pi) * -height * 0.08)
    radius = max(2, round(min(width, height) * 0.028))

    bowl_y = round(height * 0.78)
    bowl_x = round(width * 0.72)
    bowl_w = round(width * 0.18)
    bowl_h = round(height * 0.055)
    draw.ellipse(
        (bowl_x - bowl_w // 2, bowl_y - bowl_h // 2, bowl_x + bowl_w // 2, bowl_y + bowl_h),
        fill=(210, 96, 66, 170),
    )
    draw.arc(
        (bowl_x - bowl_w // 2, bowl_y - bowl_h, bowl_x + bowl_w // 2, bowl_y + bowl_h),
        0,
        180,
        fill=(91, 53, 41, 190),
        width=max(1, round(radius * 0.55)),
    )
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(246, 184, 66, 210))

    for crumb in range(2):
        jitter = crumb + frame_index
        crumb_x = round(x - radius * (2 + crumb) + math.sin(jitter) * radius)
        crumb_y = round(y + radius * (crumb - 1) + math.cos(jitter) * radius)
        tiny = max(1, radius // 2)
        draw.ellipse(
            (crumb_x - tiny, crumb_y - tiny, crumb_x + tiny, crumb_y + tiny),
            fill=(250, 219, 111, 160),
        )


def generate_frame(source: Image.Image, action: str, frame_index: int) -> Image.Image:
    phase = frame_index / FRAME_COUNT * math.tau

    if action == "자기":
        profile = sleep_profile_for("", "")
        sprite = generate_sleep_pose(source, profile, frame_index)
    else:
        sprite = transform_sprite(
            source,
            scale_x=1.0 + 0.025 * math.sin(phase),
            scale_y=1.0 - 0.02 * math.sin(phase),
            angle=math.sin(phase) * 0.9,
            offset_x=round(math.sin(phase) * source.width * 0.026),
            offset_y=round(abs(math.sin(phase)) * source.height * 0.012),
        )

    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    out.alpha_composite(sprite)
    sprite_bbox = alpha_bbox(sprite)
    if action == "자기":
        draw_closed_eyes(out, sprite_bbox, profile)
    effects = Image.new("RGBA", source.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(effects)
    if action == "자기":
        draw_sleep_effect(draw, source.size, sprite_bbox, profile, frame_index)
    else:
        draw_food_effect(draw, source.size, frame_index)
    out.alpha_composite(effects)
    return out


def generate_planned_frame(source: Image.Image, plan: ClipPlan, frame_index: int) -> Image.Image:
    if plan.action == SLEEP_ACTION:
        profile = sleep_profile_for(plan.character, plan.stage)
        sprite = generate_sleep_pose(source, profile, frame_index)
        out = Image.new("RGBA", source.size, (0, 0, 0, 0))
        out.alpha_composite(sprite)
        sprite_bbox = alpha_bbox(sprite)
        draw_closed_eyes(out, sprite_bbox, profile)
        effects = Image.new("RGBA", source.size, (0, 0, 0, 0))
        draw_sleep_effect(ImageDraw.Draw(effects), source.size, sprite_bbox, profile, frame_index)
        out.alpha_composite(effects)
        return out
    return generate_frame(source, plan.action, frame_index)


def write_clip(plan: ClipPlan, *, overwrite: bool = False) -> int:
    source = Image.open(plan.source_path).convert("RGBA")
    source = ImageOps.exif_transpose(source)
    written = 0
    for offset, frame_path in enumerate(plan.frame_paths):
        if frame_path.exists() and not overwrite:
            continue
        frame = generate_planned_frame(source, plan, offset)
        frame.save(frame_path)
        written += 1
    return written


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--redo-sleep",
        action="store_true",
        help="overwrite generated sleep clips while preserving hand-made sleep references",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    plans = build_sleep_redo_plans() if args.redo_sleep else build_missing_plans()
    overwrite = args.redo_sleep
    label = "sleep redo clips" if args.redo_sleep else "missing clips"
    if not plans:
        print(f"{label}: 0")
        print("written frames: 0")
        return 0

    ANIMATION_DIR.mkdir(parents=True, exist_ok=True)
    written_frames = 0
    for plan in plans:
        written_frames += write_clip(plan, overwrite=overwrite)

    print(f"{label}: {len(plans)}")
    print(f"written frames: {written_frames}")
    for plan in plans:
        print(f"{plan.character}_{plan.stage}_{plan.action}: {len(plan.frame_paths)} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
