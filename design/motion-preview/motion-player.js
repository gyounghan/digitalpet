(function attachMotionPlayer(root, factory) {
  const api = factory();

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.TurtleMotion = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function createMotionPlayer() {
  const TURTLE_BOUNDARIES = Object.freeze([
    0, 188, 369, 542, 721, 901, 1074, 1253, 1448,
  ]);
  const EIGHT_FRAME_BOUNDARIES = Object.freeze([
    112, 260, 408, 556, 704, 852, 1000, 1148, 1296,
  ]);
  const SIX_FRAME_BOUNDARIES = Object.freeze([
    112, 309, 506, 703, 900, 1097, 1294,
  ]);
  const TWO_HURT_BOUNDARIES = Object.freeze([112, 246, 380, 514, 648]);
  const TWO_RECOVER_BOUNDARIES = Object.freeze([760, 894, 1028, 1162, 1296]);
  const THREE_HURT_BOUNDARIES = Object.freeze([96, 174, 252, 330, 408]);
  const THREE_RECOVER_BOUNDARIES = Object.freeze([510, 568, 626, 684, 742]);
  const THREE_ROAR_BOUNDARIES = Object.freeze([
    836, 912, 988, 1064, 1140, 1216, 1292,
  ]);

  function motion(label, cycleMs, cropY, cropHeight, boundaries, note, frameDirectory = null) {
    return Object.freeze({
      label,
      cycleMs,
      cropY,
      cropHeight,
      boundaries,
      note,
      frameDirectory,
    });
  }

  const CHARACTERS = Object.freeze({
    turtle: Object.freeze({
      label: '거북이',
      subtitle: '기본 거북이',
      sheet: 'turtle-motion-sheet.png',
      theme: 'light',
      canvasColor: '#ffffff',
      motions: Object.freeze({
        walk: motion('걷기', 880, 105, 165, TURTLE_BOUNDARIES, '짧은 다리의 교차와 몸통 높낮이를 확인할 수 있습니다.'),
        eat: motion('먹기', 1280, 330, 180, TURTLE_BOUNDARIES, '잎을 발견하고 고개를 숙여 먹은 뒤 다시 일어납니다.'),
        sleep: motion('자기', 1680, 550, 190, TURTLE_BOUNDARIES, '눈을 감고 엎드린 자세에서 숨결과 잠꼬대가 반복됩니다.'),
        happy: motion('기쁨', 1120, 760, 250, TURTLE_BOUNDARIES, '표정이 밝아지고 가볍게 뛰어오르는 기쁨 동작입니다.'),
      }),
    }),
    hyunmooTwo: Object.freeze({
      label: '현무 2두',
      subtitle: '두 개의 머리가 지키는, 평온한 힘',
      sheet: 'hyunmoo-two-motion-sheet.png',
      theme: 'dark',
      canvasColor: '#07110f',
      motions: Object.freeze({
        idle: motion('대기', 1440, 208, 85, EIGHT_FRAME_BOUNDARIES, '두 머리의 작은 시선 변화와 편안한 호흡을 확인합니다.', 'frames/hyunmoo-two/idle'),
        walk: motion('걷기', 960, 322, 80, EIGHT_FRAME_BOUNDARIES, '거북의 발걸음과 등 위 뱀 머리의 흔들림이 함께 이어집니다.', 'frames/hyunmoo-two/walk'),
        run: motion('달리기', 720, 433, 88, EIGHT_FRAME_BOUNDARIES, '몸을 낮추고 빠르게 차고 나가는 여덟 프레임 동작입니다.', 'frames/hyunmoo-two/run'),
        eat: motion('먹기', 1440, 555, 90, SIX_FRAME_BOUNDARIES, '고개를 숙여 먹이를 먹고 다시 자세를 회복합니다.', 'frames/hyunmoo-two/eat'),
        sleep: motion('자기', 1800, 677, 83, SIX_FRAME_BOUNDARIES, '몸을 바닥에 붙이고 잠드는 느린 호흡 동작입니다.', 'frames/hyunmoo-two/sleep'),
        happy: motion('기쁨', 1200, 789, 94, SIX_FRAME_BOUNDARIES, '별과 음표, 하트가 이어지는 기쁨 표현입니다.', 'frames/hyunmoo-two/happy'),
        angry: motion('화남', 1120, 912, 94, SIX_FRAME_BOUNDARIES, '몸을 낮추고 입김을 뿜는 화난 표현입니다.', 'frames/hyunmoo-two/angry'),
        hurt: motion('피격', 800, 1040, 115, TWO_HURT_BOUNDARIES, '충격을 받고 움츠러드는 네 프레임 동작입니다.', 'frames/hyunmoo-two/hurt'),
        recover: motion('회복', 960, 1040, 115, TWO_RECOVER_BOUNDARIES, '기절 상태에서 다시 일어나는 네 프레임 동작입니다.', 'frames/hyunmoo-two/recover'),
      }),
    }),
    hyunmooThree: Object.freeze({
      label: '현무 3두',
      subtitle: '세 개의 생명이 지키는, 변치 않는 힘',
      sheet: 'hyunmoo-three-motion-sheet.png',
      theme: 'dark',
      canvasColor: '#07110f',
      motions: Object.freeze({
        idle: motion('대기', 1440, 208, 92, EIGHT_FRAME_BOUNDARIES, '세 머리가 각자 반응하는 대기 동작입니다.', 'frames/hyunmoo-three/idle'),
        walk: motion('걷기', 960, 322, 94, EIGHT_FRAME_BOUNDARIES, '발걸음에 맞춰 두 뱀 머리가 서로 다른 박자로 움직입니다.', 'frames/hyunmoo-three/walk'),
        run: motion('달리기', 720, 440, 95, EIGHT_FRAME_BOUNDARIES, '몸을 낮춰 달리며 세 머리의 실루엣을 유지합니다.', 'frames/hyunmoo-three/run'),
        eat: motion('먹기', 1440, 559, 92, SIX_FRAME_BOUNDARIES, '앞의 거북 머리가 먹이를 먹는 동안 뱀 머리가 주변을 살핍니다.', 'frames/hyunmoo-three/eat'),
        sleep: motion('자기', 1800, 680, 82, SIX_FRAME_BOUNDARIES, '몸을 길게 낮추고 세 머리가 차례로 잠듭니다.', 'frames/hyunmoo-three/sleep'),
        happy: motion('기쁨', 1200, 783, 98, SIX_FRAME_BOUNDARIES, '별과 음악, 하트로 이어지는 여섯 프레임 표현입니다.', 'frames/hyunmoo-three/happy'),
        angry: motion('화남', 1120, 906, 101, SIX_FRAME_BOUNDARIES, '세 머리가 함께 위협 자세를 취하는 화난 동작입니다.', 'frames/hyunmoo-three/angry'),
        hurt: motion('피격', 800, 1037, 116, THREE_HURT_BOUNDARIES, '충격과 어지러움이 이어지는 네 프레임 동작입니다.', 'frames/hyunmoo-three/hurt'),
        recover: motion('회복', 960, 1037, 116, THREE_RECOVER_BOUNDARIES, '웅크린 자세에서 천천히 다시 일어납니다.', 'frames/hyunmoo-three/recover'),
        roar: motion('포효', 1080, 1037, 116, THREE_ROAR_BOUNDARIES, '세 머리가 순서대로 고개를 들며 힘을 방출합니다.', 'frames/hyunmoo-three/roar'),
      }),
    }),
  });

  const MOTIONS = CHARACTERS.turtle.motions;

  function frameRect(frame, row, sheetWidth, sheetHeight, columns, rows) {
    const width = sheetWidth / columns;
    const height = sheetHeight / rows;

    return {
      x: frame * width,
      y: row * height,
      width,
      height,
    };
  }

  function nextFrame(frame, frameCount) {
    return (frame + 1) % frameCount;
  }

  function frameSegment(frame, boundaries = TURTLE_BOUNDARIES) {
    const x = boundaries[frame];
    return { x, width: boundaries[frame + 1] - x };
  }

  function characterFor(characterKey) {
    const character = CHARACTERS[characterKey];
    if (!character) throw new RangeError(`Unknown character: ${characterKey}`);
    return character;
  }

  function motionFor(characterKey, motionKey) {
    const motionData = characterFor(characterKey).motions[motionKey];
    if (!motionData) throw new RangeError(`Unknown motion: ${motionKey}`);
    return motionData;
  }

  function availableMotions(characterKey) {
    return Object.keys(characterFor(characterKey).motions);
  }

  function frameCountFor(characterKey, motionKey) {
    return motionFor(characterKey, motionKey).boundaries.length - 1;
  }

  function frameAssetFor(characterKey, motionKey, frame) {
    const motionData = motionFor(characterKey, motionKey);
    const count = motionData.boundaries.length - 1;
    if (frame < 0 || frame >= count) throw new RangeError(`Unknown frame: ${frame}`);
    if (!motionData.frameDirectory) return null;
    return `${motionData.frameDirectory}-${String(frame + 1).padStart(2, '0')}.png`;
  }

  function sourceRectFor(characterKey, motionKey, frame) {
    const motionData = motionFor(characterKey, motionKey);
    const count = motionData.boundaries.length - 1;
    if (frame < 0 || frame >= count) throw new RangeError(`Unknown frame: ${frame}`);
    const segment = frameSegment(frame, motionData.boundaries);
    return {
      x: segment.x,
      y: motionData.cropY,
      width: segment.width,
      height: motionData.cropHeight,
    };
  }

  return Object.freeze({
    CHARACTERS,
    MOTIONS,
    availableMotions,
    frameAssetFor,
    frameCountFor,
    frameRect,
    frameSegment,
    motionFor,
    nextFrame,
    sourceRectFor,
  });
});
