import crypto from 'node:crypto';
import { optionalAuth } from './auth.js';
import { updateRankingProfile } from './ranking.js';

/// 펫 저장/동기화/기기 이전 라우트
///
/// 클라이언트 계약: lib/data/datasources/pet_remote_datasource.dart
/// - POST /pet/sync           { deviceId, ...petData }  → { pet }
/// - GET  /pet/:deviceId                                 → { pet }
/// - POST /pet/transfer-code  { deviceId }               → { transferCode }
/// - POST /pet/transfer       { newDeviceId, transferCode } → { pet }
/// - POST /pet/battle-record  { deviceId, record }
///
/// 저장 키: 로그인(JWT) 또는 기기-계정 연결이 있으면 계정 키(userId),
/// 없으면 게스트 키('dev:{deviceId}') — 로그인 없이도 모든 기능 동작.

const TRANSFER_CODE_TTL_MS = 24 * 60 * 60 * 1000; // 24시간
const MAX_BATTLE_RECORDS = 50;

function resolveOwnerKey(store, req, deviceId) {
  if (req.userId) {
    // 로그인 상태 — 이 기기를 계정에 연결 (기기 변경 시 자동 이관)
    if (deviceId && store.data.deviceLinks[deviceId] !== req.userId) {
      store.linkDevice(deviceId, req.userId);
    }
    return req.userId;
  }
  return store.ownerKeyForDevice(deviceId);
}

export function registerPetRoutes(app, store) {
  app.post('/pet/sync', optionalAuth, (req, res) => {
    const { deviceId, ...petData } = req.body ?? {};
    if (!deviceId && !req.userId) {
      return res.status(400).json({ error: 'deviceId가 필요해요' });
    }
    const ownerKey = resolveOwnerKey(store, req, deviceId);

    const stored = store.data.pets[ownerKey];
    const incomingUpdated = Number(petData.lastUpdated ?? 0);
    const storedUpdated = Number(stored?.lastUpdated ?? -1);

    // 최신 데이터 선택 — 동률이면 클라이언트(방금 플레이한 쪽) 우선
    const latest = incomingUpdated >= storedUpdated ? petData : stored;
    store.data.pets[ownerKey] = latest;
    updateRankingProfile(store, ownerKey, deviceId, latest);
    store.save();
    res.json({ pet: latest });
  });

  app.get('/pet/:deviceId', optionalAuth, (req, res) => {
    const ownerKey = req.userId ?? store.ownerKeyForDevice(req.params.deviceId);
    const pet = store.data.pets[ownerKey];
    if (!pet) return res.status(404).json({ pet: null });
    res.json({ pet });
  });

  app.post('/pet/transfer-code', optionalAuth, (req, res) => {
    const { deviceId } = req.body ?? {};
    const ownerKey = resolveOwnerKey(store, req, deviceId);
    if (!store.data.pets[ownerKey]) {
      return res.status(404).json({ error: '저장된 펫이 없어요' });
    }

    // 만료 코드 정리 + 6자리 코드 발급
    const now = Date.now();
    for (const [code, t] of Object.entries(store.data.transfers)) {
      if (t.expiresAt < now) delete store.data.transfers[code];
    }
    const transferCode = crypto.randomInt(0, 36 ** 6)
      .toString(36).toUpperCase().padStart(6, '0');
    store.data.transfers[transferCode] = {
      ownerKey,
      expiresAt: now + TRANSFER_CODE_TTL_MS,
    };
    store.save();
    res.json({ transferCode });
  });

  app.post('/pet/transfer', (req, res) => {
    const { newDeviceId, transferCode } = req.body ?? {};
    const entry = store.data.transfers[(transferCode ?? '').toUpperCase()];
    if (!entry || entry.expiresAt < Date.now()) {
      return res.status(404).json({ error: '유효하지 않은 이전 코드예요' });
    }
    const pet = store.data.pets[entry.ownerKey];
    if (!pet) return res.status(404).json({ error: '저장된 펫이 없어요' });

    // 새 기기를 같은 소유 키로 연결 (계정 키면 링크, 게스트 키면 펫 복사)
    if (!entry.ownerKey.startsWith('dev:')) {
      store.linkDevice(newDeviceId, entry.ownerKey);
    } else {
      store.data.pets[`dev:${newDeviceId}`] = pet;
    }
    delete store.data.transfers[transferCode.toUpperCase()];
    store.save();
    res.json({ pet });
  });

  app.post('/pet/battle-record', optionalAuth, (req, res) => {
    const { deviceId, record } = req.body ?? {};
    if (!record) return res.status(400).json({ error: 'record가 필요해요' });
    const ownerKey = resolveOwnerKey(store, req, deviceId);
    const list = store.data.battleRecords[ownerKey] ?? [];
    list.unshift({ ...record, savedAt: Date.now() });
    store.data.battleRecords[ownerKey] = list.slice(0, MAX_BATTLE_RECORDS);
    store.save();
    res.json({ ok: true });
  });
}
