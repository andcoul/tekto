// Premium body figure (FR-049, FR-051, FR-052; design tour 2026-11-21): anatomical muscle shapes
// drawn on a 200 × 440 canvas, left half mirrored. Muscles are lit by level 0–3 in Glacier
// with a soft glow; records get a mint outline. The same shapes as design/app-tour/index.html.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum FigureView { front, back }

const _sil = 'M100 56 L92 56 Q91 64 88 66 Q74 70 62 74 Q46 78 42 96 Q38 128 38 160 Q32 188 31 214 Q28 232 34 244 '
    'Q42 246 44 232 Q46 220 47 214 Q55 192 57 168 L60 136 Q61 160 66 190 Q60 210 62 236 Q60 270 66 302 Q70 314 70 326 '
    'Q65 356 70 392 Q66 406 64 416 Q68 424 90 422 Q90 406 85 392 Q89 356 88 326 Q90 314 92 302 Q99 266 98 240 L100 240 Z';
const _delt = 'M64 75 Q47 78 43 96 Q42 110 47 120 Q55 104 68 94 Q71 82 64 75 Z';
const _fore = 'M42 168 Q35 190 34 214 Q38 221 44 216 Q51 194 54 171 Q49 163 42 168 Z';

/// Figure parts per view (left half; mirrored when drawn).
const _parts = <FigureView, Map<String, List<String>>>{
  FigureView.front: {
    'traps': ['M92 64 Q80 70 66 75 Q80 78 92 80 Z'],
    'delts': [_delt],
    'chest': ['M98 80 Q84 78 70 82 Q62 92 64 110 Q74 124 98 121 Z'],
    'biceps': ['M47 124 Q41 140 42 160 Q47 167 53 162 Q58 144 57 126 Q52 118 47 124 Z'],
    'forearms': [_fore],
    'abs': ['R85,126,12,15,4', 'R85,144,12,15,4', 'R85,162,12,15,4', 'R86,180,11,17,4'],
    'obliques': ['M70 124 Q64 152 71 190 L82 194 L82 128 Q77 124 70 124 Z'],
    'abductors': ['M67 196 Q61 212 63 232 L70 226 Q72 210 77 200 Z'],
    'quads': ['M76 204 Q63 236 66 290 Q74 306 87 300 Q95 262 93 224 Q88 206 76 204 Z'],
    'adductors': ['M94 216 Q99 224 99 240 Q97 262 91 282 Q89 252 91 228 Z'],
    'shins': ['M73 326 Q68 354 72 386 L80 386 Q83 354 81 326 Z'],
  },
  FigureView.back: {
    'traps': ['M100 54 L92 58 Q86 66 66 75 Q82 82 90 100 L100 128 Z'],
    'rdelts': [_delt],
    'lats': ['M70 96 Q62 122 70 160 Q80 180 96 186 L96 150 Q90 122 86 104 Z'],
    'triceps': ['M47 120 Q41 140 43 160 Q49 167 55 160 Q59 140 57 122 Q52 114 47 120 Z'],
    'forearms': [_fore],
    'lowerback': ['M89 150 Q86 176 91 196 L99 197 L99 152 Z'],
    'abductors': ['M67 194 Q61 204 65 218 Q73 206 84 200 Z'],
    'glutes': ['M70 202 Q63 226 74 244 Q90 254 99 242 L99 204 Q86 196 70 202 Z'],
    'hamstrings': ['M70 250 Q63 276 69 304 L87 306 Q94 278 92 252 Q82 246 70 250 Z'],
    'adductors': ['M93 254 Q99 266 97 290 L93 298 Q94 276 93 254 Z'],
    'calves': ['M70 326 Q61 348 69 374 Q77 382 84 372 Q90 348 86 326 Z'],
  },
};

/// Muscle group (kMuscleGroups) → figure parts in each view.
const kGroupParts = <String, Map<FigureView, List<String>>>{
  'chest': {
    FigureView.front: ['chest']
  },
  'shoulders': {
    FigureView.front: ['delts'],
    FigureView.back: ['rdelts']
  },
  'triceps': {
    FigureView.back: ['triceps']
  },
  'back': {
    FigureView.back: ['lats']
  },
  'biceps': {
    FigureView.front: ['biceps']
  },
  'traps': {
    FigureView.front: ['traps'],
    FigureView.back: ['traps']
  },
  'forearms': {
    FigureView.front: ['forearms'],
    FigureView.back: ['forearms']
  },
  'quads': {
    FigureView.front: ['quads']
  },
  'hamstrings': {
    FigureView.back: ['hamstrings']
  },
  'glutes': {
    FigureView.back: ['glutes']
  },
  'abductors': {
    FigureView.front: ['abductors'],
    FigureView.back: ['abductors']
  },
  'adductors': {
    FigureView.front: ['adductors'],
    FigureView.back: ['adductors']
  },
  'calves': {
    FigureView.back: ['calves']
  },
  'abs': {
    FigureView.front: ['abs', 'obliques']
  },
  'lower_back': {
    FigureView.back: ['lowerback']
  },
};

/// Tile crop per group: view and source rectangle on the 200 × 440 canvas (square).
const kGroupTiles = <String, (FigureView, Rect)>{
  'chest': (FigureView.front, Rect.fromLTWH(50, 64, 100, 100)),
  'shoulders': (FigureView.front, Rect.fromLTWH(38, 52, 124, 124)),
  'triceps': (FigureView.back, Rect.fromLTWH(36, 90, 128, 128)),
  'back': (FigureView.back, Rect.fromLTWH(44, 70, 112, 112)),
  'biceps': (FigureView.front, Rect.fromLTWH(36, 92, 128, 128)),
  'traps': (FigureView.back, Rect.fromLTWH(52, 42, 96, 96)),
  'forearms': (FigureView.front, Rect.fromLTWH(26, 128, 148, 148)),
  'quads': (FigureView.front, Rect.fromLTWH(48, 200, 104, 104)),
  'hamstrings': (FigureView.back, Rect.fromLTWH(50, 228, 100, 100)),
  'glutes': (FigureView.back, Rect.fromLTWH(54, 176, 92, 92)),
  'abductors': (FigureView.front, Rect.fromLTWH(50, 176, 100, 100)),
  'adductors': (FigureView.front, Rect.fromLTWH(54, 200, 92, 92)),
  'calves': (FigureView.back, Rect.fromLTWH(52, 302, 96, 96)),
  'abs': (FigureView.front, Rect.fromLTWH(56, 114, 88, 88)),
  'lower_back': (FigureView.back, Rect.fromLTWH(60, 130, 80, 80)),
};

/// Converts group levels into part levels for one view.
Map<String, int> partLevels(Map<String, int> groupLevels, FigureView view) {
  final out = <String, int>{};
  groupLevels.forEach((g, l) {
    for (final p in kGroupParts[g]?[view] ?? const <String>[]) {
      if ((out[p] ?? 0) < l) out[p] = l;
    }
  });
  return out;
}

/// Parses the subset of SVG used above: M, L, Q, Z (absolute), plus `E cx,cy,rx,ry` and `R x,y,w,h,r`.
Path parseShape(String d) {
  if (d.startsWith('E')) {
    final v = d.substring(1).split(',').map(double.parse).toList();
    return Path()..addOval(Rect.fromCenter(center: Offset(v[0], v[1]), width: v[2] * 2, height: v[3] * 2));
  }
  if (d.startsWith('R')) {
    final v = d.substring(1).split(',').map(double.parse).toList();
    return Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(v[0], v[1], v[2], v[3]), Radius.circular(v[4])));
  }
  final path = Path();
  final tokens = RegExp(r'[MLQZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i++]) {
      case 'M':
        path.moveTo(n(), n());
      case 'L':
        path.lineTo(n(), n());
      case 'Q':
        path.quadraticBezierTo(n(), n(), n(), n());
      case 'Z':
        path.close();
    }
  }
  return path;
}

final _cache = <String, Path>{};
Path _shape(String d) => _cache.putIfAbsent(d, () => parseShape(d));

const _levelColors = <List<Color>>[
  [Color(0xFF3A3F4E), Color(0xFF2B2F3B)],
  [Color(0xFF55678F), Color(0xFF3E4C6C)],
  [Color(0xFF8FA8E8), Color(0xFF6D86C8)],
  [Color(0xFFDCE6FF), AppColors.glacier],
];

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.view, this.levels, this.records, this.crop);
  final FigureView view;
  final Map<String, int> levels;
  final Set<String> records;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        (size.width / crop.width < size.height / crop.height) ? size.width / crop.width : size.height / crop.height;
    canvas.save();
    canvas.translate((size.width - crop.width * scale) / 2, (size.height - crop.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-crop.left, -crop.top);

    final silPaint = Paint()
      ..shader =
          ui.Gradient.linear(const Offset(0, 0), const Offset(0, 440), const [Color(0xFF2B2F3B), Color(0xFF1C1F27)]);
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 34), width: 34, height: 44), silPaint);
    void both(void Function() draw) {
      draw();
      canvas.save();
      canvas.translate(200, 0);
      canvas.scale(-1, 1);
      draw();
      canvas.restore();
    }

    both(() => canvas.drawPath(_shape(_sil), silPaint));
    final parts = _parts[view]!;
    // Glow under the bright muscles.
    both(() {
      parts.forEach((name, shapes) {
        final l = levels[name] ?? 0;
        if (l < 2) return;
        final glow = Paint()
          ..color = AppColors.glacier.withValues(alpha: l == 3 ? 0.55 : 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        for (final d in shapes) {
          canvas.drawPath(_shape(d), glow);
        }
      });
    });
    both(() {
      parts.forEach((name, shapes) {
        final l = (levels[name] ?? 0).clamp(0, 3);
        final record = records.contains(name);
        for (final d in shapes) {
          final p = _shape(d);
          final b = p.getBounds();
          canvas.drawPath(p, Paint()..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, _levelColors[l]));
          canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = record ? 2.4 : 1.3
              ..color = record ? AppColors.mint : const Color(0xFF12141A),
          );
        }
      });
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.view != view || old.levels != levels || old.records != records || old.crop != crop;
}

/// A full front or back figure. [groupLevels] maps muscle groups (kMuscleGroups) to 0–3.
class MuscleFigure extends StatelessWidget {
  const MuscleFigure({
    super.key,
    required this.view,
    this.groupLevels = const {},
    this.recordGroups = const {},
    this.height = 220,
    this.semanticLabel,
  });

  final FigureView view;
  final Map<String, int> groupLevels;
  final Set<String> recordGroups;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final records = <String>{
      for (final g in recordGroups) ...?kGroupParts[g]?[view],
    };
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: height * 200 / 440,
        child: CustomPaint(
          painter: _FigurePainter(view, partLevels(groupLevels, view), records, const Rect.fromLTWH(0, 0, 200, 440)),
        ),
      ),
    );
  }
}

/// Square tile showing one muscle group lit on a cropped figure (focus picker, recovery rows).
class MuscleTile extends StatelessWidget {
  const MuscleTile({super.key, required this.group, this.size = 96, this.level = 3});
  final String group;
  final double size;
  final int level;

  @override
  Widget build(BuildContext context) {
    final (view, crop) = kGroupTiles[group]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const RadialGradient(
            center: Alignment(0, -0.6), radius: 1.0, colors: [Color(0xFF232838), Color(0xFF14161C)]),
        border: Border.all(color: AppColors.steel),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _FigurePainter(view, partLevels({group: level}, view), const {}, crop)),
    );
  }
}
