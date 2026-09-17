# -*- coding: utf-8 -*-
"""assets/anim 프레임 애니메이션 + 포즈시트 + 투사체 이미지를 브라우저에서
미리보는 자립형 HTML을 생성한다. (도트가 아닌 실제 이미지 에셋 뷰어)

매니페스트(lib/core/anim/anim_manifest.dart)에서 키·프레임수를 읽어
web_preview/characters.html 을 만든다. 에셋은 상대경로(../assets/...)로
참조하므로 file://로 바로 열 수 있다(<img> src는 CORS 무관).

사용: python tool/generate_asset_preview.py  → web_preview/characters.html
"""
import os
import re
import glob

MANIFEST = os.path.join("lib", "core", "anim", "anim_manifest.dart")
OUT = os.path.join("web_preview", "characters.html")

SPECIES_KR = {
    "tiger": "백호", "bird": "주작", "snake": "청룡", "turtle": "현무",
    "samjoko": "삼족오", "gumiho": "구미호", "moonrabbit": "달토끼",
    "haetae": "해태", "bear": "지리산곰", "toad": "두꺼비", "fluff": "털뭉치",
}
STAGE_KR = {"1": "털뭉치", "2": "유아기", "3": "성장기", "4": "성숙기"}


def parse_manifest():
    txt = open(MANIFEST, encoding="utf-8").read()
    # 첫 맵(animFrameCounts)만 파싱
    body = txt.split("animFrameCounts = {", 1)[1].split("};", 1)[0]
    out = {}
    for m in re.finditer(r"'([a-z]+)_(\d)_([a-z]+)':\s*(\d+)", body):
        sp, st, mo, n = m.group(1), m.group(2), m.group(3), int(m.group(4))
        out.setdefault((sp, st), {})[mo] = n
    return out


def card(key, count):
    frames = ",".join(f'"../assets/anim/{key}_{i}.png"' for i in range(count))
    mo = key.split("_")[-1]
    return f'''<div class="card"><div class="anim" data-frames='[{frames}]'></div>
      <div class="lbl">{mo} ({count})</div></div>'''


def img_card(path, label):
    return f'<div class="card"><img src="{path}"><div class="lbl">{label}</div></div>'


def main():
    data = parse_manifest()
    sections = []
    for (sp, st) in sorted(data.keys()):
        title = f"{SPECIES_KR.get(sp, sp)} {STAGE_KR.get(st, st)}  ·  {sp}_{st}"
        cards = "".join(card(f"{sp}_{st}_{mo}", n)
                        for mo, n in sorted(data[(sp, st)].items()))
        sections.append(f'<h2>{title}</h2><div class="grid">{cards}</div>')

    # 포즈시트
    poses = "".join(img_card(f"../assets/pets/{os.path.basename(p)}",
                             os.path.basename(p)[:-4])
                    for p in sorted(glob.glob("assets/pets/*.png")))
    if poses:
        sections.append(f'<h2>포즈시트 (정적)</h2><div class="grid">{poses}</div>')
    # 투사체
    fx = "".join(img_card(f"../assets/effects/{os.path.basename(p)}",
                         os.path.basename(p)[:-4])
                 for p in sorted(glob.glob("assets/effects/*.png")))
    if fx:
        sections.append(f'<h2>투사체 이미지</h2><div class="grid">{fx}</div>')
    # 배경
    bg = "".join(img_card(f"../assets/backgrounds/{os.path.basename(p)}",
                         os.path.basename(p)[:-4])
                 for p in sorted(glob.glob("assets/backgrounds/*.png")))
    if bg:
        sections.append(f'<h2>홈 배경</h2><div class="grid bg">{bg}</div>')

    html = f'''<!doctype html><html lang="ko"><head><meta charset="utf-8">
<title>갓생몬 캐릭터 미리보기</title><style>
  body{{margin:0;background:#eaf8ff;font-family:-apple-system,'Apple SD Gothic Neo',sans-serif;color:#26324a;padding:20px}}
  h1{{font-size:20px}} h2{{font-size:15px;margin:26px 0 10px;border-bottom:2px solid #ffd59a;padding-bottom:6px}}
  .grid{{display:flex;flex-wrap:wrap;gap:12px}}
  .card{{background:#fffef8;border:1px solid #ffd59a;border-radius:10px;padding:8px;text-align:center;width:120px}}
  .anim,.card img{{width:104px;height:104px;object-fit:contain;image-rendering:auto;background:
    linear-gradient(45deg,#eee 25%,transparent 25%,transparent 75%,#eee 75%),
    linear-gradient(45deg,#eee 25%,#fff 25%,#fff 75%,#eee 75%);background-size:16px 16px;background-position:0 0,8px 8px}}
  .grid.bg .card{{width:180px}} .grid.bg img{{width:164px;height:200px}}
  .lbl{{font-size:11px;font-weight:700;margin-top:5px;color:#536076}}
</style></head><body>
<h1>🐣 갓생몬 캐릭터·에셋 미리보기</h1>
<p style="font-size:12px;color:#7b8598">assets/anim 프레임 애니메이션(자동 재생) · 포즈시트 · 투사체 · 배경. 매니페스트에서 자동 생성됨.</p>
{''.join(sections)}
<script>
  document.querySelectorAll('.anim').forEach(el=>{{
    const frames=JSON.parse(el.dataset.frames); let i=0;
    const img=new Image(); img.style.width='100%'; img.style.height='100%';
    img.style.objectFit='contain'; el.appendChild(img);
    img.src=frames[0];
    setInterval(()=>{{ i=(i+1)%frames.length; img.src=frames[i]; }}, 90);
  }});
</script></body></html>'''
    os.makedirs("web_preview", exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(html)
    total = sum(len(v) for v in data.values())
    print(f"생성: {OUT}  (애니 {total}개, {len(data)} 종·단계)")


if __name__ == "__main__":
    main()
