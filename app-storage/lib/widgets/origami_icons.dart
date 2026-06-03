import 'package:flutter/material.dart';

/// 折纸造型图标语义（`docs/fronted-design.md` §2.2）。
enum OrigamiGlyph {
  /// 纸鸟（文章 / 发布 / 展览厅）
  bird,

  /// 折纸箱（文件夹）
  box,

  /// 折纸笔（写作模式）
  pen,

  /// 放大镜（校阅模式）
  lens,

  /// 折纸心（点赞）
  heart,

  /// 空态留白纸
  emptyPaper,

  /// 解锁锁形
  lock,

  /// 印章 / 折角印记（已发布 / 「我的」身份）
  seal,
}

/// 折纸造型矢量绘制器 —— 设计 §2.1/§2.3 约定的「Lottie 缺失 → 退静态图标」
/// 恒在兜底路径。以单位坐标（0–1）绘制后按 [Size] 缩放。
class OrigamiGlyphPainter extends CustomPainter {
  OrigamiGlyphPainter({
    required this.glyph,
    required this.color,
    this.accent,
    this.fill = false,
    this.progress = 0.0,
    this.strokeWidth = 2.0,
  });

  final OrigamiGlyph glyph;
  final Color color;

  /// 点缀色（纸鸟眼 / 笔尖墨 / 锁芯 / 印记），缺省取 [color]。
  final Color? accent;

  /// 是否填充（点赞红心 / 选中态图标）。
  final bool fill;

  /// 动作进度：纸鸟 = 振翅幅度；折纸箱 = 开合（0 合 / 1 开）。
  final double progress;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    final solid = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final facet = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.12);
    final accentPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent ?? color;

    switch (glyph) {
      case OrigamiGlyph.bird:
        _bird(canvas, p, stroke, solid, accentPaint);
      case OrigamiGlyph.box:
        _box(canvas, p, stroke, facet);
      case OrigamiGlyph.pen:
        _pen(canvas, p, stroke, facet, accentPaint);
      case OrigamiGlyph.lens:
        _lens(canvas, p, stroke);
      case OrigamiGlyph.heart:
        _heart(canvas, p, stroke, solid);
      case OrigamiGlyph.emptyPaper:
        _emptyPaper(canvas, p, stroke);
      case OrigamiGlyph.lock:
        _lock(canvas, p, stroke, accentPaint);
      case OrigamiGlyph.seal:
        _seal(canvas, p, stroke);
    }
  }

  // 海鸥剪影：翼尖随 [progress] 升降模拟振翅。
  void _bird(Canvas c, Offset Function(double, double) p, Paint stroke,
      Paint solid, Paint accentPaint) {
    final lift = 0.32 + (1 - progress) * 0.10; // progress 0→翼平，1→翼扬
    final path = Path()
      ..moveTo(p(0.06, lift).dx, p(0.06, lift).dy)
      ..quadraticBezierTo(
          p(0.30, 0.40).dx, p(0.30, 0.40).dy, p(0.50, 0.55).dx, p(0.50, 0.55).dy)
      ..quadraticBezierTo(
          p(0.70, 0.40).dx, p(0.70, 0.40).dy, p(0.94, lift).dx, p(0.94, lift).dy)
      ..quadraticBezierTo(
          p(0.74, 0.50).dx, p(0.74, 0.50).dy, p(0.56, 0.62).dx, p(0.56, 0.62).dy)
      ..quadraticBezierTo(
          p(0.50, 0.66).dx, p(0.50, 0.66).dy, p(0.44, 0.62).dx, p(0.44, 0.62).dy)
      ..quadraticBezierTo(
          p(0.26, 0.50).dx, p(0.26, 0.50).dy, p(0.06, lift).dx, p(0.06, lift).dy)
      ..close();
    if (fill) {
      c.drawPath(path, solid);
    } else {
      c.drawPath(path, Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.14));
      c.drawPath(path, stroke);
    }
    // 中线折痕
    c.drawLine(p(0.50, 0.55), p(0.50, 0.64), stroke);
  }

  // 折纸箱：箱体 + 可开合的盖。
  void _box(Canvas c, Offset Function(double, double) p, Paint stroke,
      Paint facet) {
    final body = Path()
      ..moveTo(p(0.22, 0.46).dx, p(0.22, 0.46).dy)
      ..lineTo(p(0.78, 0.46).dx, p(0.78, 0.46).dy)
      ..lineTo(p(0.72, 0.84).dx, p(0.72, 0.84).dy)
      ..lineTo(p(0.28, 0.84).dx, p(0.28, 0.84).dy)
      ..close();
    c.drawPath(body, facet);
    c.drawPath(body, stroke);
    // 盖：盖尖 y 随 progress 从 0.60（合）抬到 0.20（开）
    final apexY = 0.60 - progress * 0.40;
    final lid = Path()
      ..moveTo(p(0.20, 0.46).dx, p(0.20, 0.46).dy)
      ..lineTo(p(0.80, 0.46).dx, p(0.80, 0.46).dy)
      ..lineTo(p(0.50, apexY).dx, p(0.50, apexY).dy)
      ..close();
    c.drawPath(lid, facet);
    c.drawPath(lid, stroke);
  }

  // 折纸笔：笔杆斜置 + 笔尖。
  void _pen(Canvas c, Offset Function(double, double) p, Paint stroke,
      Paint facet, Paint accentPaint) {
    final barrel = Path()
      ..moveTo(p(0.26, 0.72).dx, p(0.26, 0.72).dy)
      ..lineTo(p(0.72, 0.20).dx, p(0.72, 0.20).dy)
      ..lineTo(p(0.82, 0.28).dx, p(0.82, 0.28).dy)
      ..lineTo(p(0.36, 0.80).dx, p(0.36, 0.80).dy)
      ..close();
    c.drawPath(barrel, facet);
    c.drawPath(barrel, stroke);
    // 笔尖三角
    final nib = Path()
      ..moveTo(p(0.16, 0.86).dx, p(0.16, 0.86).dy)
      ..lineTo(p(0.26, 0.72).dx, p(0.26, 0.72).dy)
      ..lineTo(p(0.36, 0.80).dx, p(0.36, 0.80).dy)
      ..close();
    c.drawPath(nib, accentPaint);
    c.drawPath(nib, stroke);
  }

  // 放大镜：镜片圈 + 手柄。
  void _lens(Canvas c, Offset Function(double, double) p, Paint stroke) {
    final s = (p(1, 0).dx); // 单位长度
    c.drawCircle(p(0.42, 0.42), 0.24 * s, stroke);
    c.drawLine(p(0.60, 0.60), p(0.84, 0.84),
        stroke..strokeWidth = strokeWidth * 1.4);
  }

  // 折纸心。
  void _heart(Canvas c, Offset Function(double, double) p, Paint stroke,
      Paint solid) {
    final path = Path()
      ..moveTo(p(0.50, 0.78).dx, p(0.50, 0.78).dy)
      ..cubicTo(p(0.10, 0.50).dx, p(0.10, 0.50).dy, p(0.18, 0.18).dx,
          p(0.18, 0.18).dy, p(0.50, 0.36).dx, p(0.50, 0.36).dy)
      ..cubicTo(p(0.82, 0.18).dx, p(0.82, 0.18).dy, p(0.90, 0.50).dx,
          p(0.90, 0.50).dy, p(0.50, 0.78).dx, p(0.50, 0.78).dy)
      ..close();
    if (fill) {
      c.drawPath(path, solid);
    } else {
      c.drawPath(path, stroke);
    }
  }

  // 空态：一张带折角的纸。
  void _emptyPaper(Canvas c, Offset Function(double, double) p, Paint stroke) {
    final sheet = Path()
      ..moveTo(p(0.26, 0.20).dx, p(0.26, 0.20).dy)
      ..lineTo(p(0.64, 0.20).dx, p(0.64, 0.20).dy)
      ..lineTo(p(0.76, 0.32).dx, p(0.76, 0.32).dy)
      ..lineTo(p(0.76, 0.80).dx, p(0.76, 0.80).dy)
      ..lineTo(p(0.26, 0.80).dx, p(0.26, 0.80).dy)
      ..close();
    c.drawPath(sheet, stroke);
    // 折角
    final ear = Path()
      ..moveTo(p(0.64, 0.20).dx, p(0.64, 0.20).dy)
      ..lineTo(p(0.64, 0.32).dx, p(0.64, 0.32).dy)
      ..lineTo(p(0.76, 0.32).dx, p(0.76, 0.32).dy);
    c.drawPath(ear, stroke);
  }

  // 锁形。
  void _lock(Canvas c, Offset Function(double, double) p, Paint stroke,
      Paint accentPaint) {
    final s = (p(1, 0).dx);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(p(0.30, 0.48).dx, p(0.30, 0.48).dy, p(0.70, 0.82).dx,
          p(0.70, 0.82).dy),
      Radius.circular(0.04 * s),
    );
    c.drawRRect(body, stroke);
    // 锁梁半圆
    final shackle = Rect.fromLTRB(
        p(0.36, 0.34).dx, p(0.34, 0.34).dy, p(0.64, 0.62).dx, p(0.62, 0.62).dy);
    c.drawArc(shackle, 3.14159, 3.14159, false, stroke);
    // 锁芯
    c.drawCircle(p(0.50, 0.63), 0.035 * s, accentPaint);
  }

  // 印章 / 折角印记。
  void _seal(Canvas c, Offset Function(double, double) p, Paint stroke) {
    final s = (p(1, 0).dx);
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTRB(p(0.26, 0.26).dx, p(0.26, 0.26).dy, p(0.74, 0.74).dx,
          p(0.74, 0.74).dy),
      Radius.circular(0.06 * s),
    );
    c.drawRRect(outer, stroke);
    if (fill) {
      c.drawRRect(outer, Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.14));
    }
    c.drawLine(p(0.40, 0.40), p(0.60, 0.60), stroke);
    c.drawLine(p(0.60, 0.40), p(0.40, 0.60), stroke);
  }

  @override
  bool shouldRepaint(covariant OrigamiGlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.accent != accent ||
      old.fill != fill ||
      old.progress != progress ||
      old.strokeWidth != strokeWidth;
}
