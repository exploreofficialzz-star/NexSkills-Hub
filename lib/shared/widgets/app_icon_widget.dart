import 'package:flutter/material.dart';

/// NexSkills Hub app icon — rendered as a Flutter widget.
///
/// Design matches the launcher icon exactly:
///   • Blue rounded rectangle background  (#6C63FF — NexColors.primary)
///   • White circle ring  (stroke only, transparent interior — blue shows through)
///   • White bold N letter centred inside the ring
///
/// Use this widget anywhere the app icon should appear:
///   About dialog, onboarding, splash overlay, etc.
class AppIconWidget extends StatelessWidget {
  final double size;
  const AppIconWidget({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF), // exact blue from icon
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: CustomPaint(
        painter: _IconPainter(size: size),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  final double size;
  const _IconPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── White circle ring (transparent inside, white stroke) ──────
    final ringRadius = w * 0.38;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), ringRadius, ringPaint);

    // ── White bold N letter ───────────────────────────────────────
    // Coordinate system: 108×108 viewport, N fits within 28–80 x 30–74
    final sx = w / 108;
    final sy = h / 108;
    final nPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(28 * sx, 30 * sy); // top-left outer
    path.lineTo(40 * sx, 30 * sy); // top inner-left
    path.lineTo(68 * sx, 74 * sy); // bottom of front diagonal
    path.lineTo(80 * sx, 74 * sy); // bottom-right outer
    path.lineTo(80 * sx, 30 * sy); // top-right outer
    path.lineTo(68 * sx, 30 * sy); // top inner-right
    path.lineTo(40 * sx, 74 * sy); // bottom of back diagonal
    path.lineTo(28 * sx, 74 * sy); // bottom-left outer
    path.close();

    canvas.drawPath(path, nPaint);
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.size != size;
}
