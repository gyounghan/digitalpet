import 'package:flutter/material.dart';

/// 진화 단계 헬퍼
/// 진화 단계에 따른 UI 표시를 위한 유틸리티
class EvolutionHelper {
  EvolutionHelper._(); // private constructor
  
  /// 진화 단계 이름 반환
  /// 
  /// [stage] 진화 단계 (0~4)
  /// 
  /// 반환: 진화 단계 이름
  static String getEvolutionStageName(int stage) {
    switch (stage) {
      case 0:
        return '알';
      case 1:
        return '유년기';
      case 2:
        return '성장기';
      case 3:
        return '성체';
      case 4:
        return '완전체';
      default:
        return '알';
    }
  }
  
  /// 진화 단계에 따른 아이콘 반환
  /// 
  /// [stage] 진화 단계 (0~4)
  /// 
  /// 반환: 진화 단계에 맞는 아이콘
  static IconData getEvolutionIcon(int stage) {
    switch (stage) {
      case 0:
        return Icons.egg; // 알
      case 1:
        return Icons.child_care; // 유년기
      case 2:
        return Icons.auto_awesome; // 성장기
      case 3:
        return Icons.pets; // 성체
      case 4:
        return Icons.stars; // 완전체
      default:
        return Icons.egg;
    }
  }
  
  /// 진화 단계에 따른 색상 반환
  /// 
  /// [stage] 진화 단계 (0~4)
  /// 
  /// 반환: 진화 단계에 맞는 색상
  static Color getEvolutionColor(int stage) {
    switch (stage) {
      case 0:
        return Colors.white; // 알 - 흰색
      case 1:
        return Colors.lightBlue; // 유년기 - 연한 파랑
      case 2:
        return Colors.green; // 성장기 - 초록
      case 3:
        return Colors.orange; // 성체 - 주황
      case 4:
        return Colors.purple; // 완전체 - 보라
      default:
        return Colors.grey;
    }
  }
  
  /// 진화 단계에 따른 배경색 반환
  /// 
  /// [stage] 진화 단계 (0~4)
  /// 
  /// 반환: 진화 단계에 맞는 배경색
  static Color getEvolutionBackgroundColor(int stage) {
    switch (stage) {
      case 0:
        return Colors.grey[200]!; // 알 - 연한 회색
      case 1:
        return Colors.lightBlue[100]!; // 유년기 - 연한 파랑
      case 2:
        return Colors.green[100]!; // 성장기 - 연한 초록
      case 3:
        return Colors.orange[100]!; // 성체 - 연한 주황
      case 4:
        return Colors.purple[100]!; // 완전체 - 연한 보라
      default:
        return Colors.grey[300]!;
    }
  }
}
