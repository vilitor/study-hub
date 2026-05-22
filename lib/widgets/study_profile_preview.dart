import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class StudyProfilePreview extends StatefulWidget {
  final String profileId;

  const StudyProfilePreview({super.key, required this.profileId});

  @override
  State<StudyProfilePreview> createState() => _StudyProfilePreviewState();
}

class _StudyProfilePreviewState extends State<StudyProfilePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _controller.repeat(reverse: true);
    });
  }

  @override
  void didUpdateWidget(covariant StudyProfilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.spacing.cardRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.accent.withValues(alpha: 0.05),
            colors.surfaceElevated,
          ),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: SizedBox(
          height: 152,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ProfilePreviewPainter(
                  profileId: widget.profileId,
                  progress: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : _controller.value,
                  colors: colors,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfilePreviewPainter extends CustomPainter {
  final String profileId;
  final double progress;
  final AppColorTokens colors;

  _ProfilePreviewPainter({
    required this.profileId,
    required this.progress,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = colors.accent.withValues(alpha: 0.44);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.accentSecondary.withValues(alpha: 0.12);
    final dx = math.sin(progress * math.pi) * 8;

    switch (profileId) {
      case 'medicine':
        _medical(canvas, size, paint, fill, dx);
        break;
      case 'psychology':
        _mind(canvas, size, paint, fill, dx);
        break;
      case 'engineering':
      case 'architecture':
        _technical(canvas, size, paint, fill, dx);
        break;
      case 'law':
        _law(canvas, size, paint, fill, dx);
        break;
      case 'business':
        _business(canvas, size, paint, fill, dx);
        break;
      case 'history':
      case 'geography':
        _mapTimeline(canvas, size, paint, fill, dx);
        break;
      case 'other':
        _custom(canvas, size, paint, fill, dx);
        break;
      default:
        _code(canvas, size, paint, fill, dx);
    }
  }

  void _code(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    for (var i = 0; i < 5; i++) {
      final y = 34.0 + i * 20;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(32 + (i.isEven ? dx : -dx), y, 92 + i * 18, 8),
          const Radius.circular(8),
        ),
        paint,
      );
    }
    canvas.drawCircle(Offset(size.width - 54, 48), 24, fill);
    canvas.drawLine(
      Offset(size.width - 70, 48),
      Offset(size.width - 38, 48),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 54, 32),
      Offset(size.width - 54, 64),
      paint,
    );
  }

  void _medical(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    final center = Offset(size.width / 2 + dx, size.height / 2);
    canvas.drawCircle(center, 42, fill);
    canvas.drawLine(center.translate(-28, 0), center.translate(28, 0), paint);
    canvas.drawLine(center.translate(0, -28), center.translate(0, 28), paint);
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 96, height: 96),
      -0.7,
      1.4,
      false,
      paint,
    );
  }

  void _mind(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 46, fill);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        center.translate(math.cos(i) * (22 + dx / 4), math.sin(i) * 24),
        14,
        paint,
      );
    }
    canvas.drawLine(
      center.translate(-38, 18),
      center.translate(38, -18),
      paint,
    );
  }

  void _technical(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint fill,
    double dx,
  ) {
    final rect = Rect.fromLTWH(36 + dx, 34, size.width - 72, 84);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      fill,
    );
    for (var i = 0; i < 4; i++) {
      final x = rect.left + 28 + i * 46;
      canvas.drawLine(Offset(x, rect.top), Offset(x + 34, rect.bottom), paint);
    }
    canvas.drawRect(rect.deflate(18), paint);
  }

  void _law(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    final base = Offset(size.width / 2 + dx, 42);
    canvas.drawCircle(base, 12, fill);
    canvas.drawLine(base, base.translate(0, 74), paint);
    canvas.drawLine(base.translate(-54, 22), base.translate(54, 22), paint);
    canvas.drawArc(
      Rect.fromCenter(center: base.translate(-42, 46), width: 42, height: 34),
      0,
      math.pi,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: base.translate(42, 46), width: 42, height: 34),
      0,
      math.pi,
      false,
      paint,
    );
  }

  void _business(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    final bottom = size.height - 34;
    for (var i = 0; i < 5; i++) {
      final height = 28.0 + i * 14 + dx / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(42 + i * 42, bottom - height, 22, height),
          const Radius.circular(8),
        ),
        i == 2 ? fill : paint,
      );
    }
    canvas.drawLine(Offset(36, bottom), Offset(size.width - 36, bottom), paint);
  }

  void _mapTimeline(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint fill,
    double dx,
  ) {
    final y = size.height / 2;
    canvas.drawLine(Offset(32, y), Offset(size.width - 32, y), paint);
    for (var i = 0; i < 4; i++) {
      final x = 48.0 + i * ((size.width - 96) / 3);
      canvas.drawCircle(Offset(x, y + (i.isEven ? dx / 2 : -dx / 2)), 12, fill);
      canvas.drawCircle(
        Offset(x, y + (i.isEven ? dx / 2 : -dx / 2)),
        12,
        paint,
      );
    }
  }

  void _custom(Canvas canvas, Size size, Paint paint, Paint fill, double dx) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate((i - 1) * 48 + dx / 3, (i - 1) * 12),
            width: 70,
            height: 46,
          ),
          const Radius.circular(16),
        ),
        i == 1 ? fill : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilePreviewPainter oldDelegate) {
    return oldDelegate.profileId != profileId ||
        oldDelegate.progress != progress ||
        oldDelegate.colors != colors;
  }
}
