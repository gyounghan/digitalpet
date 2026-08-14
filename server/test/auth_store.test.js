import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { Store } from '../src/store.js';
import {
  registerEmail,
  loginEmail,
  loginProviderUser,
  verifyToken,
  verifyKakaoToken,
  verifyNaverToken,
} from '../src/auth.js';
import { applyBattleResult, updateRankingProfile, RP_WIN, RP_LOSS } from '../src/ranking.js';

let store;

beforeEach(() => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-test-'));
  store = new Store(path.join(dir, 'db.json'));
});

test('이메일 가입 → 로그인 → 토큰 검증', () => {
  const reg = registerEmail(store, {
    email: 'a@b.com', password: 'secret1', nickname: '한',
  });
  assert.ok(reg.token);
  assert.equal(reg.user.nickname, '한');

  const login = loginEmail(store, { email: 'a@b.com', password: 'secret1' });
  assert.ok(login.token);
  assert.equal(verifyToken(login.token), reg.user.id);

  const wrong = loginEmail(store, { email: 'a@b.com', password: 'nope' });
  assert.ok(wrong.error);
});

test('중복 이메일·짧은 비밀번호 거부', () => {
  registerEmail(store, { email: 'a@b.com', password: 'secret1' });
  assert.ok(registerEmail(store, { email: 'a@b.com', password: 'secret2' }).error);
  assert.ok(registerEmail(store, { email: 'c@d.com', password: '12345' }).error);
  assert.ok(registerEmail(store, { email: 'not-email', password: 'secret1' }).error);
});

test('소셜 로그인 — 같은 providerId면 같은 계정', () => {
  const first = loginProviderUser(store, 'kakao', '12345', '카카오유저');
  const second = loginProviderUser(store, 'kakao', '12345', null);
  assert.equal(first.user.id, second.user.id);
  const other = loginProviderUser(store, 'naver', '12345', null);
  assert.notEqual(first.user.id, other.user.id);
});

test('카카오/네이버 토큰 검증 — 프로바이더 응답 파싱', async () => {
  const kakaoFetch = async () => ({
    ok: true,
    json: async () => ({
      id: 999, kakao_account: { profile: { nickname: '카카오' } },
    }),
  });
  const kakao = await verifyKakaoToken('token', kakaoFetch);
  assert.deepEqual(kakao, { providerId: '999', nickname: '카카오' });

  const naverFetch = async () => ({
    ok: true,
    json: async () => ({ response: { id: 'abc', nickname: '네이버' } }),
  });
  const naver = await verifyNaverToken('token', naverFetch);
  assert.deepEqual(naver, { providerId: 'abc', nickname: '네이버' });

  const failFetch = async () => ({ ok: false });
  assert.equal(await verifyKakaoToken('bad', failFetch), null);
  assert.equal(await verifyNaverToken('bad', failFetch), null);
});

test('기기-계정 연결 — 게스트 펫이 계정으로 이관된다', () => {
  const guestKey = store.ownerKeyForDevice('device-1');
  assert.equal(guestKey, 'dev:device-1');
  store.data.pets[guestKey] = { name: '털뭉치', level: 3 };

  const { user } = registerEmail(store, { email: 'a@b.com', password: 'secret1' });
  store.linkDevice('device-1', user.id);

  assert.equal(store.ownerKeyForDevice('device-1'), user.id);
  assert.equal(store.data.pets[user.id].name, '털뭉치');
  assert.equal(store.data.pets['dev:device-1'], undefined);
});

test('영속화 — 저장 후 다시 로드해도 데이터 유지', () => {
  registerEmail(store, { email: 'a@b.com', password: 'secret1' });
  store.data.pets['dev:d1'] = { name: '펫' };
  store.save();

  const reloaded = new Store(store.filePath);
  assert.equal(Object.keys(reloaded.data.users).length, 1);
  assert.equal(reloaded.data.pets['dev:d1'].name, '펫');
});

test('랭킹 RP — 승 +25·패 +5, 프로필 최신화', () => {
  const key = 'dev:d1';
  updateRankingProfile(store, key, 'd1', {
    petName: '용맹이', level: 12, evolutionType: 'tiger', evolutionStage: 3,
  });
  applyBattleResult(store, key, { isVictory: true, isDominantVictory: false });
  applyBattleResult(store, key, { isVictory: false, isDominantVictory: false });

  const entry = store.data.rankings[key];
  assert.equal(entry.rp, RP_WIN + RP_LOSS);
  assert.equal(entry.battleVictoryCount, 1);
  assert.equal(entry.battleDefeatCount, 1);
  assert.equal(entry.name, '용맹이');
  assert.equal(entry.deviceId, 'd1');
});
