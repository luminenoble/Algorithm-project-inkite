import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/skin_controller.dart';

/// 毛笔运笔加载动效（`docs/fronted-design.md` §2.3）。
///
/// 替代默认 [CircularProgressIndicator]：一支「毛笔」沿环来回运笔，笔锋由粗到
/// 细拖出墨迹。超过约 8s 显示一行「正在铺纸……」避免无限静默。
class BrushLoading extends StatefulWidget {
  const BrushLoading({
    super.key,
    this.size = 48,
    this.color,
    this.message,
    this.showSlowHint = true,
  });

  final double size;

  /// 笔色，缺省取当前皮肤朱砂点缀。
  final Color? color;

  /// 固定显示的文案（提供则不等 8s）。
  final String? message;

  /// 是否在超 8s 时显示「正在铺纸……」。
  final bool showSlowHint;

  /// 居中包裹，便于 `StreamBuilder` / `FutureBuilder` 的 waiting 态直接返回。
  static Widget centered({double size = 48, String? message}) =>
      Center(child: BrushLoading(size: size, message: message));

  @override
  State<BrushLoading> createState() => _BrushLoadingState();
}

class _BrushLoadingState extends State<BrushLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    if (widget.showSlowHint && widget.message == null) {
      _slowTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _slow = true);
      });
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.skin.accentVermilion;
    final hint = widget.message ?? (_slow ? '正在铺纸……' : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _BrushPainter(t: _controller.value, color: color),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 12),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: context.skin.inkSecondary),
          ),
        ],
      ],
    );
  }
}

class _BrushPainter extends CustomPainter {
  _BrushPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;
    final head = t * 2 * math.pi;
    const n = 26;
    const span = 5.0; // 弧长（弧度，约 286°）
    const step = span / n;
    final maxW = size.shortestSide * 0.10;

    for (var i = 0; i < n; i++) {
      final f = i / n;
      final a0 = head - i * step;
      final a1 = head - (i + 1) * step;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 1 - f)
        ..strokeWidth = maxW * (1 - f) + 1.0;
      canvas.drawLine(
        center + Offset(math.cos(a0), math.sin(a0)) * r,
        center + Offset(math.cos(a1), math.sin(a1)) * r,
        paint,
      );
    }
    // 笔锋
    canvas.drawCircle(
      center + Offset(math.cos(head), math.sin(head)) * r,
      maxW * 0.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushPainter old) =>
      old.t != t || old.color != color;
}
