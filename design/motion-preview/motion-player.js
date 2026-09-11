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
  const SIX_FRAMES = Object.freeze([0, 1, 2, 3, 4, 5, 6]);
  const SEVEN_FRAMES = Object.freeze([0, 1, 2, 3, 4, 5, 6, 7]);
  const EIGHT_FRAMES = Object.freeze([0, 1, 2, 3, 4, 5, 6, 7, 8]);

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
      label: '현무 유아기',
      subtitle: '한 개의 생명이 깨어나는 첫 단계',
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
    hyunmooGrowth: Object.freeze({
      label: '현무 성장기',
      subtitle: '두 개의 머리가 지키는, 평온한 힘',
      sheet: 'hyunmoo-growth-motion-sheet.png',
      theme: 'light',
      canvasColor: '#ffffff',
      motions: Object.freeze({
        walk: motion('걷기', 980, 0, 1, SEVEN_FRAMES, '성장한 다리와 등 위 뱀 머리가 함께 흔들리는 일곱 프레임 동작입니다.', 'frames/hyunmoo-growth/walk'),
        eat: motion('먹기', 1320, 0, 1, SIX_FRAMES, '채소를 발견하고 고개를 숙여 먹는 여섯 프레임 동작입니다.', 'frames/hyunmoo-growth/eat'),
        sleep: motion('자기', 1680, 0, 1, SIX_FRAMES, '두 머리가 편안히 엎드려 잠드는 동작입니다.', 'frames/hyunmoo-growth/sleep'),
        happy: motion('기쁨', 1120, 0, 1, SIX_FRAMES, '활짝 웃고 가볍게 뛰어오르는 기쁨 표현입니다.', 'frames/hyunmoo-growth/happy'),
      }),
    }),
    hyunmooMature: Object.freeze({
      label: '현무 성숙기',
      subtitle: '흔들리지 않는 완성된 수호자',
      sheet: 'hyunmoo-mature-motion-sheet.png',
      theme: 'light',
      canvasColor: '#ffffff',
      motions: Object.freeze({
        walk: motion('걷기', 1040, 0, 1, EIGHT_FRAMES, '완성된 세 머리의 균형을 유지하며 걷는 여덟 프레임 동작입니다.', 'frames/hyunmoo-mature/walk'),
        eat: motion('먹기', 1320, 0, 1, SIX_FRAMES, '세 머리가 주변을 살피며 먹이를 먹는 동작입니다.', 'frames/hyunmoo-mature/eat'),
        sleep: motion('자기', 1680, 0, 1, SIX_FRAMES, '세 머리가 차례로 긴장을 풀고 잠드는 동작입니다.', 'frames/hyunmoo-mature/sleep'),
        happy: motion('기쁨', 1160, 0, 1, SIX_FRAMES, '큰 몸으로 힘차게 뛰어오르는 기쁨 표현입니다.', 'frames/hyunmoo-mature/happy'),
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
