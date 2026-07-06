# -*- coding: utf-8 -*-
"""생성된 모션 프레임을 터미널 ASCII로 미리보기.

사용법: python tool/preview_motion.py <species> <motion> [frame]
"""

import re
import sys


def load_frames(species, motion):
    src = open("lib/core/pixel/pet_motion_data.dart", encoding="utf-8").read()
    species_match = re.search(
        r"'%s': \{(.*?)\n  \}," % species, src, re.S
    )
    block = species_match.group(1)
    # 주의: 행 비트마스크 리스트도 "\n    ]," 로 닫히므로 (같은 들여쓰기),
    # 모션 리스트의 끝은 뒤에 다음 모션 키(')가 오거나 종 블록이 끝나는 지점.
    # (마지막 모션은 species 블록 그룹의 끝(\Z)에서 닫힌다)
    motion_match = re.search(
        r"'%s': \[(.*?)\n    \],?\n?(?=    '|\Z)" % motion, block, re.S
    )
    motion_block = motion_match.group(1)
    sprites = re.findall(
        r"dark: \[(.*?)\],\s*body: \[(.*?)\],\s*accent: \[(.*?)\],",
        motion_block,
        re.S,
    )
    result = []
    for dark_src, body_src, accent_src in sprites:
        dark = [int(x, 16) for x in re.findall(r"0x[0-9A-F]+", dark_src)]
        body = [int(x, 16) for x in re.findall(r"0x[0-9A-F]+", body_src)]
        accent = [int(x, 16) for x in re.findall(r"0x[0-9A-F]+", accent_src)]
        result.append((dark, body, accent))
    return result


def render(dark, body, accent=None):
    n = len(dark)
    accent = accent or [0] * n
    # 32그리드 이하는 가로 2배 폭으로(정사각 비율 보정)
    wide = n <= 32
    for y in range(n):
        line = ""
        for x in range(n):
            if dark[y] >> x & 1:
                line += "@@" if wide else "@"
            elif accent[y] >> x & 1:
                line += "++" if wide else "+"
            elif body[y] >> x & 1:
                line += ".." if wide else "."
            else:
                line += "  " if wide else " "
        print(line.rstrip())


def main():
    species = sys.argv[1] if len(sys.argv) > 1 else "dragon"
    motion = sys.argv[2] if len(sys.argv) > 2 else "sleep"
    frames = load_frames(species, motion)
    if len(sys.argv) > 3:
        idx = int(sys.argv[3])
        print("=== %s %s frame %d ===" % (species, motion, idx + 1))
        render(*frames[idx])
    else:
        for i, frame in enumerate(frames):
            print("=== %s %s frame %d ===" % (species, motion, i + 1))
            render(*frame)


if __name__ == "__main__":
    main()
