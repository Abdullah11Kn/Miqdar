import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// The Miqdar mark: the letter meem inside a dial that is three quarters measured.
class MiqdarMark extends StatelessWidget {
  const MiqdarMark({super.key, this.size = 36, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final dark = onDark || Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DialPainter(
          progress: 0.75,
          strokeWidth: size * 0.082,
          track: dark ? const Color(0xFF4A3A2A) : const Color(0xFFE2D6C2),
          color: MiqdarColors.saffron,
        ),
        child: Center(
          child: Text(
            'م',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Plex',
              fontWeight: FontWeight.w600,
              fontSize: size * 0.58,
              height: 1,
              color: dark ? MiqdarColors.paper : MiqdarColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class MiqdarWordmark extends StatelessWidget {
  const MiqdarWordmark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Miq.of(context).text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Miqdar', style: MiqType.display(size, color: ink, height: 1.1)),
        SizedBox(width: size * 0.4),
        Container(width: 1, height: size * 0.8, color: ink.withValues(alpha: 0.25)),
        SizedBox(width: size * 0.4),
        Text(
          'مقدار',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Amiri', fontSize: size * 0.92, height: 1.1, color: ink),
        ),
      ],
    );
  }
}

/// The brand's one recurring shape: a plate seen from above, marked like a scale.
/// Everything measured in the app is drawn on this dial.
class MeasureDial extends StatelessWidget {
  const MeasureDial({
    super.key,
    required this.size,
    required this.progress,
    required this.child,
    this.strokeWidth = 9,
    this.color = MiqdarColors.saffron,
    this.ticks = 60,
    this.dashedTrack = false,
  });

  final double size;

  /// 0 to 1 around the dial.
  final double progress;
  final Widget child;
  final double strokeWidth;
  final Color color;
  final int ticks;
  final bool dashedTrack;

  @override
  Widget build(BuildContext context) {
    final miq = Miq.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, inner) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DialPainter(
            progress: value,
            strokeWidth: strokeWidth,
            track: miq.track,
            color: color,
            tickColor: miq.muted.withValues(alpha: 0.45),
            ticks: ticks,
            dashedTrack: dashedTrack,
          ),
          child: inner,
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.progress,
    required this.strokeWidth,
    required this.track,
    required this.color,
    this.tickColor = Colors.transparent,
    this.ticks = 0,
    this.dashedTrack = false,
  });

  final double progress;
  final double strokeWidth;
  final Color track;
  final Color color;
  final Color tickColor;
  final int ticks;
  final bool dashedTrack;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    const top = -math.pi / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (dashedTrack) {
      const dashes = 48;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          top + i * 2 * math.pi / dashes,
          math.pi / dashes,
          false,
          trackPaint,
        );
      }
    } else {
      canvas.drawCircle(center, radius, trackPaint);
    }

    // Scale graduations just inside the ring, longer every fifth one.
    if (ticks > 0) {
      for (var i = 0; i < ticks; i++) {
        final angle = top + 2 * math.pi * i / ticks;
        final major = i % 5 == 0;
        final dir = Offset(math.cos(angle), math.sin(angle));
        final outer = radius - strokeWidth / 2 - 5;
        final inner = outer - (major ? 9 : 4);
        canvas.drawLine(
          center + dir * outer,
          center + dir * inner,
          Paint()
            ..color = tickColor
            ..strokeWidth = major ? 1.4 : 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    if (progress <= 0.002) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      top,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.tickColor != tickColor ||
      old.dashedTrack != dashedTrack;
}

/// A title in the display serif, with an optional action at the far end.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction, this.size = 24});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: MiqType.display(size, color: Miq.of(context).text, height: 1.2))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

/// Rows on one sheet with hairlines between them, like a page in a ledger.
class Ledger extends StatelessWidget {
  const Ledger({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final miq = Miq.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: miq.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: miq.hairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: miq.hairline),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A navigation row in a [Ledger].
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final miq = Miq.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: miq.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: miq.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: miq.muted)),
                  ],
                ],
              ),
            ),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(Icons.chevron_right_rounded, color: miq.muted, size: 22)),
          ],
        ),
      ),
    );
  }
}

/// A nutrient as the brand shows it: serif amount, small label, thin bar.
class MacroColumn extends StatelessWidget {
  const MacroColumn({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.progress,
  });

  final String label;
  final String value;
  final Color color;

  /// Null when there is no goal to measure against.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final miq = Miq.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: MiqType.display(25, color: miq.text, height: 1.15)),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: miq.muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (progress ?? 0).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: miq.track,
            color: color,
          ),
        ),
      ],
    );
  }
}
