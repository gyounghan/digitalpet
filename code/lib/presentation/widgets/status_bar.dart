import 'package:flutter/material.dart';

/// 상태바 위젯
/// Pet의 상태(hunger, happiness, stamina)를 시각적으로 표시
/// 
/// 사용 예시:
/// ```dart
/// StatusBar(
///   label: 'Hunger',
///   value: 75,
///   color: Colors.orange,
/// )
/// ```
class StatusBar extends StatelessWidget {
  /// 상태바 라벨 (예: "Hunger", "Happiness", "Stamina")
  final String label;
  
  /// 상태 값 (0~100)
  final int value;
  
  /// 상태바 색상
  final Color color;
  
  const StatusBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨과 값 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$value / 100',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 진행바
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 20,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
