from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parent

EIGHT_FRAME_CENTERS = (186, 334, 482, 630, 778, 926, 1074, 1222)
SIX_FRAME_CENTERS = (210, 407, 604, 801, 998, 1195)


def row(sheet, character, motion, y0, y1, centers):
    return {
        "sheet": sheet,
        "character": character,
        "motion": motion,
        "region": (110, y0, 1290, y1),
        "centers": centers,
    }


EXTRACTIONS = (
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "idle", 208, 293, EIGHT_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "walk", 322, 402, EIGHT_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "run", 433, 521, EIGHT_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "eat", 555, 645, SIX_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "sleep", 677, 760, SIX_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "happy", 789, 883, SIX_FRAME_CENTERS),
    row("hyunmoo-two-motion-sheet.png", "hyunmoo-two", "angry", 912, 1006, SIX_FRAME_CENTERS),
    {
        "sheet": "hyunmoo-two-motion-sheet.png",
        "character": "hyunmoo-two",
        "motion": "hurt",
        "region": (110, 1038, 645, 1148),
        "centers": (174, 305, 436, 568),
    },
    {
        "sheet": "hyunmoo-two-motion-sheet.png",
        "character": "hyunmoo-two",
        "motion": "recover",
        "region": (758, 1038, 1280, 1148),
        "centers": (820, 950, 1080, 1210),
    },
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "idle", 208, 300, EIGHT_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "walk", 322, 416, EIGHT_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "run", 440, 535, EIGHT_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "eat", 559, 651, SIX_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "sleep", 680, 762, SIX_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "happy", 783, 881, SIX_FRAME_CENTERS),
    row("hyunmoo-three-motion-sheet.png", "hyunmoo-three", "angry", 906, 1007, SIX_FRAME_CENTERS),
    {
        "sheet": "hyunmoo-three-motion-sheet.png",
        "character": "hyunmoo-three",
        "motion": "hurt",
        "region": (90, 1038, 410, 1149),
        "centers": (133, 214, 298, 371),
    },
    {
        "sheet": "hyunmoo-three-motion-sheet.png",
        "character": "hyunmoo-three",
        "motion": "recover",
        "region": (450, 1038, 732, 1149),
        "centers": (510, 594, 682),
        "label_overlap": (474, 494, 1097),
        # The source labels four frames but contains three distinct drawings.
        "sequence": (0, 1, 1, 2),
    },
    {
        "sheet": "hyunmoo-three-motion-sheet.png",
        "character": "hyunmoo-three",
        "motion": "roar",
        "region": (834, 1038, 1290, 1149),
        "centers": (872, 938, 1008, 1084, 1176, 1254),
    },
)


def foreground_mask(image):
    pixels = np.asarray(image.convert("RGB"))
    brightest = pixels.max(axis=2)
    return brightest > 85


def component_masks(mask, min_area=3):
    labels, count = ndimage.label(mask)
    components = []
    for label in range(1, count + 1):
        component = labels == label
        area = int(component.sum())
        if area < min_area:
            continue
        ys, xs = np.where(component)
        components.append((float(xs.mean()), component))
    return components


def extracted_pose(
    source,
    region,
    centers,
    pose_index,
    label_overlap=None,
):
    x0, y0, x1, y1 = region
    crop = source.crop(region).convert("RGBA")
    masks = [np.zeros((y1 - y0, x1 - x0), dtype=bool) for _ in centers]

    foreground = foreground_mask(crop)
    if label_overlap is not None:
        keep_x, label_right, keep_y = label_overlap
        ys, xs = np.indices(foreground.shape)
        global_xs = x0 + xs
        global_ys = y0 + ys
        label_pixels = (global_xs < label_right) & (
            (global_xs < keep_x) | (global_ys < keep_y)
        )
        foreground[label_pixels] = False

    for local_center, component in component_masks(foreground):
        global_center = x0 + local_center
        nearest = min(range(len(centers)), key=lambda index: abs(centers[index] - global_center))
        masks[nearest] |= component

    mask_image = Image.fromarray((masks[pose_index] * 255).astype(np.uint8), mode="L")
    mask_image = mask_image.filter(ImageFilter.MaxFilter(5))
    bbox = mask_image.getbbox()
    if bbox is None:
        raise RuntimeError(f"No foreground found for pose {pose_index}")

    left, top, right, bottom = bbox
    padding = 4
    bbox = (
        max(0, left - padding),
        max(0, top - padding),
        min(crop.width, right + padding),
        min(crop.height, bottom + padding),
    )
    crop.putalpha(mask_image)
    center_x = centers[pose_index] - x0
    return {
        "image": crop.crop(bbox),
        "bbox": bbox,
        "left_from_center": bbox[0] - center_x,
        "right_from_center": bbox[2] - center_x,
    }


def normalize_poses(poses, height):
    left = min(pose["left_from_center"] for pose in poses)
    right = max(pose["right_from_center"] for pose in poses)
    width = right - left
    normalized = []

    for pose in poses:
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        bbox = pose["bbox"]
        x = pose["left_from_center"] - left
        canvas.alpha_composite(pose["image"], (x, bbox[1]))
        normalized.append(canvas)
    return normalized


def extract(config):
    source = Image.open(ROOT / config["sheet"])
    centers = config["centers"]
    extracted = [
        extracted_pose(
            source,
            config["region"],
            centers,
            index,
            config.get("label_overlap"),
        )
        for index in range(len(centers))
    ]
    poses = normalize_poses(extracted, config["region"][3] - config["region"][1])
    sequence = config.get("sequence", tuple(range(len(poses))))
    output_dir = ROOT / "frames" / config["character"]
    output_dir.mkdir(parents=True, exist_ok=True)

    for frame_index, pose_index in enumerate(sequence, start=1):
        path = output_dir / f"{config['motion']}-{frame_index:02d}.png"
        poses[pose_index].save(path, optimize=True)


if __name__ == "__main__":
    for extraction in EXTRACTIONS:
        extract(extraction)
