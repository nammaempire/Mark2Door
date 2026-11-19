import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The four outcomes a shopper can land on after paying.
enum ResultKind {
  success(AppColors.success),
  failed(AppColors.danger),
  pending(AppColors.warning),
  refunded(Color(0xFF2F6FD6));

  const ResultKind(this.color);

  /// Colour of the animated badge and its accents.
  final Color color;
}

/// Animated badge for a result page, drawn in code so it stays sharp on
/// every screen and needs no image files.
///
/// It plays an intro once (the badge pops in and its mark draws itself),
/// then keeps moving gently like a looping GIF: a breathing halo for all
/// kinds, plus turning clock hands while a payment is pending. With the
/// phone's "remove animations" setting on, it shows the finished picture.
class ResultAnimation extends StatefulWidget {
  const ResultAnimation({super.key, required this.kind, this.size = 168});

  final ResultKind kind;
  final double size;

  @override
  State<ResultAnimation> createState() => _ResultAnimationState();
}

class _ResultAnimationState extends State<ResultAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _loop.repeat();
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: switch (widget.kind) {
        ResultKind.success => 'Success',
        ResultKind.failed => 'Failed',
        ResultKind.pending => 'Pending',
        ResultKind.refunded => 'Refunded',
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _ResultPainter(
            kind: widget.kind,
            intro: _intro,
            loop: _loop,
          ),
        ),
      ),
    );
  }
}

class _ResultPainter extends CustomPainter {
  _ResultPainter({required this.kind, required this.intro, required this.loop})
      : super(repaint: Listenable.merge([intro, loop]));

  final ResultKind kind;
  final Animation<double> intro;
  final Animation<double> loop;

  /// Progress of one phase of the intro, eased, clamped to 0..1.
  double _phase(double from, double to, [Curve curve = Curves.easeOut]) =>
      curve.transform(((intro.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.30;
    final color = kind.color;

    // Breathing halo: two soft rings that swell and fade once the badge
    // has landed, and keep going for as long as the page is open.
    final appear = _phase(0, 0.4);
    final breath = (math.sin(loop.value * 2 * math.pi) + 1) / 2;
    for (final (i, base) in const [1.62, 1.30].indexed) {
      final swell = 1 + 0.06 * (i == 0 ? breath : 1 - breath);
      canvas.drawCircle(
        center,
        radius * base * swell * appear,
        Paint()..color = color.withAlpha(((i == 0 ? 20 : 38) * appear).round()),
      );
    }

    // A failed payment gives a short shake as the cross lands.
    final shake = kind == ResultKind.failed
        ? math.sin(_phase(0.6, 1, Curves.linear) * math.pi * 5) *
            (1 - _phase(0.6, 1, Curves.linear)) *
            size.shortestSide *
            0.03
        : 0.0;
    final badgeCenter = center.translate(shake, 0);

    // Badge pops in with a small overshoot.
    final pop = _phase(0, 0.45, Curves.easeOutBack);
    canvas.drawCircle(badgeCenter, radius * pop, Paint()..color = color);
    if (pop <= 0) return;

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final draw = _phase(0.4, 0.85, Curves.easeInOut);

    switch (kind) {
      case ResultKind.success:
        _paintTick(canvas, badgeCenter, radius, stroke, draw);
        _paintConfetti(canvas, center, radius, color);
      case ResultKind.failed:
        _paintCross(canvas, badgeCenter, radius, stroke, draw);
      case ResultKind.pending:
        _paintClock(canvas, badgeCenter, radius, stroke, draw);
      case ResultKind.refunded:
        _paintRefund(canvas, badgeCenter, radius, stroke, draw);
    }
  }

  void _paintTick(Canvas canvas, Offset c, double r, Paint stroke, double t) {
    final path = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.12, c.dy + r * 0.32)
      ..lineTo(c.dx + r * 0.44, c.dy - r * 0.28);
    _drawPartial(canvas, path, stroke, t);
  }

  void _paintCross(Canvas canvas, Offset c, double r, Paint stroke, double t) {
    final d = r * 0.34;
    // The two strokes are drawn one after the other.
    _drawPartial(
      canvas,
      Path()
        ..moveTo(c.dx - d, c.dy - d)
        ..lineTo(c.dx + d, c.dy + d),
      stroke,
      (t * 2).clamp(0.0, 1.0),
    );
    _drawPartial(
      canvas,
      Path()
        ..moveTo(c.dx + d, c.dy - d)
        ..lineTo(c.dx - d, c.dy + d),
      stroke,
      (t * 2 - 1).clamp(0.0, 1.0),
    );
  }

  void _paintClock(Canvas canvas, Offset c, double r, Paint stroke, double t) {
    final face = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.56),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      face,
    );
    if (t < 1) return;
    // Minute hand turns once per loop; the hour hand follows slowly.
    final minute = -math.pi / 2 + loop.value * 2 * math.pi;
    final hour = math.pi / 6 + loop.value * 2 * math.pi / 12;
    canvas
      ..drawLine(
        c,
        c + Offset(math.cos(minute), math.sin(minute)) * (r * 0.40),
        face,
      )
      ..drawLine(
        c,
        c + Offset(math.cos(hour), math.sin(hour)) * (r * 0.26),
        face,
      );
  }

  void _paintRefund(Canvas canvas, Offset c, double r, Paint stroke, double t) {
    // An anticlockwise arrow circling a rupee sign: money coming back.
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    final ring = r * 0.60;
    const start = -math.pi * 0.25;
    final sweep = -math.pi * 1.55 * t;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ring),
      start,
      sweep,
      false,
      arc,
    );
    if (t > 0.15) {
      // Arrowhead at the moving end of the arc, pointing along it.
      final end = start + sweep;
      final tip = c + Offset(math.cos(end), math.sin(end)) * ring;
      final direction = end - math.pi / 2;
      final head = r * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(
            tip.dx - math.cos(direction - 0.6) * head,
            tip.dy - math.sin(direction - 0.6) * head,
          )
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
            tip.dx - math.cos(direction + 0.6) * head,
            tip.dy - math.sin(direction + 0.6) * head,
          ),
        arc..strokeJoin = StrokeJoin.round,
      );
    }
    final rupee = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: r * 0.62,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Colors.white.withAlpha((255 * _phase(0.6, 0.95)).round()),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rupee.paint(canvas, c - rupee.size.center(Offset.zero));
    rupee.dispose();
  }

  /// A one-time burst of confetti flying out from behind the badge.
  void _paintConfetti(Canvas canvas, Offset c, double r, Color color) {
    final t = _phase(0.45, 1, Curves.easeOutCubic);
    if (t <= 0 || t >= 1) return;
    const colors = [
      Color(0xFFFF8A1F),
      Color(0xFFE0607B),
      Color(0xFF2F6FD6),
      Color(0xFFF2C21E),
    ];
    const count = 12;
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count + (i.isEven ? 0.18 : -0.12);
      final distance = r * (1.15 + 0.75 * t) * (i.isEven ? 1 : 0.86);
      final at = c + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = (i % 5 == 0 ? color : colors[i % colors.length])
            .withAlpha((255 * (1 - t)).round());
      if (i.isEven) {
        canvas.drawCircle(at, r * 0.07, paint);
      } else {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(angle + t * 3)
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: r * 0.18,
                height: r * 0.08,
              ),
              Radius.circular(r * 0.03),
            ),
            paint,
          )
          ..restore();
      }
    }
  }

  /// Draws the first [t] (0..1) of [path], so marks appear to be written.
  void _drawPartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_ResultPainter old) => old.kind != kind;
}
