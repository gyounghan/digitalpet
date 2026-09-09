const assert = require('node:assert/strict');

const {
  MOTIONS,
  frameRect,
  frameSegment,
  nextFrame,
} = require('./motion-player.js');

assert.deepEqual(
  Object.keys(MOTIONS),
  ['walk', 'eat', 'sleep', 'happy'],
  '네 가지 거북이 모션을 모두 제공해야 한다.',
);

assert.deepEqual(
  [
    MOTIONS.walk.row,
    MOTIONS.eat.row,
    MOTIONS.sleep.row,
    MOTIONS.happy.row,
  ],
  [0, 1, 2, 3],
  '모션은 스프라이트 시트의 행 순서를 따라야 한다.',
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
