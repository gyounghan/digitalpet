from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parent


def row(sheet, character, motion, y0, y1, centers):
    return {
        "sheet": sheet,
        "character": character,
        "motion": motion,
        "region": (145, y0, 1515, y1),
        "centers": centers,
    }


EXTRACTIONS = (
    row(
        "hyunmoo-growth-motion-sheet.png",
        "hyunmoo-growth",
        "walk",
        277,
        405,
        (250, 443, 636, 830, 1023, 1216, 1410),
    ),
    row(
        "hyunmoo-growth-motion-sheet.png",
        "hyunmoo-growth",
        "eat",
        452,
        574,
        (246, 466, 695, 910, 1125, 1340),
    ),
    row(
        "hyunmoo-growth-motion-sheet.png",
        "hyunmoo-growth",
        "sleep",
        620,
        743,
        (262, 483, 704, 936, 1160, 1390),
    ),
    row(
        "hyunmoo-growth-motion-sheet.png",
        "hyunmoo-growth",
        "happy",
        778,
        956,
        (262, 476, 707, 900, 1125, 1375),
    ),
    row(
        "hyunmoo-mature-motion-sheet.png",
        "hyunmoo-mature",
        "walk",
        302,
        439,
        (223, 395, 567, 740, 912, 1084, 1261, 1430),
    ),
    row(
        "hyunmoo-mature-motion-sheet.png",
        "hyunmoo-mature",
        "eat",
        475,
        616,
        (238, 456, 656, 873, 1097, 1330),
    ),
    row(
        "hyunmoo-mature-motion-sheet.png",
        "hyunmoo-mature",
        "sleep",
        657,
        790,
        (244, 470, 684, 931, 1155, 1393),
    ),
    row(
        "hyunmoo-mature-motion-sheet.png",
        "hyunmoo-mature",
        "happy",
        813,
        988,
        (252, 470, 698, 916, 1150, 1387),
    ),
)


def foreground_mask(image):
    pixels = np.asarray(image.convert("RGB"))
    darkest = pixels.min(axis=2)
    saturation = pixels.max(axis=2) - darkest
    return (darkest < 245) | (saturation > 10)


def component_masks(mask, min_area=3):
    labels, count = ndimage.label(mask)
    components = []
    for label in range(1, count + 1):
        component = labels == label
        if int(component.sum()) < min_area:
            continue
        _, xs = np.where(component)
        components.append((float(xs.mean()), component))
    return components


def extracted_pose(source, region, centers, pose_index):
    x0, y0, x1, y1 = region
    crop = source.crop(region).convert("RGBA")
    masks = [np.zeros((y1 - y0, x1 - x0), dtype=bool) for _ in centers]

    for local_center, component in component_masks(foreground_mask(crop)):
        global_center = x0 + local_center
        nearest = min(
            range(len(centers)),
            key=lambda index: abs(centers[index] - global_center),
        )
        masks[nearest] |= component

    mask_image = Image.fromarray(
        (masks[pose_index] * 255).astype(np.uint8),
        mode="L",
    ).filter(ImageFilter.MaxFilter(3))
    bbox = mask_image.getbbox()
    if bbox is None:
        raise RuntimeError(f"No foreground found for pose {pose_index}")

    left, top, right, bottom = bbox
    padding = 3
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
        extracted_pose(source, config["region"], centers, index)
        for index in range(len(centers))
    ]
    poses = normalize_poses(extracted, config["region"][3] - config["region"][1])
    output_dir = ROOT / "frames" / config["character"]
    output_dir.mkdir(parents=True, exist_ok=True)

    for frame_index, pose in enumerate(poses, start=1):
        path = output_dir / f"{config['motion']}-{frame_index:02d}.png"
        pose.save(path, optimize=True)


if __name__ == "__main__":
    for extraction in EXTRACTIONS:
        extract(extraction)
