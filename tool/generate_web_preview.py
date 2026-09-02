# -*- coding: utf-8 -*-
"""도트 모션 데이터를 브라우저에서 미리보는 자립형 HTML을 생성한다.

앱은 dart2js에서 64비트 마스크가 32비트로 잘려 웹 렌더가 깨지므로,
프리뷰는 별도 HTML(JS BigInt 비트연산)로 만든다. 데이터를 인라인해
file://로 바로 열 수 있다(fetch/CORS 불필요).

입력:
  - android/app/src/main/assets/pet_motion_data.json  (스프라이트 도트)
  - lib/core/pixel/hidden_palette.dart                 (영물 5색 팔레트)
출력:
  - web_preview/index.html
사용: python tool/generate_web_preview.py
"""

import json
import os
import re

JSON_PATH = os.path.join("android", "app", "src", "main", "assets",
                         "pet_motion_data.json")
PALETTE_PATH = os.path.join("lib", "core", "pixel", "hidden_palette.dart")
OUT_DIR = "web_preview"
OUT_PATH = os.path.join(OUT_DIR, "index.html")

# 사신수/털뭉치 색 (SpeciesTheme와 동기 — [dark, body, accent]; a2·a3는 accent로 폴백)
DARK = "#14161A"
SACRED = {
    "fluff": ["#14161A", "#F4E9CE", "#F2A0AE"],
    "bird": [DARK, "#DC4828", "#FFC94D"],
    "dragon": [DARK, "#2B7AD6", "#F2E3C2"],   # snake(청룡) 에셋 키
    "tiger": [DARK, "#4A5A78", "#F0F3F8"],
    "turtle": [DARK, "#9CCC65", "#9C7A4C"],
}

# 미리보기에서 앞에 노출할 신규 동물 영물
NEW_SPECIES = ["bear", "otter", "owl", "crane"]

# 한국어 라벨
LABELS = {
    "fluff": "털뭉치", "bird": "주작", "dragon": "청룡", "tiger": "백호",
    "turtle": "현무", "samjoko": "삼족오", "gumiho": "구미호",
    "moonrabbit": "달토끼", "haetae": "해태", "dokkaebi": "도깨비",
    "hwangryong": "황룡", "bear": "곰", "otter": "수달", "owl": "부엉이",
    "crane": "두루미",
}


def species_prefix(key):
    """'bear2' → 'bear', 'dragon1' → 'dragon', 'fluff' → 'fluff'."""
    return re.sub(r"\d+$", "", key)


def parse_hidden_palettes():
    """hidden_palette.dart에서 종별 변이0 5색(#RRGGBB)을 뽑는다."""
    text = open(PALETTE_PATH, encoding="utf-8").read()
    palettes = {}
    # 'species': [ [Color(0xAARRGGBB), ...], ... ]  — 첫 리스트(변이0)만 사용
    for m in re.finditer(r"'(\w+)':\s*\[\s*\[([^\]]+)\]", text):
        species = m.group(1)
        colors = re.findall(r"0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})", m.group(2))
        if len(colors) == 5:
            palettes[species] = ["#" + c for c in colors]
    return palettes


def build_palette_map(sprites, hidden):
    """스프라이트 키 → [dark, body, accent, a2, a3] CSS 색."""
    out = {}
    for key in sprites:
        pre = species_prefix(key)
        if pre in hidden:
            out[key] = hidden[pre]
        else:
            base = SACRED.get(pre, SACRED["tiger"])
            dark, body, accent = base
            out[key] = [dark, body, accent, accent, accent]
    return out


def main():
    data = json.load(open(JSON_PATH, encoding="utf-8"))
    hidden = parse_hidden_palettes()
    palettes = build_palette_map(data, hidden)

    # 종 정렬: 신규 동물 먼저, 그다음 나머지
    prefixes = []
    seen = set()
    for key in data:
        p = species_prefix(key)
        if p not in seen:
            seen.add(p)
            prefixes.append(p)
    order = NEW_SPECIES + [p for p in prefixes if p not in NEW_SPECIES]

    payload = {
        "sprites": data,
        "palettes": palettes,
        "labels": LABELS,
        "order": order,
        "newSpecies": NEW_SPECIES,
    }

    os.makedirs(OUT_DIR, exist_ok=True)
    html = HTML_TEMPLATE.replace("__DATA__", json.dumps(payload, ensure_ascii=False))
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"생성: {OUT_PATH} (스프라이트 {len(data)}개, 종 {len(order)})")


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>갓생몬 도트 프리뷰</title>
<style>
  :root { --bg:#F7F4EE; --card:#fff; --ink:#1A1A1F; --line:#e5e0d6; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:-apple-system,'Apple SD Gothic Neo',sans-serif;
         background:var(--bg); color:var(--ink); padding:20px; }
  h1 { font-size:20px; margin:0 0 4px; }
  .sub { color:#8a8a95; font-size:13px; margin-bottom:16px; }
  .controls { display:flex; gap:8px; flex-wrap:wrap; align-items:center;
              margin-bottom:16px; }
  .controls label { font-size:13px; font-weight:600; }
  select, button { font:inherit; padding:6px 10px; border:1px solid var(--line);
                   border-radius:8px; background:#fff; cursor:pointer; }
  button.active { background:#4A5A78; color:#fff; border-color:#4A5A78; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(180px,1fr));
          gap:14px; }
  .cell { background:var(--card); border:1px solid var(--line); border-radius:14px;
          padding:12px; text-align:center; }
  .cell.new { border-color:#4A5A78; box-shadow:0 0 0 2px rgba(74,90,120,.12); }
  .cell canvas { image-rendering:pixelated; width:150px; height:150px;
                 background:#efeae0; border-radius:10px; }
  .cell .name { font-weight:700; margin-top:8px; font-size:14px; }
  .cell .stage { color:#8a8a95; font-size:12px; }
  .badge { display:inline-block; font-size:10px; font-weight:800; color:#4A5A78;
           background:rgba(74,90,120,.14); border-radius:999px; padding:2px 7px;
           margin-left:6px; }
  .dark-mode { --bg:#16181f; --card:#20232c; --ink:#f0f0f0; --line:#333; }
  .dark-mode .cell canvas { background:#2a2d36; }
</style>
</head>
<body>
<h1>갓생몬 도트 프리뷰 <span class="badge" id="count"></span></h1>
<div class="sub">동물 영물 4종(곰·수달·부엉이·두루미)을 앞에 배치했습니다. 모션·배경을 바꿔 확인하세요.</div>
<div class="controls">
  <label>모션</label>
  <select id="motion"></select>
  <label>스테이지</label>
  <select id="stage">
    <option value="all">전체</option>
    <option value="1">유아기</option>
    <option value="2">성장기</option>
    <option value="3">성숙기</option>
  </select>
  <button id="onlyNew">신규 4종만</button>
  <button id="darkBtn">🌙 어두운 배경</button>
  <label>속도</label>
  <select id="speed">
    <option value="600">보통</option>
    <option value="350">빠름</option>
    <option value="900">느림</option>
  </select>
</div>
<div class="grid" id="grid"></div>

<script>
const DATA = __DATA__;
const SCALE = 3;               // 캔버스 배율(도트당 px)
let motion = 'walk', frame = 0, onlyNew = false, stageFilter = 'all', speed = 600;

// 스테이지 번호: 키 끝 숫자(1 유아기 / 2 성장기 / 3 성숙기). fluff는 표시용 0.
function stageOf(key){ const m = key.match(/(\d+)$/); return m ? m[1] : '0'; }
function prefixOf(key){ return key.replace(/\d+$/, ''); }

function hexRowToBig(hex){ return BigInt('0x' + hex); }

function drawFrame(canvas, key){
  const sp = DATA.sprites[key];
  const size = sp.size;
  const f = sp[motion].f[frame % sp[motion].f.length];
  const pal = DATA.palettes[key]; // [dark, body, accent, a2, a3]
  canvas.width = size * SCALE; canvas.height = size * SCALE;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0,0,canvas.width,canvas.height);
  const rows = name => {
    const arr = (f[name] || []).map(hexRowToBig);
    while (arr.length < size) arr.push(0n);
    return arr;
  };
  const d = rows('d'), b = rows('b'), a = rows('a'), a2 = rows('a2'), a3 = rows('a3');
  for (let y=0; y<size; y++){
    for (let x=0; x<size; x++){
      const bit = 1n << BigInt(x);
      let c = null;
      if (d[y] & bit) c = pal[0];
      else if (a3[y] & bit) c = pal[4];
      else if (a2[y] & bit) c = pal[3];
      else if (a[y] & bit) c = pal[2];
      else if (b[y] & bit) c = pal[1];
      if (c){ ctx.fillStyle = c; ctx.fillRect(x*SCALE, y*SCALE, SCALE, SCALE); }
    }
  }
}

function visibleKeys(){
  return DATA.order.flatMap(pre =>
    Object.keys(DATA.sprites)
      .filter(k => prefixOf(k) === pre)
      .sort()
  ).filter(k => {
    if (onlyNew && !DATA.newSpecies.includes(prefixOf(k))) return false;
    if (stageFilter !== 'all' && stageOf(k) !== stageFilter) return false;
    return true;
  });
}

let canvases = [];
function buildGrid(){
  const grid = document.getElementById('grid');
  grid.innerHTML = ''; canvases = [];
  const keys = visibleKeys();
  document.getElementById('count').textContent = keys.length + '개';
  const stageName = {'1':'유아기','2':'성장기','3':'성숙기','0':'털뭉치'};
  for (const key of keys){
    const pre = prefixOf(key);
    const isNew = DATA.newSpecies.includes(pre);
    const cell = document.createElement('div');
    cell.className = 'cell' + (isNew ? ' new' : '');
    const cv = document.createElement('canvas');
    const label = (DATA.labels[pre] || pre);
    cell.innerHTML = `<div class="cvwrap"></div>
      <div class="name">${label}${isNew?'<span class="badge">NEW</span>':''}</div>
      <div class="stage">${stageName[stageOf(key)]||key} · ${key}</div>`;
    cell.querySelector('.cvwrap').appendChild(cv);
    grid.appendChild(cell);
    canvases.push([cv, key]);
  }
  renderAll();
}
function renderAll(){ for (const [cv,key] of canvases) drawFrame(cv, key); }

function initMotions(){
  const sel = document.getElementById('motion');
  const anyKey = Object.keys(DATA.sprites)[0];
  const motions = Object.keys(DATA.sprites[anyKey]).filter(k => k !== 'size' && k !== 'f');
  const nameMap = {walk:'걷기',eat:'밥먹기',sleep:'잠',attack:'공격',dodge:'회피',
                   hurt:'아픔',angry:'화남',joy:'기쁨',hungry:'배고픔'};
  for (const m of motions){
    const o = document.createElement('option');
    o.value = m; o.textContent = nameMap[m] || m; sel.appendChild(o);
  }
  sel.value = 'walk';
  sel.onchange = () => { motion = sel.value; frame = 0; renderAll(); };
}

document.getElementById('stage').onchange = e => { stageFilter = e.target.value; buildGrid(); };
document.getElementById('speed').onchange = e => { speed = +e.target.value; restartLoop(); };
document.getElementById('onlyNew').onclick = e => {
  onlyNew = !onlyNew; e.target.classList.toggle('active', onlyNew); buildGrid();
};
document.getElementById('darkBtn').onclick = e => {
  document.body.classList.toggle('dark-mode');
  e.target.classList.toggle('active');
};

let timer = null;
function restartLoop(){
  if (timer) clearInterval(timer);
  timer = setInterval(() => { frame++; renderAll(); }, speed);
}

initMotions();
buildGrid();
restartLoop();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
