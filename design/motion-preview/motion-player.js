(function attachMotionPlayer(root, factory) {
  const api = factory();

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.TurtleMotion = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function createMotionPlayer() {
  const MOTIONS = Object.freeze({
    walk: Object.freeze({
      label: '걷기', row: 0, cycleMs: 880, cropY: 105, cropHeight: 165,
    }),
    eat: Object.freeze({
      label: '먹기', row: 1, cycleMs: 1280, cropY: 330, cropHeight: 180,
    }),
    sleep: Object.freeze({
      label: '자기', row: 2, cycleMs: 1680, cropY: 550, cropHeight: 190,
    }),
    happy: Object.freeze({
      label: '기쁨', row: 3, cycleMs: 1120, cropY: 760, cropHeight: 250,
    }),
  });

  const FRAME_BOUNDARIES = Object.freeze([
    0, 188, 369, 542, 721, 901, 1074, 1253, 1448,
  ]);

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

  function frameSegment(frame) {
    const x = FRAME_BOUNDARIES[frame];
    return { x, width: FRAME_BOUNDARIES[frame + 1] - x };
  }

  return Object.freeze({ MOTIONS, frameRect, frameSegment, nextFrame });
});
