const fs = require('node:fs');
const path = require('node:path');

const ROOT_DIR = path.resolve(__dirname, '..');
const ANIMATION_DIR = path.join(ROOT_DIR, 'tool', 'animaition');
const CHARACTER_DIR = path.join(ROOT_DIR, 'tool', 'character');
const OUT_DIR = path.join(ROOT_DIR, 'web_preview');
const OUT_PATH = path.join(OUT_DIR, 'asset-animation-viewer.html');

const STAGE_ORDER = ['유아기', '성장기', '성숙기'];
const ACTION_ORDER = ['걷기', '먹기', '자기', '기쁨', '화남', '포효'];

function compareKorean(a, b) {
  return a.localeCompare(b, 'ko-KR');
}

function byKnownOrder(order, value) {
  const index = order.indexOf(value);
  return index === -1 ? Number.MAX_SAFE_INTEGER : index;
}

function compareStage(a, b) {
  const rank = byKnownOrder(STAGE_ORDER, a) - byKnownOrder(STAGE_ORDER, b);
  return rank || compareKorean(a, b);
}

function compareAction(a, b) {
  const rank = byKnownOrder(ACTION_ORDER, a) - byKnownOrder(ACTION_ORDER, b);
  return rank || compareKorean(a, b);
}

function normalizeAction(action) {
  const normalized = action.normalize('NFC').replace(/png$/iu, '');
  if (normalized === '곧기') return '걷기';
  return normalized;
}

function normalizeAnimationName(fileName) {
  const baseName = path.basename(fileName).normalize('NFC');
  const match = baseName.match(/^(.+?)_(유아기|성장기|성숙기)_(.+?)_(\d+)\.png$/u);

  if (!match) {
    throw new Error(`Invalid animation filename: ${fileName}`);
  }

  const [, character, stage, action, frame] = match;
  const frameNumber = Number.parseInt(frame, 10);
  if (!Number.isFinite(frameNumber) || frameNumber < 1) {
    throw new Error(`Invalid animation frame number: ${fileName}`);
  }

  return [
    character.normalize('NFC'),
    stage.normalize('NFC'),
    normalizeAction(action),
    String(frameNumber).padStart(5, '0'),
  ].join('_') + '.png';
}

function normalizeCharacterName(fileName) {
  const baseName = path.basename(fileName).normalize('NFC');
  const match = baseName.match(/^(.+?)_(유아기|성장기|성숙기)\.png$/u);

  if (!match) {
    throw new Error(`Invalid original character filename: ${fileName}`);
  }

  const [, character, stage] = match;
  return `${character.normalize('NFC')}_${stage.normalize('NFC')}.png`;
}

function parseAnimationFile(fileName) {
  const normalized = normalizeAnimationName(fileName);
  const match = normalized.match(/^(.+?)_(.+?)_(.+?)_(\d+)\.png$/u);
  const [, character, stage, action, frame] = match;

  return {
    character,
    stage,
    action,
    index: Number.parseInt(frame, 10),
    fileName: normalized,
    path: `../tool/animaition/${normalized}`,
  };
}

function parseCharacterFile(fileName) {
  const normalized = normalizeCharacterName(fileName);
  const match = normalized.match(/^(.+?)_(.+?)\.png$/u);
  const [, character, stage] = match;

  return {
    character,
    stage,
    fileName: normalized,
    path: `../tool/character/${normalized}`,
  };
}

function ensureCharacter(manifestMap, name) {
  if (!manifestMap.has(name)) {
    manifestMap.set(name, {
      name,
      stages: new Map(),
    });
  }
  return manifestMap.get(name);
}

function ensureStage(character, stage) {
  if (!character.stages.has(stage)) {
    character.stages.set(stage, {
      stage,
      original: null,
      actions: new Map(),
    });
  }
  return character.stages.get(stage);
}

function buildManifest({ animationFiles, characterFiles }) {
  const manifestMap = new Map();
  const issues = {
    missingOriginals: [],
    originalsWithoutAnimations: [],
  };

  for (const fileName of characterFiles.map(normalizeCharacterName).sort(compareKorean)) {
    const original = parseCharacterFile(fileName);
    const character = ensureCharacter(manifestMap, original.character);
    const stage = ensureStage(character, original.stage);
    stage.original = {
      fileName: original.fileName,
      path: original.path,
    };
  }

  for (const fileName of animationFiles.map(normalizeAnimationName).sort(compareKorean)) {
    const frame = parseAnimationFile(fileName);
    const character = ensureCharacter(manifestMap, frame.character);
    const stage = ensureStage(character, frame.stage);
    if (!stage.actions.has(frame.action)) {
      stage.actions.set(frame.action, {
        action: frame.action,
        frames: [],
      });
    }
    stage.actions.get(frame.action).frames.push({
      index: frame.index,
      fileName: frame.fileName,
      path: frame.path,
    });
  }

  const characters = [...manifestMap.values()]
    .sort((a, b) => compareKorean(a.name, b.name))
    .map((character) => ({
      name: character.name,
      stages: [...character.stages.values()]
        .sort((a, b) => compareStage(a.stage, b.stage))
        .map((stage) => {
          const actions = [...stage.actions.values()]
            .sort((a, b) => compareAction(a.action, b.action))
            .map((action) => ({
              action: action.action,
              frames: action.frames.sort((a, b) => a.index - b.index),
            }));

          if (!stage.original && actions.length > 0) {
            issues.missingOriginals.push(`${character.name}_${stage.stage}`);
          }

          if (stage.original && actions.length === 0) {
            issues.originalsWithoutAnimations.push(`${character.name}_${stage.stage}`);
          }

          return {
            stage: stage.stage,
            original: stage.original,
            actions,
          };
        }),
    }));

  const stageCount = characters.reduce((sum, character) => sum + character.stages.length, 0);
  const actionCount = characters.reduce(
    (sum, character) =>
      sum + character.stages.reduce((stageSum, stage) => stageSum + stage.actions.length, 0),
    0
  );

  return {
    generatedAt: new Date().toISOString(),
    summary: {
      animationCount: animationFiles.length,
      originalCount: characterFiles.length,
      characterCount: characters.length,
      stageCount,
      actionCount,
    },
    issues,
    characters,
  };
}

function escapeScriptData(value) {
  return JSON.stringify(value, null, 2)
    .replace(/</g, '\\u003c')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function generateViewerHtml(manifest) {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>갓생몬 애니메이션 자산 뷰어</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f7f2;
      --surface: #ffffff;
      --surface-2: #eef4ee;
      --ink: #1b221f;
      --muted: #65746d;
      --line: #d7e0da;
      --primary: #236a62;
      --primary-ink: #ffffff;
      --accent: #d84f3f;
      --gold: #d99b26;
      --shadow: rgba(20, 31, 27, 0.12);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo",
        "Noto Sans KR", "Segoe UI", sans-serif;
      letter-spacing: 0;
    }

    button,
    input,
    select {
      font: inherit;
    }

    button,
    select,
    input[type="range"] {
      cursor: pointer;
    }

    .shell {
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      min-height: 100vh;
    }

    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 16px 20px;
      border-bottom: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.9);
      backdrop-filter: blur(10px);
    }

    h1,
    h2,
    p {
      margin: 0;
    }

    h1 {
      font-size: 20px;
      line-height: 1.2;
      font-weight: 900;
    }

    .stats {
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
      justify-content: flex-end;
    }

    .stat {
      min-height: 30px;
      padding: 6px 10px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface-2);
      color: var(--muted);
      font-size: 12px;
      font-weight: 800;
      white-space: nowrap;
    }

    .content {
      display: grid;
      grid-template-columns: 300px minmax(0, 1fr);
      min-height: 0;
    }

    .sidebar {
      min-height: 0;
      padding: 14px;
      border-right: 1px solid var(--line);
      background: #fbfcfa;
      overflow: auto;
    }

    .filters {
      display: grid;
      gap: 9px;
      margin-bottom: 12px;
    }

    .field {
      display: grid;
      gap: 5px;
    }

    .field label {
      color: var(--muted);
      font-size: 11px;
      font-weight: 900;
    }

    select,
    input[type="search"],
    input[type="range"] {
      width: 100%;
    }

    select,
    input[type="search"] {
      min-height: 38px;
      padding: 8px 10px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      color: var(--ink);
      outline: none;
    }

    select:focus,
    input[type="search"]:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(35, 106, 98, 0.14);
    }

    .clip-list {
      display: grid;
      gap: 8px;
    }

    .clip-button {
      display: grid;
      grid-template-columns: 56px minmax(0, 1fr);
      gap: 10px;
      align-items: center;
      width: 100%;
      min-height: 72px;
      padding: 8px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      color: var(--ink);
      text-align: left;
      box-shadow: 0 5px 14px rgba(28, 42, 35, 0.06);
    }

    .clip-button[aria-pressed="true"] {
      border-color: var(--primary);
      background: #e4f2ef;
      box-shadow: inset 3px 0 0 var(--primary);
    }

    .thumb {
      width: 56px;
      height: 56px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #f6faf6;
      object-fit: contain;
      image-rendering: pixelated;
    }

    .clip-title,
    .clip-meta {
      display: block;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .clip-title {
      font-size: 13px;
      font-weight: 900;
    }

    .clip-meta {
      margin-top: 3px;
      color: var(--muted);
      font-size: 11px;
      font-weight: 800;
    }

    .main {
      min-width: 0;
      min-height: 0;
      padding: 18px;
      overflow: auto;
    }

    .stage-layout {
      display: grid;
      grid-template-columns: minmax(280px, 0.86fr) minmax(0, 1.14fr);
      gap: 14px;
      align-items: stretch;
    }

    .panel {
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      box-shadow: 0 14px 34px var(--shadow);
      overflow: hidden;
    }

    .panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      min-height: 48px;
      padding: 12px 14px;
      border-bottom: 1px solid var(--line);
      background: #fbfcfa;
    }

    .panel-head h2 {
      min-width: 0;
      overflow-wrap: anywhere;
      font-size: 15px;
      font-weight: 950;
    }

    .badge {
      flex: none;
      padding: 4px 8px;
      border-radius: 8px;
      background: #fff4d7;
      color: #7c5711;
      font-size: 11px;
      font-weight: 900;
    }

    .preview-stage {
      position: relative;
      display: grid;
      place-items: center;
      min-height: 460px;
      padding: 28px;
      background:
        linear-gradient(180deg, #f9fbf7 0%, #f9fbf7 62%, #dfead6 62%, #dfead6 100%);
    }

    .preview-stage.dark {
      background:
        linear-gradient(180deg, #101719 0%, #101719 62%, #172821 62%, #172821 100%);
    }

    .sprite {
      position: relative;
      z-index: 1;
      width: min(78vw, 360px);
      height: min(78vw, 360px);
      max-width: 100%;
      border: 0;
      object-fit: contain;
      image-rendering: pixelated;
      filter: drop-shadow(0 24px 12px rgba(20, 26, 24, 0.16));
    }

    .shadow {
      position: absolute;
      left: 50%;
      bottom: 92px;
      width: min(250px, 56%);
      height: 24px;
      border-radius: 50%;
      background: rgba(34, 46, 37, 0.14);
      transform: translateX(-50%);
      filter: blur(3px);
    }

    .original-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
      gap: 12px;
      padding: 12px;
    }

    .original-tile {
      display: grid;
      gap: 8px;
      align-content: start;
      min-height: 194px;
      padding: 10px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fbfcfa;
    }

    .original-tile img {
      width: 100%;
      aspect-ratio: 1;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #f6faf6;
      object-fit: contain;
      image-rendering: pixelated;
    }

    .original-tile strong,
    .original-tile span {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .original-tile strong {
      font-size: 13px;
      font-weight: 900;
    }

    .original-tile span {
      color: var(--muted);
      font-size: 11px;
      font-weight: 800;
    }

    .controls {
      display: grid;
      grid-template-columns: auto auto minmax(160px, 1fr) auto;
      gap: 9px;
      align-items: center;
      padding: 12px 14px 14px;
      border-top: 1px solid var(--line);
      background: #fbfcfa;
    }

    .action-button {
      min-height: 38px;
      padding: 8px 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      color: var(--ink);
      font-weight: 900;
    }

    .action-button.primary {
      border-color: var(--primary);
      background: var(--primary);
      color: var(--primary-ink);
    }

    .frame-readout {
      justify-self: end;
      color: var(--muted);
      font-size: 12px;
      font-weight: 900;
      white-space: nowrap;
    }

    .empty {
      display: grid;
      place-items: center;
      min-height: 180px;
      padding: 24px;
      color: var(--muted);
      font-size: 13px;
      font-weight: 800;
      text-align: center;
    }

    @media (max-width: 940px) {
      .content,
      .stage-layout {
        grid-template-columns: 1fr;
      }

      .sidebar {
        max-height: 44vh;
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }

      .preview-stage {
        min-height: 360px;
      }
    }

    @media (max-width: 600px) {
      .topbar {
        align-items: flex-start;
        flex-direction: column;
        padding: 14px;
      }

      .stats {
        justify-content: flex-start;
      }

      .main {
        padding: 12px;
      }

      .controls {
        grid-template-columns: 1fr 1fr;
      }

      .controls input[type="range"],
      .frame-readout {
        grid-column: 1 / -1;
      }

      .frame-readout {
        justify-self: start;
      }
    }
  </style>
</head>
<body>
  <div class="shell" id="viewer">
    <header class="topbar">
      <h1>갓생몬 애니메이션 자산 뷰어</h1>
      <div class="stats" id="stats"></div>
    </header>
    <div class="content">
      <aside class="sidebar">
        <div class="filters">
          <div class="field">
            <label for="search">검색</label>
            <input id="search" type="search" autocomplete="off">
          </div>
          <div class="field">
            <label for="characterFilter">캐릭터</label>
            <select id="characterFilter"></select>
          </div>
          <div class="field">
            <label for="stageFilter">성장단계</label>
            <select id="stageFilter"></select>
          </div>
        </div>
        <div class="clip-list" id="clipList"></div>
      </aside>
      <main class="main">
        <section class="stage-layout">
          <div class="panel">
            <div class="panel-head">
              <h2 id="activeTitle"></h2>
              <span class="badge" id="activeBadge"></span>
            </div>
            <div class="preview-stage" id="previewStage">
              <div class="shadow" aria-hidden="true"></div>
              <img class="sprite" id="animationFrame" alt="">
            </div>
            <div class="controls">
              <button class="action-button primary" id="playToggle" type="button">정지</button>
              <button class="action-button" id="themeToggle" type="button">배경</button>
              <input id="frameSlider" type="range" min="0" max="0" value="0">
              <span class="frame-readout" id="frameReadout"></span>
            </div>
          </div>
          <div class="panel">
            <div class="panel-head">
              <h2>원본 캐릭터</h2>
              <span class="badge" id="originalBadge"></span>
            </div>
            <div class="original-grid" id="originalGrid"></div>
          </div>
        </section>
      </main>
    </div>
  </div>
  <script>
    window.ASSET_MANIFEST = ${escapeScriptData(manifest)};

    const manifest = window.ASSET_MANIFEST;
    const clips = manifest.characters.flatMap((character) =>
      character.stages.flatMap((stage) =>
        stage.actions.map((action) => ({
          character: character.name,
          stage: stage.stage,
          original: stage.original,
          action: action.action,
          frames: action.frames,
        }))
      )
    );

    const stageRank = new Map(${JSON.stringify(STAGE_ORDER)}.map((stage, index) => [stage, index]));
    const state = {
      query: '',
      character: 'all',
      stage: 'all',
      clipIndex: 0,
      frame: 0,
      playing: true,
      dark: false,
      lastTick: 0,
      frameMs: 125,
    };

    const el = {
      stats: document.getElementById('stats'),
      search: document.getElementById('search'),
      characterFilter: document.getElementById('characterFilter'),
      stageFilter: document.getElementById('stageFilter'),
      clipList: document.getElementById('clipList'),
      activeTitle: document.getElementById('activeTitle'),
      activeBadge: document.getElementById('activeBadge'),
      previewStage: document.getElementById('previewStage'),
      animationFrame: document.getElementById('animationFrame'),
      playToggle: document.getElementById('playToggle'),
      themeToggle: document.getElementById('themeToggle'),
      frameSlider: document.getElementById('frameSlider'),
      frameReadout: document.getElementById('frameReadout'),
      originalGrid: document.getElementById('originalGrid'),
      originalBadge: document.getElementById('originalBadge'),
    };

    function imagePath(src) {
      return encodeURI(src);
    }

    function currentClip() {
      return clips[state.clipIndex] || null;
    }

    function selectedClips() {
      const query = state.query.trim().toLocaleLowerCase('ko-KR');
      return clips
        .map((clip, index) => ({ clip, index }))
        .filter(({ clip }) => {
          if (state.character !== 'all' && clip.character !== state.character) return false;
          if (state.stage !== 'all' && clip.stage !== state.stage) return false;
          if (!query) return true;
          return [clip.character, clip.stage, clip.action]
            .join(' ')
            .toLocaleLowerCase('ko-KR')
            .includes(query);
        });
    }

    function syncActiveWithFilters() {
      const visible = selectedClips();
      if (!visible.some(({ index }) => index === state.clipIndex)) {
        state.clipIndex = visible[0]?.index ?? 0;
        state.frame = 0;
      }
    }

    function populateStats() {
      const entries = [
        ['캐릭터', manifest.summary.characterCount],
        ['원본', manifest.summary.originalCount],
        ['애니메이션', manifest.summary.actionCount],
        ['프레임', manifest.summary.animationCount],
      ];
      el.stats.innerHTML = entries
        .map(([label, value]) => '<span class="stat">' + label + ' ' + value + '</span>')
        .join('');
    }

    function populateFilters() {
      const characterOptions = ['all', ...manifest.characters.map((character) => character.name)];
      el.characterFilter.innerHTML = characterOptions
        .map((value) => '<option value="' + value + '">' + (value === 'all' ? '전체' : value) + '</option>')
        .join('');

      const stages = [...new Set(clips.map((clip) => clip.stage))]
        .sort((a, b) => (stageRank.get(a) ?? 99) - (stageRank.get(b) ?? 99) || a.localeCompare(b, 'ko-KR'));
      el.stageFilter.innerHTML = ['all', ...stages]
        .map((value) => '<option value="' + value + '">' + (value === 'all' ? '전체' : value) + '</option>')
        .join('');
    }

    function renderClipList() {
      syncActiveWithFilters();
      const visible = selectedClips();
      if (visible.length === 0) {
        el.clipList.innerHTML = '<div class="empty">표시할 애니메이션이 없습니다.</div>';
        return;
      }

      el.clipList.innerHTML = visible.map(({ clip, index }) => {
        const firstFrame = clip.frames[0];
        const selected = index === state.clipIndex ? 'true' : 'false';
        return [
          '<button class="clip-button" type="button" data-index="' + index + '" aria-pressed="' + selected + '">',
          '<img class="thumb" src="' + imagePath(firstFrame.path) + '" alt="">',
          '<span>',
          '<strong class="clip-title">' + clip.character + ' ' + clip.stage + '</strong>',
          '<span class="clip-meta">' + clip.action + ' · ' + clip.frames.length + '프레임</span>',
          '</span>',
          '</button>',
        ].join('');
      }).join('');
    }

    function renderOriginals(clip) {
      const character = manifest.characters.find((item) => item.name === clip.character);
      const originals = character.stages
        .filter((stage) => stage.original)
        .map((stage) => ({ stage: stage.stage, original: stage.original }));

      el.originalBadge.textContent = originals.length + '개';
      el.originalGrid.innerHTML = originals.map(({ stage, original }) => {
        const active = stage === clip.stage ? ' · 선택됨' : '';
        return [
          '<div class="original-tile">',
          '<img src="' + imagePath(original.path) + '" alt="' + clip.character + ' ' + stage + ' 원본">',
          '<strong>' + clip.character + '</strong>',
          '<span>' + stage + active + '</span>',
          '</div>',
        ].join('');
      }).join('');
    }

    function renderActiveClip() {
      const clip = currentClip();
      if (!clip) return;
      const frame = clip.frames[state.frame % clip.frames.length];

      el.activeTitle.textContent = clip.character + ' · ' + clip.stage + ' · ' + clip.action;
      el.activeBadge.textContent = clip.frames.length + '프레임';
      el.animationFrame.src = imagePath(frame.path);
      el.animationFrame.alt = clip.character + ' ' + clip.stage + ' ' + clip.action + ' ' + frame.index;
      el.frameSlider.max = String(Math.max(0, clip.frames.length - 1));
      el.frameSlider.value = String(state.frame % clip.frames.length);
      el.frameReadout.textContent = String(state.frame + 1) + ' / ' + clip.frames.length;
      el.playToggle.textContent = state.playing ? '정지' : '재생';
      el.playToggle.classList.toggle('primary', state.playing);
      el.previewStage.classList.toggle('dark', state.dark);
      renderOriginals(clip);
    }

    function render() {
      renderClipList();
      renderActiveClip();
    }

    function selectClip(index) {
      state.clipIndex = index;
      state.frame = 0;
      render();
    }

    el.search.addEventListener('input', (event) => {
      state.query = event.target.value;
      render();
    });

    el.characterFilter.addEventListener('change', (event) => {
      state.character = event.target.value;
      state.frame = 0;
      render();
    });

    el.stageFilter.addEventListener('change', (event) => {
      state.stage = event.target.value;
      state.frame = 0;
      render();
    });

    el.clipList.addEventListener('click', (event) => {
      const button = event.target.closest('button[data-index]');
      if (!button) return;
      selectClip(Number(button.dataset.index));
    });

    el.playToggle.addEventListener('click', () => {
      state.playing = !state.playing;
      renderActiveClip();
    });

    el.themeToggle.addEventListener('click', () => {
      state.dark = !state.dark;
      renderActiveClip();
    });

    el.frameSlider.addEventListener('input', (event) => {
      state.frame = Number(event.target.value);
      renderActiveClip();
    });

    function tick(now) {
      const clip = currentClip();
      if (clip && state.playing && now - state.lastTick > state.frameMs) {
        state.frame = (state.frame + 1) % clip.frames.length;
        state.lastTick = now;
        renderActiveClip();
      }
      requestAnimationFrame(tick);
    }

    populateStats();
    populateFilters();
    render();
    requestAnimationFrame(tick);
  </script>
</body>
</html>
`;
}

function listPngFiles(directory) {
  return fs.readdirSync(directory).filter((fileName) => fileName.toLowerCase().endsWith('.png'));
}

function buildRenamePlan(directory, type) {
  const normalizer = type === 'animation' ? normalizeAnimationName : normalizeCharacterName;
  const files = listPngFiles(directory);
  const targetToSource = new Map();

  return files.map((fileName) => {
    const target = normalizer(fileName);
    if (targetToSource.has(target) && targetToSource.get(target) !== fileName) {
      throw new Error(`Rename collision: ${targetToSource.get(target)} and ${fileName} -> ${target}`);
    }
    targetToSource.set(target, fileName);

    return {
      directory,
      fromName: fileName,
      toName: target,
      fromPath: path.join(directory, fileName),
      toPath: path.join(directory, target),
    };
  }).filter((plan) => plan.fromName !== plan.toName);
}

function applyRenamePlan(plans) {
  const tempMoves = plans.map((plan, index) => ({
    ...plan,
    tempPath: path.join(plan.directory, `.asset-preview-rename-${process.pid}-${index}.tmp`),
  }));

  for (const move of tempMoves) {
    fs.renameSync(move.fromPath, move.tempPath);
  }

  for (const move of tempMoves) {
    if (fs.existsSync(move.toPath)) {
      throw new Error(`Cannot rename ${move.fromName}: target already exists (${move.toName})`);
    }
    fs.renameSync(move.tempPath, move.toPath);
  }
}

function buildManifestFromDisk() {
  return buildManifest({
    animationFiles: listPngFiles(ANIMATION_DIR),
    characterFiles: listPngFiles(CHARACTER_DIR),
  });
}

function writeViewer() {
  const manifest = buildManifestFromDisk();
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(OUT_PATH, generateViewerHtml(manifest), 'utf8');
  return { manifest, outPath: OUT_PATH };
}

function runCli(argv = process.argv.slice(2)) {
  const args = new Set(argv);
  const fix = args.has('--fix');
  const build = args.has('--build');
  const check = args.has('--check') || (!fix && !build);

  const animationPlan = buildRenamePlan(ANIMATION_DIR, 'animation');
  const characterPlan = buildRenamePlan(CHARACTER_DIR, 'character');
  const plans = [...animationPlan, ...characterPlan];

  if (check) {
    console.log(`animation rename candidates: ${animationPlan.length}`);
    console.log(`character rename candidates: ${characterPlan.length}`);
    for (const plan of plans) {
      console.log(`${path.relative(ROOT_DIR, plan.fromPath)} -> ${path.relative(ROOT_DIR, plan.toPath)}`);
    }
  }

  if (fix && plans.length > 0) {
    applyRenamePlan(plans);
    console.log(`renamed files: ${plans.length}`);
  } else if (fix) {
    console.log('renamed files: 0');
  }

  if (build) {
    const result = writeViewer();
    console.log(`viewer: ${path.relative(ROOT_DIR, result.outPath)}`);
    console.log(`frames: ${result.manifest.summary.animationCount}`);
    console.log(`clips: ${result.manifest.summary.actionCount}`);
  }
}

if (require.main === module) {
  runCli();
}

module.exports = {
  ANIMATION_DIR,
  CHARACTER_DIR,
  OUT_PATH,
  buildManifest,
  buildManifestFromDisk,
  buildRenamePlan,
  generateViewerHtml,
  normalizeAnimationName,
  normalizeCharacterName,
  runCli,
  writeViewer,
};
