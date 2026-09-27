import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Minimal line icon for a service or project category, drawn in vector so
/// it stays crisp at any density and can be tinted (brand color at rest,
/// white on the active chip). All glyphs share one 24×24 grid, stroke width
/// and round caps, so the row reads as a single consistent set.
class TradeIcon extends StatelessWidget {
  const TradeIcon({
    super.key,
    required this.categoryId,
    required this.color,
    this.size = 24,
  });

  final String categoryId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphs[categoryId];
    if (glyph == null) return Icon(Icons.handyman_outlined, size: size, color: color);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GlyphPainter(glyph, color)),
    );
  }
}

typedef _Glyph = Path Function();

final Map<String, _Glyph> _glyphs = {
  'gasfiteria': _faucet,
  'electricidad': _bolt,
  'carpinteria': _saw,
  'pintura': _roller,
  'cerrajeria': _key,
  'electrodomesticos': _washer,
  'jardineria': _sprout,
  'climatizacion': _snowflake,
  'piscinas': _pool,
  'pozos': _pipes,
  'tarrajeo': _trowel,
  'construccion': _helmet,
};

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      glyph(),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}

RRect _rr(double l, double t, double r, double b, double radius) =>
    RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

Path _drop(double cx, double top, double r) => Path()
  ..moveTo(cx, top)
  ..cubicTo(cx, top, cx - r, top + 2 * r * 0.9, cx - r, top + 2.6 * r)
  ..arcToPoint(Offset(cx + r, top + 2.6 * r), radius: Radius.circular(r), clockwise: false)
  ..cubicTo(cx + r, top + 2 * r * 0.9, cx, top, cx, top);

Path _faucet() => Path()
  // Handle.
  ..moveTo(8.5, 4)
  ..lineTo(14.5, 4)
  ..moveTo(11.5, 4)
  ..lineTo(11.5, 7.5)
  // Body and spout.
  ..moveTo(3, 7.5)
  ..lineTo(15, 7.5)
  ..quadraticBezierTo(19, 7.5, 19, 11.5)
  ..lineTo(19, 13.5)
  ..lineTo(15, 13.5)
  ..lineTo(15, 12.5)
  ..quadraticBezierTo(15, 11.5, 14, 11.5)
  ..lineTo(3, 11.5)
  ..close()
  ..addPath(_drop(17, 16.5, 1.6), Offset.zero);

Path _bolt() => Path()
  ..moveTo(13, 2.5)
  ..lineTo(4.5, 13.5)
  ..lineTo(11.5, 13.5)
  ..lineTo(10.5, 21.5)
  ..lineTo(19.5, 10.5)
  ..lineTo(12.5, 10.5)
  ..close();

Path _saw() {
  final saw = Path()
    // Handle with grip hole.
    ..addRRect(_rr(1.5, 7.5, 7.5, 15.5, 2))
    ..addRRect(_rr(3.2, 9.5, 5.8, 12.2, 1))
    // Blade, toothed along the bottom edge.
    ..moveTo(7.5, 9)
    ..lineTo(22, 10.5)
    ..lineTo(22, 13);
  const teeth = 6;
  for (var i = 1; i <= teeth; i++) {
    final x = 22 - (22 - 7.5) * i / teeth;
    final y = 13 + 1.2 * i / teeth;
    saw
      ..lineTo(x + (22 - 7.5) / teeth / 2, y + 1.3)
      ..lineTo(x, y);
  }
  final rotation = Matrix4.identity()
    ..translateByDouble(12, 12, 0, 1)
    ..rotateZ(-math.pi / 5)
    ..translateByDouble(-12, -12, 0, 1);
  return saw.transform(rotation.storage);
}

Path _roller() => Path()
  ..addRRect(_rr(3, 3, 17, 8.5, 2))
  ..moveTo(17, 5.75)
  ..lineTo(20, 5.75)
  ..lineTo(20, 11.5)
  ..lineTo(12, 11.5)
  ..lineTo(12, 14)
  ..addRRect(_rr(10.25, 14, 13.75, 21.5, 1.5));

Path _key() => Path()
  ..addOval(Rect.fromCircle(center: const Offset(7.5, 16.5), radius: 4.5))
  ..moveTo(10.7, 13.3)
  ..lineTo(21, 3)
  ..moveTo(15.5, 8.5)
  ..lineTo(18, 11)
  ..moveTo(18.5, 5.5)
  ..lineTo(20.5, 7.5);

Path _washer() => Path()
  ..addRRect(_rr(4, 2.5, 20, 21.5, 2.5))
  ..moveTo(4, 6.5)
  ..lineTo(20, 6.5)
  ..moveTo(7, 4.5)
  ..lineTo(7.01, 4.5)
  ..moveTo(9.5, 4.5)
  ..lineTo(9.51, 4.5)
  ..addOval(Rect.fromCircle(center: const Offset(12, 14), radius: 4.5))
  // Water line inside the drum.
  ..moveTo(8, 15)
  ..quadraticBezierTo(10, 13.5, 12, 15)
  ..quadraticBezierTo(14, 16.5, 16, 15);

Path _sprout() => Path()
  ..moveTo(12, 20.5)
  ..lineTo(12, 10.5)
  // Left leaf.
  ..moveTo(12, 14)
  ..cubicTo(12, 10.5, 9.5, 8.5, 5, 8.5)
  ..cubicTo(5, 12, 7.5, 14, 12, 14)
  // Right leaf.
  ..moveTo(12, 10.5)
  ..cubicTo(12, 6.5, 14.5, 4, 19.5, 4)
  ..cubicTo(19.5, 8, 16.5, 10.5, 12, 10.5)
  // Ground.
  ..moveTo(6.5, 20.5)
  ..lineTo(17.5, 20.5);

Path _snowflake() {
  final flake = Path();
  const c = Offset(12, 12);
  for (var i = 0; i < 6; i++) {
    final a = -math.pi / 2 + i * math.pi / 3;
    Offset at(double r, [double da = 0]) =>
        c + Offset(math.cos(a + da), math.sin(a + da)) * r;
    final branch = at(6.2);
    flake
      ..moveTo(c.dx, c.dy)
      ..relativeLineTo(at(9.5).dx - c.dx, at(9.5).dy - c.dy)
      ..moveTo(branch.dx, branch.dy)
      ..lineTo(branch.dx + 2.6 * math.cos(a - 0.9), branch.dy + 2.6 * math.sin(a - 0.9))
      ..moveTo(branch.dx, branch.dy)
      ..lineTo(branch.dx + 2.6 * math.cos(a + 0.9), branch.dy + 2.6 * math.sin(a + 0.9));
  }
  return flake;
}

Path _wave(double y) {
  final wave = Path()..moveTo(2.5, y);
  for (var x = 2.5; x < 21.5; x += 4.75) {
    wave.quadraticBezierTo(x + 1.19, y - 1.3, x + 2.38, y);
    wave.quadraticBezierTo(x + 3.56, y + 1.3, x + 4.75, y);
  }
  return wave;
}

Path _pool() => Path()
  // Ladder rails bending over the pool edge.
  ..moveTo(8, 15)
  ..lineTo(8, 5.5)
  ..quadraticBezierTo(8, 3, 10.5, 3)
  ..moveTo(15, 15)
  ..lineTo(15, 5.5)
  ..quadraticBezierTo(15, 3, 17.5, 3)
  ..moveTo(8, 8)
  ..lineTo(15, 8)
  ..moveTo(8, 11.5)
  ..lineTo(15, 11.5)
  ..addPath(_wave(17), Offset.zero)
  ..addPath(_wave(21), Offset.zero);

Path _pipes() => Path()
  // Elbow fitting: horizontal run turning down.
  ..moveTo(2.5, 6)
  ..lineTo(12.5, 6)
  ..quadraticBezierTo(18, 6, 18, 11.5)
  ..lineTo(18, 21.5)
  ..moveTo(2.5, 12)
  ..lineTo(11, 12)
  ..quadraticBezierTo(12, 12, 12, 13)
  ..lineTo(12, 21.5)
  // Collars.
  ..moveTo(6.5, 4.5)
  ..lineTo(6.5, 13.5)
  ..moveTo(10.5, 17.5)
  ..lineTo(19.5, 17.5);

Path _trowel() => Path()
  ..addRRect(_rr(2.5, 14, 21.5, 19, 1.5))
  ..moveTo(12, 14)
  ..lineTo(12, 10)
  ..addRRect(_rr(6.5, 5.5, 17.5, 10, 2.25));

Path _helmet() => Path()
  ..addRRect(_rr(2.5, 17, 21.5, 20, 1.5))
  ..moveTo(4.5, 17)
  ..cubicTo(4.5, 11, 7.5, 7.5, 12, 7.5)
  ..cubicTo(16.5, 7.5, 19.5, 11, 19.5, 17)
  ..moveTo(10, 12.5)
  ..lineTo(10, 5.5)
  ..lineTo(14, 5.5)
  ..lineTo(14, 12.5);
