import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


SCRIPT_PATH = Path(__file__).with_name("generate_missing_action_frames.py")
SPEC = importlib.util.spec_from_file_location("generate_missing_action_frames", SCRIPT_PATH)
generator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generator
SPEC.loader.exec_module(generator)


def make_source(path: Path) -> None:
    image = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((28, 12, 68, 84), radius=10, fill=(112, 153, 93, 255))
    draw.ellipse((38, 24, 46, 32), fill=(28, 24, 22, 255))
    draw.ellipse((52, 24, 60, 32), fill=(28, 24, 22, 255))
    image.save(path)


def alpha_height(image: Image.Image) -> int:
    bbox = generator.alpha_bbox(image)
    return bbox[3] - bbox[1]


class SleepGenerationTests(unittest.TestCase):
    def test_sleep_redo_plans_preserve_handmade_reference_clips(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            characters = root / "character"
            animations = root / "animaition"
            characters.mkdir()
            animations.mkdir()

            for name in ("구미호_유아기.png", "백호_유아기.png", "청룡_성장기.png"):
                make_source(characters / name)

            original_character_dir = generator.CHARACTER_DIR
            original_animation_dir = generator.ANIMATION_DIR
            try:
                generator.CHARACTER_DIR = characters
                generator.ANIMATION_DIR = animations

                plans = generator.build_sleep_redo_plans()
            finally:
                generator.CHARACTER_DIR = original_character_dir
                generator.ANIMATION_DIR = original_animation_dir

        self.assertEqual([(plan.character, plan.stage, plan.action) for plan in plans], [("청룡", "성장기", "자기")])
        self.assertEqual(plans[0].frame_paths[0].name, "청룡_성장기_자기_00001.png")
        self.assertEqual(plans[0].frame_paths[-1].name, "청룡_성장기_자기_00008.png")

    def test_sleep_pose_is_lower_than_the_standing_source(self) -> None:
        source = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        draw = ImageDraw.Draw(source)
        draw.rounded_rectangle((30, 10, 66, 86), radius=9, fill=(94, 128, 208, 255))

        profile = generator.sleep_profile_for("청룡", "성장기")
        posed = generator.generate_sleep_pose(source, profile, frame_index=0)

        source_bbox = generator.alpha_bbox(source)
        posed_bbox = generator.alpha_bbox(posed)
        self.assertLessEqual(alpha_height(posed), round(alpha_height(source) * 0.72))
        self.assertGreaterEqual(posed_bbox[3], source_bbox[3] - 2)


if __name__ == "__main__":
    unittest.main()
