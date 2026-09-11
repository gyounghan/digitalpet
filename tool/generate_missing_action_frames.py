# -*- coding: utf-8 -*-
"""Generate first-pass sleep/eat PNG animation clips from original character art.

The source of truth for file names is:
  캐릭터_성장단계_행위_00001.png

Existing action clips are preserved. Missing clips are generated as 8 transparent
PNG frames by transforming the original character image and adding a small,
action-specific effect layer.
"""

from __future__ import annotations

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


def draw_sleep_effect(draw: ImageDraw.ImageDraw, size: tuple[int, int], frame_index: int) -> None:
    width, height = size
    phase = frame_index / FRAME_COUNT
    base_x = round(width * 0.68)
    base_y = round(height * (0.24 - 0.07 * phase))
    color = (89, 132, 205, max(60, round(170 * (1.0 - phase * 0.55))))
    stroke = max(1, round(min(width, height) * 0.018))

    for tier in range(3):
        offset = tier * round(min(width, height) * 0.09)
        scale = 1.0 - tier * 0.22
        z_width = max(5, round(width * 0.09 * scale))
        z_height = max(5, round(height * 0.075 * scale))
        x = base_x + offset // 2
        y = base_y - offset
        points = [
            (x, y),
            (x + z_width, y),
            (x, y + z_height),
            (x + z_width, y + z_height),
        ]
        draw.line(points[:2], fill=color, width=stroke)
        draw.line(points[1:3], fill=color, width=stroke)
        draw.line(points[2:], fill=color, width=stroke)


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
        sprite = transform_sprite(
            source,
            scale_x=1.03 + 0.015 * math.sin(phase),
            scale_y=0.90 + 0.025 * math.cos(phase),
            angle=math.sin(phase) * 1.2,
            offset_x=round(math.sin(phase) * source.width * 0.01),
            offset_y=round(source.height * 0.055 + math.cos(phase) * source.height * 0.012),
        )
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
    effects = Image.new("RGBA", source.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(effects)
    if action == "자기":
        draw_sleep_effect(draw, source.size, frame_index)
    else:
        draw_food_effect(draw, source.size, frame_index)
    out.alpha_composite(effects)
    return out


def write_clip(plan: ClipPlan) -> int:
    source = Image.open(plan.source_path).convert("RGBA")
    source = ImageOps.exif_transpose(source)
    written = 0
    for offset, frame_path in enumerate(plan.frame_paths):
        if frame_path.exists():
            continue
        frame = generate_frame(source, plan.action, offset)
        frame.save(frame_path)
        written += 1
    return written


def main() -> int:
    plans = build_missing_plans()
    if not plans:
        print("missing clips: 0")
        print("written frames: 0")
        return 0

    ANIMATION_DIR.mkdir(parents=True, exist_ok=True)
    written_frames = 0
    for plan in plans:
        written_frames += write_clip(plan)

    print(f"missing clips: {len(plans)}")
    print(f"written frames: {written_frames}")
    for plan in plans:
        print(f"{plan.character}_{plan.stage}_{plan.action}: {len(plan.frame_paths)} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
