# PocketFriend(갓생몬) 서버 — Fly.io 배포용
FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production

# 의존성 레이어 캐시 — 소스만 바뀌면 npm ci를 다시 돌지 않는다
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

EXPOSE 3000
CMD ["node", "src/index.js"]
