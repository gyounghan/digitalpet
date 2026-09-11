const assert = require('node:assert/strict');

const {
  CHARACTERS,
  availableMotions,
  frameCountFor,
  frameAssetFor,
  frameRect,
  frameSegment,
  sourceRectFor,
  nextFrame,
} = require('./motion-player.js');

assert.equal(
  frameAssetFor('hyunmooGrowth', 'walk', 6),
  'frames/hyunmoo-growth/walk-07.png',
  '현무 성장기 걷기는 새 시트에서 추출한 일곱 번째 프레임을 사용해야 한다.',
);

assert.equal(
  frameAssetFor('hyunmooMature', 'happy', 5),
  'frames/hyunmoo-mature/happy-06.png',
  '현무 성숙기 기쁨은 새 시트에서 추출한 여섯 번째 프레임을 사용해야 한다.',
);

assert.equal(
  frameAssetFor('turtle', 'walk', 0),
  null,
  '기존 거북이는 원본 시트에서 바로 잘라야 한다.',
);

assert.deepEqual(
  Object.keys(CHARACTERS),
  ['turtle', 'hyunmooGrowth', 'hyunmooMature'],
  '미리보기에서 현무의 세 성장 단계를 선택할 수 있어야 한다.',
);

assert.deepEqual(
  availableMotions('hyunmooGrowth'),
  ['walk', 'eat', 'sleep', 'happy'],
  '현무 성장기는 새 시트에 포함된 네 동작만 제공해야 한다.',
);

assert.deepEqual(
  availableMotions('hyunmooMature'),
  ['walk', 'eat', 'sleep', 'happy'],
  '현무 성숙기는 새 시트에 포함된 네 동작만 제공해야 한다.',
);

assert.equal(
  frameCountFor('hyunmooGrowth', 'walk'),
  7,
  '현무 성장기 걷기는 원본에 존재하는 일곱 프레임을 순환해야 한다.',
);

assert.equal(
  frameCountFor('hyunmooMature', 'walk'),
  8,
  '현무 성숙기 걷기는 원본의 여덟 프레임을 순환해야 한다.',
);

assert.deepEqual(
  frameRect(0, 0, 1448, 1086, 8, 4),
  { x: 0, y: 0, width: 181, height: 271.5 },
  '첫 프레임은 시트의 왼쪽 위를 보여줘야 한다.',
);

assert.deepEqual(
  frameRect(7, 3, 1448, 1086, 8, 4),
  { x: 1267, y: 814.5, width: 181, height: 271.5 },
  '마지막 프레임은 시트의 오른쪽 아래를 보여줘야 한다.',
);

assert.deepEqual(
  frameSegment(3),
  { x: 542, width: 179 },
  '네 번째 프레임은 다음 캐릭터 조각이 섞이지 않는 실제 여백 경계를 사용해야 한다.',
);

assert.equal(nextFrame(7, 8), 0, '마지막 다음에는 첫 프레임으로 반복해야 한다.');

console.log('motion-player tests passed');
