import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/motion.dart';
import '../theme/skin_controller.dart';

/// 翻书折叠方向（`docs/fronted-design.md` §3.1）。
enum FoldDirection { forward, backward }

/// 全局当前翻页方向：Tab 间切换由 [MainShell] 按索引差设定；子页进入恒 forward。
/// 转场在页面创建时读取，故用一个轻量全局值传递（无 context 可用）。
final ValueNotifier<FoldDirection> foldDirection =
    ValueNotifier<FoldDirection>(FoldDirection.forward);

/// 为一条路由套上翻书折叠转场（§3）。
///
/// - [full] 动效：`Matrix4` 透视 + `rotateY` 模拟书页翻折，叠折痕受光。
/// - [reduced]：退标准 [FadeTransition]。
/// - [off]：时长归零，瞬切。
CustomTransitionPage<void> foldPage(
  GoRouterState state,
  Widget child, {
  FoldDirection? direction,
}) {
  final motion = SkinController.instance.motion;
  final dir = direction ?? foldDirection.value;
  final dur = switch (motion) {
    MotionLevel.off => Duration.zero,
    MotionLevel.reduced => const Duration(milliseconds: 220),
    // 单段 durFold 420ms + 错峰 ≈ 600ms（§3.1）
    MotionLevel.full => const Duration(milliseconds: 600),
  };
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: dur,
    reverseTransitionDuration: dur,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (!context.motion.useRichMotion) {
        return FadeTransition(opacity: animation, child: child);
      }
      return _FoldTransition(
        animation: animation,
        direction: dir,
        child: child,
      );
    },
  );
}

class _FoldTransition extends StatelessWidget {
  const _FoldTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final FoldDirection direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.curveFold,
      reverseCurve: Motion.curveFold.flipped,
    );
    // forward：绕左缘从背面翻正进场；backward：绕右缘。
    final forward = direction == FoldDirection.forward;
    final alignment = forward ? Alignment.centerLeft : Alignment.centerRight;
    final sign = forward ? 1.0 : -1.0;
    final lightEnd = forward ? Alignment.centerRight : Alignment.centerLeft;

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final v = curved.value.clamp(0.0, 1.0);
        final angle = (1 - v) * (math.pi / 2) * sign;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // 轻微透视（§3.1）
          ..rotateY(angle);
        return Opacity(
          opacity: v,
          child: Transform(
            alignment: alignment,
            transform: transform,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                // 折痕受光：折叠中从亮面扫到暗面（§3.1），随翻正淡出。
                if (v < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1 - v) * 0.4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: alignment,
                              end: lightEnd,
                              colors: [skin.foldLightTint, skin.paperShade],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
