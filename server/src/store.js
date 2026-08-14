import fs from 'node:fs';
import path from 'node:path';

/// JSON 파일 영속 저장소
///
/// 초기 규모(수백 유저)에 맞춘 단순 저장소 — 외부 DB 셋업 없이 어느 PC에서든
/// `npm start`만으로 구동된다. 쓰기는 tmp 파일 + rename으로 원자적 처리.
/// 규모가 커지면 이 클래스만 SQLite/Postgres 구현으로 교체하면 된다.
///
/// 데이터 구조:
/// - users:        { [userId]: { id, provider, providerId?, email?, passwordHash?, nickname, createdAt } }
/// - deviceLinks:  { [deviceId]: userId }          — 기기 → 계정 연결
/// - pets:         { [ownerKey]: petData }         — ownerKey = userId 또는 'dev:{deviceId}'
/// - transfers:    { [code]: { ownerKey, expiresAt } }
/// - rankings:     { [ownerKey]: { deviceId, name, level, rp, evolutionType, evolutionStage, battleVictoryCount, battleDefeatCount } }
/// - battleRecords:{ [ownerKey]: [record, ...] }   — 최근 50개 유지
export class Store {
  constructor(filePath) {
    this.filePath = filePath;
    this.data = {
      users: {},
      deviceLinks: {},
      pets: {},
      transfers: {},
      rankings: {},
      battleRecords: {},
    };
    this._load();
  }

  _load() {
    try {
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      this.data = { ...this.data, ...JSON.parse(raw) };
    } catch {
      // 파일 없음/파싱 실패 → 빈 상태로 시작
    }
  }

  save() {
    const dir = path.dirname(this.filePath);
    fs.mkdirSync(dir, { recursive: true });
    const tmp = `${this.filePath}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 1));
    fs.renameSync(tmp, this.filePath);
  }

  /// 기기 ID → 저장 키. 계정에 연결된 기기면 계정 키, 아니면 게스트 키.
  ownerKeyForDevice(deviceId) {
    const userId = this.data.deviceLinks[deviceId];
    return userId ?? `dev:${deviceId}`;
  }

  /// 기기를 계정에 연결하고, 게스트 키로 저장돼 있던 펫/랭킹/전적을 계정 키로 이관
  linkDevice(deviceId, userId) {
    const guestKey = `dev:${deviceId}`;
    this.data.deviceLinks[deviceId] = userId;

    for (const table of ['pets', 'rankings', 'battleRecords']) {
      const guestValue = this.data[table][guestKey];
      if (guestValue !== undefined && this.data[table][userId] === undefined) {
        this.data[table][userId] = guestValue;
      }
      delete this.data[table][guestKey];
    }
    this.save();
  }
}
