const assert = require('node:assert/strict');
const test = require('node:test');

const {
  buildManifest,
  buildActionFileNames,
  findMissingActionClips,
  generateViewerHtml,
  normalizeAnimationName,
  normalizeCharacterName,
} = require('./asset_preview');

test('normalizes animation filenames into character_stage_action_0000X shape', () => {
  assert.equal(
    normalizeAnimationName('지리산곰_유아기_곧기_0008.png'.normalize('NFD')),
    '지리산곰_유아기_걷기_00008.png'
  );
  assert.equal(
    normalizeAnimationName('삼족오_유아기_걷기png_0001.png'),
    '삼족오_유아기_걷기_00001.png'
  );
  assert.equal(
    normalizeAnimationName('청룡_성장기_걷기_0015.png'),
    '청룡_성장기_걷기_00015.png'
  );
});

test('normalizes original character filenames to NFC character_stage names', () => {
  assert.equal(
    normalizeCharacterName('청룡_성장기.png'.normalize('NFD')),
    '청룡_성장기.png'
  );
});

test('builds a manifest grouped by character, stage, and action', () => {
  const manifest = buildManifest({
    animationFiles: [
      '구미호_유아기_걷기_00002.png',
      '구미호_유아기_걷기_00001.png',
      '구미호_유아기_포효_00001.png',
      '백호_성장기_걷기_00001.png',
    ],
    characterFiles: ['백호_성장기.png', '구미호_유아기.png'],
  });

  assert.deepEqual(
    manifest.characters.map((character) => character.name),
    ['구미호', '백호']
  );

  const gumihoBaby = manifest.characters[0].stages[0];
  assert.equal(gumihoBaby.stage, '유아기');
  assert.equal(gumihoBaby.original.path, '../tool/character/구미호_유아기.png');
  assert.deepEqual(
    gumihoBaby.actions.map((action) => action.action),
    ['걷기', '포효']
  );
  assert.deepEqual(
    gumihoBaby.actions[0].frames.map((frame) => frame.index),
    [1, 2]
  );
  assert.equal(
    gumihoBaby.actions[0].frames[0].path,
    '../tool/animaition/구미호_유아기_걷기_00001.png'
  );
});

test('builds generated action frame names with five-digit frame numbers', () => {
  assert.deepEqual(
    buildActionFileNames({
      character: '청룡',
      stage: '성장기',
      action: '먹기',
      frameCount: 8,
    }),
    [
      '청룡_성장기_먹기_00001.png',
      '청룡_성장기_먹기_00002.png',
      '청룡_성장기_먹기_00003.png',
      '청룡_성장기_먹기_00004.png',
      '청룡_성장기_먹기_00005.png',
      '청룡_성장기_먹기_00006.png',
      '청룡_성장기_먹기_00007.png',
      '청룡_성장기_먹기_00008.png',
    ]
  );
});

test('finds missing generated action clips from original character stages', () => {
  const manifest = buildManifest({
    animationFiles: [
      '구미호_유아기_자기_00001.png',
      '구미호_유아기_자기_00002.png',
      '구미호_유아기_먹기_00001.png',
    ],
    characterFiles: [
      '구미호_유아기.png',
      '구미호_성장기.png',
      '청룡_유아기.png',
    ],
  });

  assert.deepEqual(findMissingActionClips(manifest, ['자기', '먹기'], 8), [
    {
      character: '구미호',
      stage: '성장기',
      action: '먹기',
      frameCount: 8,
      sourceFileName: '구미호_성장기.png',
      fileNames: buildActionFileNames({
        character: '구미호',
        stage: '성장기',
        action: '먹기',
        frameCount: 8,
      }),
    },
    {
      character: '구미호',
      stage: '성장기',
      action: '자기',
      frameCount: 8,
      sourceFileName: '구미호_성장기.png',
      fileNames: buildActionFileNames({
        character: '구미호',
        stage: '성장기',
        action: '자기',
        frameCount: 8,
      }),
    },
    {
      character: '청룡',
      stage: '유아기',
      action: '먹기',
      frameCount: 8,
      sourceFileName: '청룡_유아기.png',
      fileNames: buildActionFileNames({
        character: '청룡',
        stage: '유아기',
        action: '먹기',
        frameCount: 8,
      }),
    },
    {
      character: '청룡',
      stage: '유아기',
      action: '자기',
      frameCount: 8,
      sourceFileName: '청룡_유아기.png',
      fileNames: buildActionFileNames({
        character: '청룡',
        stage: '유아기',
        action: '자기',
        frameCount: 8,
      }),
    },
  ]);
});

test('generates a standalone HTML viewer with inlined manifest data', () => {
  const manifest = buildManifest({
    animationFiles: ['구미호_유아기_걷기_00001.png'],
    characterFiles: ['구미호_유아기.png'],
  });

  const html = generateViewerHtml(manifest);

  assert.match(html, /window\.ASSET_MANIFEST = /);
  assert.match(html, /id="viewer"/);
  assert.match(html, /구미호_유아기_걷기_00001\.png/);
});
