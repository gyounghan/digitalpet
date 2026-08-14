import http from 'node:http';
import express from 'express';
import { Server } from 'socket.io';
import { config } from './config.js';
import { Store } from './store.js';
import { registerAuthRoutes } from './auth.js';
import { registerPetRoutes } from './pet_routes.js';
import { registerRankingRoutes } from './ranking.js';
import { registerBattleGateway } from './battle_gateway.js';

const app = express();
app.use(express.json({ limit: '256kb' }));

const store = new Store(config.dataFile);

app.get('/health', (_req, res) => res.json({ ok: true }));
registerAuthRoutes(app, store);
registerPetRoutes(app, store);
registerRankingRoutes(app, store);

const server = http.createServer(app);
const io = new Server(server, {
  transports: ['websocket'],
  cors: { origin: '*' },
});
registerBattleGateway(io, store);

server.listen(config.port, () => {
  console.log(`PocketFriend 서버 시작 — http://localhost:${config.port}`);
  console.log(`데이터 파일: ${config.dataFile}`);
});
