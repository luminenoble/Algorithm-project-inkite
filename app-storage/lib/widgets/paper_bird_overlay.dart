import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/skin_controller.dart';
import 'origami_icon.dart';
import 'origami_icons.dart';

/// 纸鸟飞行 + 纸张合拢的 Overlay 动效（`docs/fronted-design.md` §4 / §6）。
///
/// 均为「不挡操作」的 Overlay 飞行物：`IgnorePointer` + 动画结束即移除（§7.3）。
/// 动效级别非 [MotionLevel.full] 时整体跳过（仅保留调用方的文本/SnackBar 反馈）。

/// 放飞一只折纸鸟，沿贝塞尔弧线从 [from] 飞到 [to]（缺省屏幕中心 → 右上）。
///
/// 用于：进展览厅纸鸟飞过（§4）、发布到广场纸鸟飞出（§6.2）。
void launchPaperBird(
  BuildContext context, {
  Offset? from,
  Offset? to,
  Color? color,
  double sizePx = 44,
}) {
  if (!context.motion.useRichMotion) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final media = MediaQuery.of(context);
  final size = media.size;
  final start = from ?? Offset(size.width * 0.5, size.height * 0.55);
  final end = to ?? Offset(size.width - 48, media.padding.top + 56);
  final birdColor = color ?? context.skin.inkPrimary;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingBird(
      from: start,
      to: end,
      color: birdColor,
      sizePx: sizePx,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

/// 纸张合拢 + 印记动效（§6.1 保存 / §6.2 发布前置）。中心浮一枚折角印记，
/// 沿水平中线折拢、定格、再淡出。
void playPaperFold(
  BuildContext context, {
  required String label,
  Color? sealColor,
}) {
  if (!context.motion.useRichMotion) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final skin = context.skin;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PaperFold(
      label: label,
      sealColor: sealColor ?? skin.accentSeal,
      paper: skin.paperHighlight,
      shade: skin.paperShade,
      ink: skin.inkPrimary,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _FlyingBird extends StatefulWidget {
  const _FlyingBird({
    required this.from,
    required this.to,
    required this.color,
    required this.sizePx,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double sizePx;
  final VoidCallback onDone;

  @override
  State<_FlyingBird> createState() => _FlyingBirdState();
}

class _FlyingBirdState extends State<_FlyingBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Offset _control;

  @override
  void initState() {
    super.initState();
    // 控制点：起讫中点抬高，形成上凸的滑翔弧线。
    final mid = Offset(
      (widget.from.dx + widget.to.dx) / 2,
      (widget.from.dy + widget.to.dy) / 2,
    );
    final dist = (widget.to - widget.from).distance;
    _control = mid + Offset(0, -dist * 0.28);
    _c = AnimationController(vsync: this, duration: Motion.durBirdFly)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _bezier(double t) {
    final u = 1 - t;
    return widget.from * (u * u) +
        _control * (2 * u * t) +
        widget.to * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Motion.curveFly.transform(_c.value);
          final pos = _bezier(t);
          // 切线方向 → 机头朝向。
          final tan = _bezier((t + 0.01).clamp(0.0, 1.0)) - _bezier(t);
          final angle = math.atan2(tan.dy, tan.dx);
          final scale = 0.9 - 0.5 * t;
          final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
          return Stack(
            children: [
              Positioned(
                left: pos.dx - widget.sizePx / 2,
                top: pos.dy - widget.sizePx / 2,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: scale,
                      child: OrigamiIcon(
                        OrigamiGlyph.bird,
                        size: widget.sizePx,
                        fill: true,
                        color: widget.color,
                        animate: true,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaperFold extends StatefulWidget {
  const _PaperFold({
    required this.label,
    required this.sealColor,
    required this.paper,
    required this.shade,
    required this.ink,
    required this.onDone,
  });

  final String label;
  final Color sealColor;
  final Color paper;
  final Color shade;
  final Color ink;
  final VoidCallback onDone;

  @override
  State<_PaperFold> createState() => _PaperFoldState();
}

class _PaperFoldState extends State<_PaperFold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            // 三段：合拢(0-0.35) → 定格(0.35-0.75) → 淡出(0.75-1)。
            final double foldT = (v / 0.35).clamp(0.0, 1.0);
            final scaleY = 1.0 - Motion.curveFold.transform(foldT) * 0.86;
            final double opacity =
                v < 0.75 ? 1.0 : (1 - (v - 0.75) / 0.25).clamp(0.0, 1.0);
            final showSeal = v >= 0.32;
            return Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(1.0, scaleY, 1.0),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: widget.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.shade),
                    boxShadow: [
                      BoxShadow(
                        color: widget.shade.withValues(alpha: 0.8),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: showSeal ? 1 : 0,
                        child: OrigamiIcon(
                          OrigamiGlyph.seal,
                          size: 22,
                          fill: true,
                          color: widget.sealColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
