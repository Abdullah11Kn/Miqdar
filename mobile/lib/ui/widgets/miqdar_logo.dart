import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'miqdar_logo_paths.dart';

/// The Miqdar logo as vector paths, parsed once from [miqdar_logo_paths.dart].
class MiqdarLogoPaths {
  MiqdarLogoPaths._();

  static final Path bowl = _parse(kBowlPath);
  static final Path star = _parse(kStarPath);
  static final List<Path> letters = [for (final l in kWordmarkLetters) _parse(l)];

  static final RegExp _command = RegExp(r'([MLCZ])([^MLCZ]*)');
  static final RegExp _number = RegExp(r'-?\d+(?:\.\d+)?');

  /// Reads the M, L, C and Z commands the generator writes, all absolute.
  static Path _parse(String d) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final m in _command.allMatches(d)) {
      final n = [for (final x in _number.allMatches(m.group(2)!)) double.parse(x.group(0)!)];
      switch (m.group(1)) {
        case 'M':
          path.moveTo(n[0], n[1]);
        case 'L':
          path.lineTo(n[0], n[1]);
        case 'C':
          path.cubicTo(n[0], n[1], n[2], n[3], n[4], n[5]);
        case 'Z':
          path.close();
      }
    }
    return path;
  }
}

/// Where the mark is in its entrance. Every value runs from 0 to 1, and
/// [MiqdarMarkFrame.done] is the finished logo.
@immutable
class MiqdarMarkFrame {
  const MiqdarMarkFrame({
    required this.outline,
    required this.fill,
    required this.outlineFade,
    required this.star,
    required this.burst,
    required this.dip,
  });

  static const done = MiqdarMarkFrame(outline: 1, fill: 1, outlineFade: 1, star: 1, burst: 1, dip: 0);

  /// How much of the bowl's outline is drawn.
  final double outline;

  /// How high the bowl's fill has risen, from the foot to the rim.
  final double fill;

  /// How far the drawn outline has faded once the fill covers it.
  final double outlineFade;

  /// The star's arrival. May pass 1 briefly, for an overshoot.
  final double star;

  /// The sparkle around the star after it lands.
  final double burst;

  /// The mark's vertical offset, in logo units, as it settles like a weighed plate.
  final double dip;
}

/// Paints the bowl and the star. Width decides the size; the height follows the logo.
class MiqdarMarkPainter extends CustomPainter {
  MiqdarMarkPainter({required this.frame, required this.ink, required this.green});

  final MiqdarMarkFrame frame;
  final Color ink;
  final Color green;

  static double heightFor(double width) => width * kMarkHeight / kMarkWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / kMarkWidth;
    canvas.save();
    canvas.scale(k);
    canvas.translate(0, frame.dip);

    _paintBowl(canvas, k);
    _paintBurst(canvas);
    _paintStar(canvas);

    canvas.restore();
  }

  void _paintBowl(Canvas canvas, double k) {
    final bowl = MiqdarLogoPaths.bowl;

    // The fill rises from the foot with a gentle wave on top, like food filling the bowl.
    if (frame.fill > 0) {
      canvas.save();
      if (frame.fill < 1) {
        final level = kMarkHeight * (1 - frame.fill);
        final amp = 14 * math.sin(math.pi * frame.fill);
        final phase = frame.fill * math.pi * 3;
        final clip = Path()..moveTo(-20, kMarkHeight + 20);
        for (double x = -20; x <= kMarkWidth + 20; x += 20) {
          clip.lineTo(x, level + amp * math.sin(x / kMarkWidth * math.pi * 2 + phase));
        }
        clip
          ..lineTo(kMarkWidth + 20, kMarkHeight + 20)
          ..close();
        canvas.clipPath(clip);
      }
      canvas.drawPath(bowl, Paint()..color = ink);
      canvas.restore();
    }

    // The outline is traced first, then dissolves into the fill.
    final outlineAlpha = 1 - frame.outlineFade;
    if (frame.outline > 0 && outlineAlpha > 0) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withValues(alpha: ink.a * outlineAlpha);
      if (frame.outline >= 1) {
        canvas.drawPath(bowl, stroke);
      } else {
        for (final metric in bowl.computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * frame.outline), stroke);
        }
      }
    }
  }

  void _paintStar(Canvas canvas) {
    if (frame.star <= 0) return;
    final t = frame.star;
    canvas.save();
    canvas.translate(kStarCenterX, kStarCenterY);
    canvas.rotate((1 - t.clamp(0.0, 1.0)) * -math.pi * 0.75);
    canvas.scale(t);
    canvas.translate(-kStarCenterX, -kStarCenterY);
    canvas.drawPath(MiqdarLogoPaths.star, Paint()..color = green);
    canvas.restore();
  }

  void _paintBurst(Canvas canvas) {
    final b = frame.burst;
    if (b <= 0 || b >= 1) return;
    final fade = 1 - Curves.easeIn.transform(b);
    final reach = Curves.easeOutCubic.transform(b);

    // Fine rays leave the star, the way light catches it.
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = green.withValues(alpha: 0.85 * fade);
    const rays = 8;
    for (var i = 0; i < rays; i++) {
      final a = i * math.pi * 2 / rays + math.pi / rays;
      final from = 150 + 110 * reach;
      final to = from + 70 * (1 - reach) + 12;
      canvas.drawLine(
        Offset(kStarCenterX + math.cos(a) * from, kStarCenterY + math.sin(a) * from),
        Offset(kStarCenterX + math.cos(a) * to, kStarCenterY + math.sin(a) * to),
        ray,
      );
    }

    // Two small twinkles beside it, rising and falling.
    for (final (dx, dy, delay, size) in const [(-235.0, -150.0, 0.0, 0.16), (215.0, -235.0, 0.18, 0.11)]) {
      final local = ((b - delay) / (1 - delay)).clamp(0.0, 1.0);
      final s = math.sin(math.pi * local) * size;
      if (s <= 0) continue;
      canvas.save();
      canvas.translate(kStarCenterX + dx, kStarCenterY + dy);
      canvas.scale(s);
      canvas.translate(-kStarCenterX, -kStarCenterY);
      canvas.drawPath(MiqdarLogoPaths.star, Paint()..color = green.withValues(alpha: 0.9));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MiqdarMarkPainter old) =>
      old.frame != frame || old.ink != ink || old.green != green;
}

/// Paints the Latin wordmark. Each letter has its own entrance from 0 to 1.
class MiqdarWordmarkPainter extends CustomPainter {
  MiqdarWordmarkPainter({required this.letters, required this.ink});

  /// One value per letter of "Miqdar"; null means all are shown.
  final List<double>? letters;
  final Color ink;

  static double heightFor(double width) => width * kWordmarkHeight / kWordmarkWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / kWordmarkWidth;
    canvas.save();
    canvas.scale(k);
    final paths = MiqdarLogoPaths.letters;
    for (var i = 0; i < paths.length; i++) {
      final t = letters == null ? 1.0 : letters![i];
      if (t <= 0) continue;
      canvas.save();
      canvas.translate(0, (1 - t) * kWordmarkHeight * 0.35);
      canvas.drawPath(paths[i], Paint()..color = ink.withValues(alpha: ink.a * t.clamp(0.0, 1.0)));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MiqdarWordmarkPainter old) => true;
}
