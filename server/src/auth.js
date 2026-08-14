import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { config } from './config.js';

/// 계정/인증 서비스 — 이메일 + 카카오/네이버 소셜 로그인
///
/// 소셜 로그인 방식: 앱이 각 SDK로 access token을 얻어 서버에 전달하면
/// 서버가 프로바이더 API로 검증해 사용자 식별자를 얻고 자체 JWT를 발급한다.
/// (서버에는 카카오/네이버 앱 키가 필요 없다 — 키는 앱 SDK 쪽에만 필요)

export function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });
}

export function verifyToken(token) {
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    return payload.sub;
  } catch {
    return null;
  }
}

/// Authorization: Bearer 헤더가 유효하면 req.userId를 채운다 (없어도 통과 —
/// 게스트(deviceId) 사용을 허용하는 오프라인 우선 설계)
export function optionalAuth(req, _res, next) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  req.userId = token ? verifyToken(token) : null;
  next();
}

function publicUser(user) {
  return {
    id: user.id,
    provider: user.provider,
    email: user.email ?? null,
    nickname: user.nickname,
  };
}

function findUserByEmail(store, email) {
  return Object.values(store.data.users).find(
    (u) => u.provider === 'email' && u.email === email,
  );
}

function findUserByProvider(store, provider, providerId) {
  return Object.values(store.data.users).find(
    (u) => u.provider === provider && u.providerId === providerId,
  );
}

function createUser(store, fields) {
  const user = {
    id: crypto.randomUUID(),
    createdAt: Date.now(),
    ...fields,
  };
  store.data.users[user.id] = user;
  store.save();
  return user;
}

/// 이메일 회원가입 — 성공 시 { token, user }, 실패 시 { error }
export function registerEmail(store, { email, password, nickname }) {
  if (!email || !email.includes('@')) return { error: '올바른 이메일을 입력해주세요' };
  if (!password || password.length < 6) return { error: '비밀번호는 6자 이상이어야 해요' };
  if (findUserByEmail(store, email)) return { error: '이미 가입된 이메일이에요' };

  const user = createUser(store, {
    provider: 'email',
    email,
    passwordHash: bcrypt.hashSync(password, 10),
    nickname: nickname || email.split('@')[0],
  });
  return { token: signToken(user.id), user: publicUser(user) };
}

/// 이메일 로그인
export function loginEmail(store, { email, password }) {
  const user = findUserByEmail(store, email ?? '');
  if (!user || !bcrypt.compareSync(password ?? '', user.passwordHash)) {
    return { error: '이메일 또는 비밀번호가 맞지 않아요' };
  }
  return { token: signToken(user.id), user: publicUser(user) };
}

/// 소셜 로그인 공통 — 프로바이더 사용자 정보로 find-or-create
export function loginProviderUser(store, provider, providerId, nickname) {
  let user = findUserByProvider(store, provider, providerId);
  user ??= createUser(store, {
    provider,
    providerId,
    nickname: nickname || `${provider}유저`,
  });
  return { token: signToken(user.id), user: publicUser(user) };
}

/// 카카오 access token 검증 → 사용자 식별
/// https://kapi.kakao.com/v2/user/me (Bearer 토큰만으로 호출 가능)
export async function verifyKakaoToken(accessToken, fetcher = fetch) {
  const res = await fetcher('https://kapi.kakao.com/v2/user/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const body = await res.json();
  if (!body.id) return null;
  return {
    providerId: String(body.id),
    nickname: body.kakao_account?.profile?.nickname ?? null,
  };
}

/// 네이버 access token 검증 → 사용자 식별
/// https://openapi.naver.com/v1/nid/me
export async function verifyNaverToken(accessToken, fetcher = fetch) {
  const res = await fetcher('https://openapi.naver.com/v1/nid/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const body = await res.json();
  const id = body.response?.id;
  if (!id) return null;
  return {
    providerId: String(id),
    nickname: body.response?.nickname ?? null,
  };
}

/// /auth 라우트 등록
export function registerAuthRoutes(app, store) {
  app.post('/auth/register', (req, res) => {
    const result = registerEmail(store, req.body ?? {});
    if (result.error) return res.status(400).json(result);
    res.json(result);
  });

  app.post('/auth/login', (req, res) => {
    const result = loginEmail(store, req.body ?? {});
    if (result.error) return res.status(401).json(result);
    res.json(result);
  });

  const socialRoute = (provider, verify) => async (req, res) => {
    const { accessToken } = req.body ?? {};
    if (!accessToken) {
      return res.status(400).json({ error: 'accessToken이 필요해요' });
    }
    try {
      const info = await verify(accessToken);
      if (!info) return res.status(401).json({ error: '토큰 검증에 실패했어요' });
      res.json(loginProviderUser(store, provider, info.providerId, info.nickname));
    } catch {
      res.status(502).json({ error: `${provider} 서버에 연결할 수 없어요` });
    }
  };

  app.post('/auth/kakao', socialRoute('kakao', verifyKakaoToken));
  app.post('/auth/naver', socialRoute('naver', verifyNaverToken));

  app.get('/auth/me', optionalAuth, (req, res) => {
    if (!req.userId) return res.status(401).json({ error: '로그인이 필요해요' });
    const user = store.data.users[req.userId];
    if (!user) return res.status(401).json({ error: '계정을 찾을 수 없어요' });
    res.json({ user: publicUser(user) });
  });
}
