import crypto from 'node:crypto';
import { simulateBattle } from './battle_sim.js';
import { applyBattleResult, updateRankingProfile } from './ranking.js';

/// Socket.IO /battle 네임스페이스 — 랜덤 매칭 + 친구 대전(초대 코드)
///
/// 프로토콜: docs/battle_server_protocol.md (클라이언트 계약의 단일 소스)
/// 배틀은 매칭 즉시 서버가 전체 시뮬레이션 후, 클라이언트 연출 속도에 맞춰
/// 턴을 순차 push한다 (턴당 2박자 × 900ms = 1800ms).

const TURN_INTERVAL_MS = 1800;
const RESULT_DELAY_MS = 1500;
const QUEUE_TIMEOUT_MS = 60 * 1000;

export function registerBattleGateway(io, store) {
  const nsp = io.of('/battle');

  /// 매칭 대기열: [{ socket, payload, timer }]
  const queue = [];
  /// 친구 대전 대기 방: roomCode → { socket, payload }
  const rooms = new Map();
  /// 진행 중 배틀: socket.id → { opponentSocket, timers, deviceId, finished }
  const active = new Map();

  function removeFromQueue(socket) {
    const idx = queue.findIndex((e) => e.socket === socket);
    if (idx >= 0) {
      clearTimeout(queue[idx].timer);
      queue.splice(idx, 1);
    }
  }

  function removeRoomBy(socket) {
    for (const [code, room] of rooms) {
      if (room.socket === socket) rooms.delete(code);
    }
  }

  function matchedPayload(roomId, opponentPayload) {
    return {
      roomId,
      opponent: {
        petName: opponentPayload.petName ?? '???',
        level: opponentPayload.level ?? 1,
        evolutionType: opponentPayload.evolutionType ?? null,
        // 상대 화면이 실제 외형(단계·등급·색 변이)을 재현할 수 있게 그대로 전달
        // (누락 시 클라이언트가 종만 보고 유아기로 추정해 잘못 그려진다)
        evolutionStage: opponentPayload.evolutionStage ?? 1,
        evolutionGrade: opponentPayload.evolutionGrade ?? '',
        colorVariant: opponentPayload.colorVariant ?? 0,
        maxHp: opponentPayload.hp ?? 100,
      },
    };
  }

  /// A/B 절대 관점 턴 → 수신자 관점 페이로드
  function turnFor(turn, isA) {
    return {
      turnNumber: turn.turnNumber,
      playerSkillName: isA ? turn.aSkillName : turn.bSkillName,
      playerDamage: isA ? turn.aDamage : turn.bDamage,
      opponentSkillName: isA ? turn.bSkillName : turn.aSkillName,
      opponentDamage: isA ? turn.bDamage : turn.aDamage,
      playerHpRemaining: isA ? turn.aHp : turn.bHp,
      opponentHpRemaining: isA ? turn.bHp : turn.aHp,
    };
  }

  function startBattle(entryA, entryB) {
    const roomId = crypto.randomUUID();
    const { socket: sockA, payload: payA } = entryA;
    const { socket: sockB, payload: payB } = entryB;

    sockA.emit('battle:matched', matchedPayload(roomId, payB));
    sockB.emit('battle:matched', matchedPayload(roomId, payA));

    const sim = simulateBattle(payA, payB);
    const timers = [];
    const session = {
      timers,
      finished: false,
    };
    const sessA = { ...session, opponentSocket: sockB, deviceId: payA.deviceId };
    const sessB = { ...session, opponentSocket: sockA, deviceId: payB.deviceId };
    // timers 배열은 공유 — 어느 쪽이 끊겨도 한 번에 정리
    active.set(sockA.id, sessA);
    active.set(sockB.id, sessB);

    // 랭킹 프로필 최신화 (deviceId 있는 쪽만)
    if (payA.deviceId) {
      updateRankingProfile(store, store.ownerKeyForDevice(payA.deviceId), payA.deviceId, payA);
    }
    if (payB.deviceId) {
      updateRankingProfile(store, store.ownerKeyForDevice(payB.deviceId), payB.deviceId, payB);
    }

    sim.turns.forEach((turn, i) => {
      timers.push(setTimeout(() => {
        sockA.emit('battle:turn', turnFor(turn, true));
        sockB.emit('battle:turn', turnFor(turn, false));
      }, TURN_INTERVAL_MS * (i + 1)));
    });

    timers.push(setTimeout(() => {
      sessA.finished = true;
      sessB.finished = true;
      sockA.emit('battle:result', {
        isVictory: sim.aWins,
        isDominantVictory: sim.aWins && sim.isDominant,
        expGained: sim.aExp,
      });
      sockB.emit('battle:result', {
        isVictory: !sim.aWins,
        isDominantVictory: !sim.aWins && sim.isDominant,
        expGained: sim.bExp,
      });

      // 랭킹 RP 반영 (deviceId 없는 참가자는 생략 — 프로토콜 명세)
      if (payA.deviceId) {
        applyBattleResult(store, store.ownerKeyForDevice(payA.deviceId), {
          isVictory: sim.aWins,
          isDominantVictory: sim.aWins && sim.isDominant,
        });
      }
      if (payB.deviceId) {
        applyBattleResult(store, store.ownerKeyForDevice(payB.deviceId), {
          isVictory: !sim.aWins,
          isDominantVictory: !sim.aWins && sim.isDominant,
        });
      }
      active.delete(sockA.id);
      active.delete(sockB.id);
    }, TURN_INTERVAL_MS * sim.turns.length + RESULT_DELAY_MS));
  }

  nsp.on('connection', (socket) => {
    socket.on('battle:join', (payload) => {
      removeFromQueue(socket);
      const entry = { socket, payload: payload ?? {} };
      entry.timer = setTimeout(() => {
        removeFromQueue(socket);
        socket.emit('battle:timeout');
      }, QUEUE_TIMEOUT_MS);

      const opponent = queue.shift();
      if (opponent) {
        clearTimeout(opponent.timer);
        clearTimeout(entry.timer);
        startBattle(opponent, entry);
      } else {
        queue.push(entry);
        socket.emit('battle:queued');
      }
    });

    socket.on('battle:cancel', () => removeFromQueue(socket));

    socket.on('battle:create_room', (payload) => {
      removeRoomBy(socket);
      let roomCode;
      do {
        roomCode = crypto.randomInt(0, 36 ** 6)
          .toString(36).toUpperCase().padStart(6, '0');
      } while (rooms.has(roomCode));
      rooms.set(roomCode, { socket, payload: payload ?? {} });
      socket.emit('battle:room_created', { roomCode });
    });

    socket.on('battle:join_room', (data) => {
      const { roomCode, ...payload } = data ?? {};
      const room = rooms.get((roomCode ?? '').toUpperCase());
      if (!room) {
        return socket.emit('battle:room_error',
          { message: '존재하지 않는 코드예요. 다시 확인해주세요.' });
      }
      if (room.socket === socket) {
        return socket.emit('battle:room_error',
          { message: '자신이 만든 방에는 참가할 수 없어요.' });
      }
      rooms.delete(roomCode.toUpperCase());
      startBattle(room, { socket, payload });
    });

    socket.on('battle:leave_room', () => removeRoomBy(socket));

    socket.on('disconnect', () => {
      removeFromQueue(socket);
      removeRoomBy(socket);

      const session = active.get(socket.id);
      if (session && !session.finished) {
        // 진행 중 이탈 — 예약된 턴/결과 전송 중단, 상대에게 몰수승 통지
        for (const t of session.timers) clearTimeout(t);
        const opponentSession = active.get(session.opponentSocket.id);
        session.opponentSocket.emit('battle:opponent_disconnected');

        // RP: 남은 쪽 승리, 이탈한 쪽 패배 (deviceId 있는 쪽만)
        if (opponentSession?.deviceId) {
          applyBattleResult(store,
            store.ownerKeyForDevice(opponentSession.deviceId),
            { isVictory: true, isDominantVictory: false });
        }
        if (session.deviceId) {
          applyBattleResult(store, store.ownerKeyForDevice(session.deviceId),
            { isVictory: false, isDominantVictory: false });
        }
        active.delete(session.opponentSocket.id);
      }
      active.delete(socket.id);
    });
  });
}
