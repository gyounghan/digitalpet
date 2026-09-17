# -*- coding: utf-8 -*-
"""새 4지 청룡 캐릭터의 스프라이트시트를 내려받아 애니 프레임으로 잘라
tool/pixellab/청룡_{단계}_{모션}_{i}.png 로 저장한다.

pixellab 스프라이트시트 zip = 시트 PNG + layout JSON(rows: rotations/animation).
animation 행마다 animation 이름(한글)·frame_count가 있어 셀(108px)로 슬라이스한다.

사용: python tool/import_snake_spritesheets.py
"""
import io
import json
import os
import urllib.request
import zipfile
from PIL import Image

# character_id : 단계(한글)
CHARS = {
    "cbf3c538-cd67-48b5-9cad-7ec6b898d1d2": "유아기",
    "63f5cf82-4e05-4c84-b21d-fdb2a649f174": "성장기",
    "0b94b7a7-2a42-45de-ac88-8346eca8f99a": "성숙기",
}
OUT = "tool/pixellab"


def main():
    os.makedirs(OUT, exist_ok=True)
    # 기존 청룡 소스 정리 (레그리스 버전 제거) — animaition·pixellab 양쪽
    for d in ("tool/animaition", "tool/pixellab"):
        for f in os.listdir(d):
            if f.startswith("청룡_"):
                os.remove(os.path.join(d, f))
    total = 0
    for cid, stage in CHARS.items():
        url = f"https://api.pixellab.ai/mcp/characters/{cid}/spritesheet"
        data = urllib.request.urlopen(url).read()
        z = zipfile.ZipFile(io.BytesIO(data))
        jname = [n for n in z.namelist() if n.endswith(".json")][0]
        pname = [n for n in z.namelist() if n.endswith(".png")][0]
        meta = json.loads(z.read(jname))
        ss = meta["spritesheet"]
        cw = ss["cell_size"]["width"]
        ch = ss["cell_size"]["height"]
        sheet = Image.open(io.BytesIO(z.read(pname))).convert("RGBA")
        for r in ss["rows"]:
            if r.get("type") != "animation":
                continue
            motion = r["animation"]
            fc = r["frame_count"]
            row = r["row"]
            for i in range(fc):
                box = (i * cw, row * ch, (i + 1) * cw, (row + 1) * ch)
                cell = sheet.crop(box)
                cell.save(os.path.join(OUT, f"청룡_{stage}_{motion}_{i:05d}.png"))
            total += 1
            print(f"  청룡_{stage}_{motion}: {fc}프레임")
    print(f"완료: {total}개 애니 저장")


if __name__ == "__main__":
    main()
