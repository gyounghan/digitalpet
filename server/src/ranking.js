/// 랭킹 — RP 기반 순위표
///
/// 클라이언트 계약: lib/data/datasources/ranking_remote_datasource.dart
/// - GET /ranking/top          → { top3: [entry] }
/// - GET /ranking/me/:deviceId → { top3, surrounding, me, totalCount }
///
/// entry: { rank, deviceId, name, level, rp, evolutionType, evolutionStage,
///          battleVictoryCount, battleDefeatCount, isMine }
///
/// RP 규칙: 승리 +25 (압승 +35), 패배 +5 (참여 보상 — 0 밑으로 내려가지 않음)

export const RP_WIN = 25;
export const RP_DOMINANT_WIN = 35;
export const RP_LOSS = 5;

function entryFor(store, ownerKey) {
  return (store.data.rankings[ownerKey] ??= {
    deviceId: null,
    name: '???',
    level: 1,
    rp: 0,
    evolutionType: null,
    evolutionStage: 1,
    battleVictoryCount: 0,
    battleDefeatCount: 0,
  });
}

/// 펫 동기화/배틀 입장 시 프로필(이름·레벨·진화) 최신화
export function updateRankingProfile(store, ownerKey, deviceId, pet) {
  if (!pet) return;
  const entry = entryFor(store, ownerKey);
  if (deviceId) entry.deviceId = deviceId;
  if (pet.name || pet.petName) entry.name = pet.name ?? pet.petName;
  if (pet.level) entry.level = pet.level;
  if (pet.evolutionType !== undefined) entry.evolutionType = pet.evolutionType;
  if (pet.evolutionStage) entry.evolutionStage = pet.evolutionStage;
}

/// 배틀 결과 반영 (deviceId 없는 참가자는 호출하지 말 것 — 프로토콜 명세)
export function applyBattleResult(store, ownerKey, { isVictory, isDominantVictory }) {
  const entry = entryFor(store, ownerKey);
  if (isVictory) {
    entry.rp += isDominantVictory ? RP_DOMINANT_WIN : RP_WIN;
    entry.battleVictoryCount += 1;
  } else {
    entry.rp += RP_LOSS;
    entry.battleDefeatCount += 1;
  }
  store.save();
}

function sortedEntries(store) {
  return Object.entries(store.data.rankings)
    .map(([ownerKey, e]) => ({ ownerKey, ...e }))
    .sort((a, b) => b.rp - a.rp || b.level - a.level)
    .map((e, i) => ({ ...e, rank: i + 1 }));
}

function toDto(entry, isMine = false) {
  const { ownerKey: _, ...rest } = entry;
  return { ...rest, isMine };
}

export function registerRankingRoutes(app, store) {
  app.get('/ranking/top', (_req, res) => {
    const top3 = sortedEntries(store).slice(0, 3).map((e) => toDto(e));
    res.json({ top3 });
  });

  app.get('/ranking/me/:deviceId', (req, res) => {
    const ownerKey = store.ownerKeyForDevice(req.params.deviceId);
    const all = sortedEntries(store);
    const myIndex = all.findIndex((e) => e.ownerKey === ownerKey);
    const me = myIndex >= 0 ? toDto(all[myIndex], true) : null;

    // 내 주변 5명 (나 포함 위2·아래2, 경계는 밀어서 5명 유지)
    let surrounding = [];
    if (myIndex >= 0) {
      const start = Math.max(
        0, Math.min(myIndex - 2, all.length - 5));
      surrounding = all.slice(start, start + 5)
        .map((e) => toDto(e, e.ownerKey === ownerKey));
    }

    res.json({
      top3: all.slice(0, 3).map((e) => toDto(e, e.ownerKey === ownerKey)),
      surrounding,
      me,
      totalCount: all.length,
    });
  });
}
