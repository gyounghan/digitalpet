/// /battle 게이트웨이 통합 테스트 — 실제 소켓으로 시나리오 검증
///
/// node:test 러너가 이 파일의 소켓 조합에서 테스트 실행을 시작하지 못하는
/// 문제(Node 23 기준)가 있어 독립 스크립트로 실행한다:
///     npm run test:integration
/// 실패 시 exit 1. 배틀 시뮬 자체는 battle_sim.test.js가 담당하고,
/// 여기서는 매칭/방/관점 반전/이탈 처리를 본다.

import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { Server } from 'socket.io';
import { io as clientIo } from 'socket.io-client';
import { Store } from '../src/store.js';
import { registerBattleGateway } from '../src/battle_gateway.js';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-int-'));
const store = new Store(path.join(dir, 'db.json'));
const server = http.createServer();
const io = new Server(server, { transports: ['websocket'] });
registerBattleGateway(io, store);
await new Promise((resolve) => server.listen(0, resolve));
const port = server.address().port;

const pet = (name) => ({
  deviceId: `dev-${name}`,
  petName: name,
  level: 5,
  evolutionStage: 2,
  evolutionType: 'bird',
  atk: 20,
  def: 10,
  hp: 60,
  stamina: 50,
});

const connect = () =>
  clientIo(`http://localhost:${port}/battle`, {
    transports: ['websocket'],
    forceNew: true,
  });

const withTimeout = (promise, label, ms = 5000) =>
  Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`${label} 타임아웃`)), ms)),
  ]);

let passed = 0;
const ok = (label) => {
  passed += 1;
  console.log(`✔ ${label}`);
};

try {
  // ── 1. 친구 대전: 방 생성 → 참가 → 매칭 → 관점 반전 턴 ──
  {
    const host = connect();
    const roomCode = await withTimeout(
      new Promise((resolve) => {
        host.on('battle:room_created', (d) => resolve(d.roomCode));
        host.on('connect', () => host.emit('battle:create_room', pet('방장')));
      }),
      'room_created',
    );
    assert.match(roomCode, /^[A-Z0-9]{6}$/);

    // guest는 roomCode 확보 후 생성 — 연결 완료 전에 핸들러가 걸리도록
    const guest = connect();

    const [hostMatched, guestMatched] = await withTimeout(
      Promise.all([
        new Promise((resolve) => host.on('battle:matched', resolve)),
        new Promise((resolve, reject) => {
          guest.on('battle:matched', resolve);
          guest.on('battle:room_error', (e) => reject(new Error(e.message)));
          guest.on('connect', () =>
            guest.emit('battle:join_room', { roomCode, ...pet('친구') }));
        }),
      ]),
      'matched',
    );
    assert.equal(hostMatched.opponent.petName, '친구');
    assert.equal(guestMatched.opponent.petName, '방장');
    assert.equal(hostMatched.opponent.maxHp, 60);
    // 상대 외형 재현 필드 — 빠지면 상대 화면에 털뭉치/빈 이미지로 그려진다
    assert.equal(hostMatched.opponent.evolutionStage, 2);
    assert.equal(hostMatched.opponent.evolutionGrade, '');
    assert.equal(hostMatched.opponent.colorVariant, 0);

    const [hostTurn, guestTurn] = await withTimeout(
      Promise.all([
        new Promise((resolve) => host.once('battle:turn', resolve)),
        new Promise((resolve) => guest.once('battle:turn', resolve)),
      ]),
      'first turn',
    );
    assert.equal(hostTurn.turnNumber, 1);
    assert.equal(hostTurn.playerDamage, guestTurn.opponentDamage);
    assert.equal(hostTurn.opponentDamage, guestTurn.playerDamage);
    assert.equal(hostTurn.playerHpRemaining, guestTurn.opponentHpRemaining);
    host.disconnect();
    guest.disconnect();
    ok('친구 대전 — 방 생성/참가/매칭/관점 반전 턴');
  }

  // ── 2. 없는 방 코드 → room_error ──
  {
    const socket = connect();
    const error = await withTimeout(
      new Promise((resolve) => {
        socket.on('battle:room_error', resolve);
        socket.on('connect', () =>
          socket.emit('battle:join_room', { roomCode: 'ZZZZZZ', ...pet('X') }));
      }),
      'room_error',
    );
    assert.ok(error.message.includes('존재하지 않는'));
    socket.disconnect();
    ok('없는 방 코드 → room_error');
  }

  // ── 3. 랜덤 매칭 ──
  {
    const a = connect();
    const b = connect();
    const [aMatch, bMatch] = await withTimeout(
      Promise.all([
        new Promise((resolve) => {
          a.on('battle:matched', resolve);
          a.on('connect', () => a.emit('battle:join', pet('A')));
        }),
        new Promise((resolve) => {
          b.on('battle:matched', resolve);
          // A가 먼저 큐에 들어가도록 살짝 늦게 입장
          b.on('connect', () =>
            setTimeout(() => b.emit('battle:join', pet('B')), 150));
        }),
      ]),
      'random match',
    );
    assert.equal(aMatch.opponent.petName, 'B');
    assert.equal(bMatch.opponent.petName, 'A');
    a.disconnect();
    b.disconnect();
    ok('랜덤 매칭 — 두 명 큐 입장 시 매칭');
  }

  // ── 4. 진행 중 이탈 → 몰수승 통지 + RP 반영 ──
  {
    const a = connect();
    const b = connect();
    await withTimeout(
      Promise.all([
        new Promise((resolve) => {
          a.on('battle:matched', resolve);
          a.on('connect', () => a.emit('battle:join', pet('이탈자')));
        }),
        new Promise((resolve) => {
          b.on('battle:matched', resolve);
          b.on('connect', () =>
            setTimeout(() => b.emit('battle:join', pet('생존자')), 150));
        }),
      ]),
      'match before disconnect',
    );

    const notified = withTimeout(
      new Promise((resolve) => b.on('battle:opponent_disconnected', resolve)),
      'opponent_disconnected',
    );
    a.disconnect();
    await notified;

    const survivor = store.data.rankings['dev:dev-생존자'];
    assert.equal(survivor.battleVictoryCount, 1);
    assert.ok(survivor.rp > 0);
    const leaver = store.data.rankings['dev:dev-이탈자'];
    assert.equal(leaver.battleDefeatCount, 1);
    b.disconnect();
    ok('진행 중 이탈 → 몰수승 통지 + RP 반영');
  }

  console.log(`\n통합 테스트 ${passed}/4 통과`);
  io.close();
  process.exit(0);
} catch (e) {
  console.error(`\n✖ 통합 테스트 실패: ${e.message}`);
  io.close();
  process.exit(1);
}
