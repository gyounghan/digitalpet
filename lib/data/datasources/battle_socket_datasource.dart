import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/constants/server_config.dart';
import '../../domain/usecases/battle_with_activity_usecase.dart' show BattleTurn;

/// 배틀 소켓 이벤트 콜백
typedef OnMatchedCallback = void Function(String roomId, Map<String, dynamic> opponent);
typedef OnTurnCallback = void Function(BattleTurn turn);
typedef OnResultCallback = void Function(Map<String, dynamic> result);
typedef OnTimeoutCallback = void Function();
typedef OnOpponentDisconnectedCallback = void Function();

/// 배틀 서버 WebSocket 연결 관리
/// NestJS 서버의 /battle 네임스페이스에 Socket.IO로 연결
class BattleSocketDatasource {
  io.Socket? _socket;
  bool _isConnected = false;

  /// 서버 URL — ServerConfig 단일 소스 (--dart-define=SERVER_URL로 교체)
  static const String defaultServerUrl = ServerConfig.baseUrl;

  /// 이벤트 콜백
  OnMatchedCallback? onMatched;
  OnTurnCallback? onTurn;
  OnResultCallback? onResult;
  OnTimeoutCallback? onTimeout;
  OnOpponentDisconnectedCallback? onOpponentDisconnected;
  VoidCallback? onQueued;

  bool get isConnected => _isConnected;

  /// 서버 연결
  Future<void> connect({String? serverUrl}) async {
    final url = serverUrl ?? defaultServerUrl;

    _socket = io.io(
      '$url/battle',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      if (kDebugMode) {
        debugPrint('BattleSocket: 연결 성공');
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      if (kDebugMode) {
        debugPrint('BattleSocket: 연결 해제');
      }
    });

    _socket!.on('battle:queued', (_) {
      onQueued?.call();
    });

    _socket!.on('battle:matched', (data) {
      final map = data as Map<String, dynamic>;
      onMatched?.call(
        map['roomId'] as String,
        map['opponent'] as Map<String, dynamic>,
      );
    });

    _socket!.on('battle:turn', (data) {
      final map = data as Map<String, dynamic>;
      final turn = BattleTurn(
        turnNumber: map['turnNumber'] as int,
        playerSkillName: map['playerSkillName'] as String? ?? '공격',
        playerDamage: map['playerDamage'] as int,
        opponentSkillName: map['opponentSkillName'] as String? ?? '공격',
        opponentDamage: map['opponentDamage'] as int,
        playerHpRemaining: map['playerHpRemaining'] as int,
        opponentHpRemaining: map['opponentHpRemaining'] as int,
      );
      onTurn?.call(turn);
    });

    _socket!.on('battle:result', (data) {
      onResult?.call(data as Map<String, dynamic>);
    });

    _socket!.on('battle:timeout', (_) {
      onTimeout?.call();
    });

    _socket!.on('battle:opponent_disconnected', (_) {
      onOpponentDisconnected?.call();
    });

    _socket!.connect();
  }

  /// 매칭 큐 입장
  ///
  /// [deviceId]는 서버의 RP(랭킹 점수) 갱신·전적 저장 키 — 누락하면
  /// 온라인 배틀이 랭킹/전적에 반영되지 않는다.
  /// [atk]/[def]/[hp]는 클라이언트가 계산한 실전 스탯
  /// (Pet.battleAtk/battleDef/battleHp × 배틀 스타일 배수) — 도감 표시와
  /// 실전 수치가 항상 일치하도록 서버는 이 값을 그대로 사용한다.
  void joinQueue({
    String? deviceId,
    required String petName,
    required int level,
    required int evolutionStage,
    String? evolutionType,
    required int atk,
    required int def,
    required int hp,
  }) {
    _socket?.emit('battle:join', {
      'deviceId': deviceId,
      'petName': petName,
      'level': level,
      'evolutionStage': evolutionStage,
      'evolutionType': evolutionType,
      'atk': atk,
      'def': def,
      'hp': hp,
    });
  }

  /// 매칭 취소
  void cancelQueue() {
    _socket?.emit('battle:cancel');
  }

  /// 연결 해제
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
