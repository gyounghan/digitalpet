import 'package:flutter/material.dart';
import '../../core/theme/species_theme.dart';

/// 시안(design/archive/previous-ui-mock/index.html) 공용 위젯 모음.
/// 홈·케어·배틀·도감이 동일한 시안 크롬을 쓰도록 재사용한다.

/// .coin-pill — 금색 원형 dot + 텍스트(앱에선 Lv 등). bg #fff4cd, 테두리 #f0c05b.
class MockCoinPill extends StatelessWidget {
  final String text;
  const MockCoinPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF0C05B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8D46A), Color(0xFFEFA72F)],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6D4B05))),
        ],
      ),
    );
  }
}

/// .screen-top — 작은 인사말(muted) + 큰 제목(23) + 우측 트레일링(주로 coin-pill).
class MockScreenTop extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTitleTap;

  const MockScreenTop({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: MockUI.muted)),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: MockUI.ink,
                      height: 1.1)),
            ),
            if (onTitleTap != null) ...[
              const SizedBox(width: 5),
              const Icon(Icons.edit, size: 13, color: MockUI.muted),
            ],
          ],
        ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: onTitleTap == null
              ? head
              : GestureDetector(
                  onTap: onTitleTap,
                  behavior: HitTestBehavior.opaque,
                  child: head),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// .meter — 8px 트랙(meterTrack) + 채움 바.
class MockMeter extends StatelessWidget {
  final double value; // 0~1
  final Color color;
  final double height;
  const MockMeter({super.key, required this.value, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: MockUI.meterTrack)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// .check-line — 17px 사각 체크(완료 green / 미완료 checkTrack) + 라벨(13 800).
class MockCheckLine extends StatelessWidget {
  final String label;
  final bool done;
  const MockCheckLine({super.key, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: done ? MockUI.green : MockUI.checkTrack,
            borderRadius: BorderRadius.circular(5),
          ),
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF594F43))),
        ),
      ],
    );
  }
}

/// .routine-panel — 헤딩(제목 + 우측 span) + check-line들.
class MockRoutinePanel extends StatelessWidget {
  final String title;
  final String trailing;
  final List<(String, bool)> items;
  final Color bg;
  const MockRoutinePanel({
    super.key,
    required this.title,
    required this.trailing,
    required this.items,
    this.bg = MockUI.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MockUI.ink)),
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: MockUI.muted)),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            MockCheckLine(label: items[i].$1, done: items[i].$2),
          ],
        ],
      ),
    );
  }
}

/// .care-row — 42px 아이콘 사각(색) + 제목/부제 + 우측 mini-button.
class MockCareRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback? onTap;

  const MockCareRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: MockUI.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22, color: MockUI.speechInk),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MockUI.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: MockUI.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniButton(label: buttonLabel, enabled: enabled, onTap: onTap),
        ],
      ),
    );
  }
}

/// .mini-button — 테두리 #bfd0b3, bg #f2f9ea, 텍스트 #486b39.
class _MiniButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _MiniButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F9EA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFD0B3)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF486B39))),
        ),
      ),
    );
  }
}

/// .info-tile — 라벨(muted 11) + 값(19). 도감 요약 그리드용.
class MockInfoTile extends StatelessWidget {
  final String label;
  final String value;
  const MockInfoTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MockUI.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MockUI.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: MockUI.muted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: MockUI.ink)),
        ],
      ),
    );
  }
}
