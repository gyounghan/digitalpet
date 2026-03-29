import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
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

  /// 서버 URL (개발: localhost:3000, 프로덕션: 실제 서버)
  static const String defaultServerUrl = 'http://10.0.2.2:3000';

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
  void joinQueue({
    required String petName,
    required int level,
    required int hunger,
    required int happiness,
    required int stamina,
    required int evolutionStage,
    String? evolutionType,
    required int todaySteps,
    required int todayExerciseMinutes,
  }) {
    _socket?.emit('battle:join', {
      'petName': petName,
      'level': level,
      'hunger': hunger,
      'happiness': happiness,
      'stamina': stamina,
      'evolutionStage': evolutionStage,
      'evolutionType': evolutionType,
      'todaySteps': todaySteps,
      'todayExerciseMinutes': todayExerciseMinutes,
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
