import 'package:flutter/material.dart';

import 'origami_icons.dart';

/// 折纸造型图标（`docs/fronted-design.md` §2.2）。
///
/// 当前用 [OrigamiGlyphPainter] 绘制矢量折纸造型，作为设计 §2.1/§2.3 约定的
/// 「Lottie 缺失 → 退静态图标」恒在兜底路径——永不破坏构建、永不空白。
///
/// **Lottie 接入 seam**：日后接 `lottie` 包时，在本 widget 内优先尝试
/// `Lottie.asset('assets/lottie/<glyph>_<state>.json')`，解码失败再回落到本
/// painter；[OrigamiIcon] 的调用方 API 保持不变。
class OrigamiIcon extends StatefulWidget {
  const OrigamiIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.accent,
    this.fill = false,
    this.progress = 0.0,
    this.animate = false,
  });

  final OrigamiGlyph glyph;
  final double size;

  /// 主色，缺省取 [IconTheme] 当前色。
  final Color? color;
  final Color? accent;

  /// 是否填充（点赞红心 / 选中态图标）。
  final bool fill;

  /// 静态动作进度（折纸箱开合等）。`animate` 开启时纸鸟忽略此值改用振翅。
  final double progress;

  /// 是否播放 idle 动效（纸鸟轻振翅）。
  final bool animate;

  @override
  State<OrigamiIcon> createState() => _OrigamiIconState();
}

class _OrigamiIconState extends State<OrigamiIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  void _start() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(OrigamiIcon old) {
    super.didUpdateWidget(old);
    if (widget.animate && _controller == null) {
      _start();
    } else if (!widget.animate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double _progress() {
    if (_controller != null && widget.glyph == OrigamiGlyph.bird) {
      return _controller!.value;
    }
    return widget.progress;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final strokeWidth = (widget.size / 24 * 2).clamp(1.4, 3.0);

    OrigamiGlyphPainter painter() => OrigamiGlyphPainter(
          glyph: widget.glyph,
          color: color,
          accent: widget.accent,
          fill: widget.fill,
          progress: _progress(),
          strokeWidth: strokeWidth,
        );

    final size = Size.square(widget.size);
    final paint = _controller == null
        ? CustomPaint(size: size, painter: painter())
        : AnimatedBuilder(
            animation: _controller!,
            builder: (_, _) => CustomPaint(size: size, painter: painter()),
          );

    return SizedBox.square(dimension: widget.size, child: paint);
  }
}
