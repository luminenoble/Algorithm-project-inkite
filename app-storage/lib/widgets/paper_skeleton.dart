import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/skin_controller.dart';

/// 骨架纸卡（`docs/fronted-design.md` §2.3）。
///
/// 列表首屏加载用 3–4 个呼吸纸卡替代整屏转圈，减少「突然弹出」。
class PaperSkeleton extends StatefulWidget {
  const PaperSkeleton({
    super.key,
    this.height = 84,
    this.width,
    this.radius = DesignTokens.radiusCard,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<PaperSkeleton> createState() => _PaperSkeletonState();
}

class _PaperSkeletonState extends State<PaperSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shade = context.skin.paperShade;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final opacity = 0.4 + _controller.value * 0.45;
        return Opacity(
          opacity: opacity,
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: shade,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// 列表骨架：若干呼吸纸卡竖排（非滚动，置于列表区顶部）。
class PaperSkeletonList extends StatelessWidget {
  const PaperSkeletonList({
    super.key,
    this.count = 4,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final int count;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            PaperSkeleton(height: itemHeight),
            if (i != count - 1) const SizedBox(height: DesignTokens.listGap),
          ],
        ],
      ),
    );
  }
}
