import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/pet.dart';

/// 비석 위젯
/// 펫이 사망했을 때 HomeScreen에 표시되는 비석 UI
///
/// [onResurrectPressed]는 리워드 광고 흐름(로드~표시/실패)을 끝까지 처리하는
/// Future를 반환해야 한다. 위젯은 그 동안 버튼을 비활성화하고 스피너를 표시한다.
class GravestoneWidget extends StatefulWidget {
  final Pet pet;
  final Future<void> Function() onResurrectPressed;

  const GravestoneWidget({
    super.key,
    required this.pet,
    required this.onResurrectPressed,
  });

  @override
  State<GravestoneWidget> createState() => _GravestoneWidgetState();
}

class _GravestoneWidgetState extends State<GravestoneWidget> {
  bool _isLoading = false;

  Future<void> _handlePressed() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onResurrectPressed();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 비석 아이콘
          Container(
            width: 160,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(80),
                topRight: Radius.circular(80),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sentiment_very_dissatisfied,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  pet.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.gravestoneTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (pet.deathDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDeathDate(pet.deathDate!),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 부활 횟수 표시
          if (pet.resurrectCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '부활 횟수: ${pet.resurrectCount}회',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
          // 부활 버튼 — 광고 로딩 중에는 비활성화하고 스피너 표시
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handlePressed,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              _isLoading ? '광고 로딩 중...' : AppStrings.resurrectButton,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeathDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
