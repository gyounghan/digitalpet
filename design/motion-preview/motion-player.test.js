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
  frameAssetFor('hyunmooThree', 'roar', 5),
  'frames/hyunmoo-three/roar-06.png',
  '서로 겹치는 포효 프레임은 개별 추출 이미지를 사용해야 한다.',
);

assert.equal(
  frameAssetFor('hyunmooTwo', 'walk', 0),
  'frames/hyunmoo-two/walk-01.png',
  '현무 일반 동작도 투명한 개별 프레임을 사용해야 한다.',
);

assert.equal(
  frameAssetFor('turtle', 'walk', 0),
  null,
  '기존 거북이는 원본 시트에서 바로 잘라야 한다.',
);

assert.deepEqual(
  Object.keys(CHARACTERS),
  ['turtle', 'hyunmooTwo', 'hyunmooThree'],
  '미리보기에서 세 캐릭터를 선택할 수 있어야 한다.',
);

assert.deepEqual(
  availableMotions('hyunmooTwo'),
  ['idle', 'walk', 'run', 'eat', 'sleep', 'happy', 'angry', 'hurt', 'recover'],
  '현무 2두는 시트에 포함된 아홉 동작을 모두 제공해야 한다.',
);

assert.deepEqual(
  availableMotions('hyunmooThree'),
  ['idle', 'walk', 'run', 'eat', 'sleep', 'happy', 'angry', 'hurt', 'recover', 'roar'],
  '현무 3두는 포효를 포함한 열 동작을 모두 제공해야 한다.',
);

assert.equal(
  frameCountFor('hyunmooTwo', 'walk'),
  8,
  '현무 걷기는 여덟 프레임을 순환해야 한다.',
);

assert.equal(
  frameCountFor('hyunmooThree', 'hurt'),
  4,
  '현무 3두 피격은 네 프레임만 순환해야 한다.',
);

assert.deepEqual(
  sourceRectFor('hyunmooTwo', 'walk', 7),
  { x: 1148, y: 322, width: 148, height: 80 },
  '현무 2두 걷기의 마지막 프레임은 구분선을 제외한 여덟 번째 칸에서 잘라야 한다.',
);

assert.deepEqual(
  sourceRectFor('hyunmooThree', 'roar', 5),
  { x: 1216, y: 1037, width: 76, height: 116 },
  '현무 3두 포효의 마지막 프레임은 전용 여섯 번째 칸에서 잘라야 한다.',
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
