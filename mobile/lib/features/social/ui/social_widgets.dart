// Shared bits for Feed and Friends: initials avatar and score ring (own style: rings, not hexagons).
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const kFriendColors = [AppColors.glacier, AppColors.mint, Color(0xFFC9B6FF), Color(0xFF8FD3FF), Color(0xFFB9C6E6)];

Color friendColor(String userId) => kFriendColors[userId.hashCode.abs() % kFriendColors.length];

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, required this.color, this.size = 40});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [color, const Color(0xFF3E4C6C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 1.5)],
      ),
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.36, color: AppColors.ink)),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.max = 300, this.color = AppColors.glacier, this.size = 50});
  final int score;
  final int max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(min(1, score / max), color),
          child: Center(child: Text('$score', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(
        r,
        0,
        2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppColors.steel);
    canvas.drawArc(
        r,
        -pi / 2,
        2 * pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
