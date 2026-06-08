import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/fold_transition.dart';
import '../../theme/motion.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';

/// 底部 Tab 主框架。包裹 5 个核心 Tab 的导航。
///
/// 折纸底栏（`docs/fronted-design.md` §3.2 / §11）：纸面色调 + 折纸造型图标，
/// 选中态朱砂高亮 + 微缩放点按反馈；切 Tab 按索引差设定翻书折叠方向。
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  // 语义递进「创作→社区→探索→收藏→我的」；放大镜 lens 贴合「开拓」检索语义。
  static const _tabs = <_TabSpec>[
    _TabSpec('/writing', '写作', OrigamiGlyph.pen),
    _TabSpec('/square', '广场', OrigamiGlyph.bird),
    _TabSpec('/explore', '开拓', OrigamiGlyph.lens),
    _TabSpec('/gallery', '展览厅', OrigamiGlyph.box),
    _TabSpec('/me', '我的', OrigamiGlyph.seal),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int target, int current) {
    if (target == current) return;
    // 目标索引大 → 向左翻进（forward）；小 → 向右翻退（backward）（§3.2）。
    foldDirection.value =
        target > current ? FoldDirection.forward : FoldDirection.backward;
    context.go(_tabs[target].path);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);
    final skin = context.skin;

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: skin.paperHighlight,
          border: Border(top: BorderSide(color: skin.inkFaint)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[i],
                      selected: i == index,
                      onTap: () => _onTap(context, i, index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final color = selected ? skin.accentVermilion : skin.inkSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.92,
            duration: Motion.durInstant,
            curve: Motion.curveFold,
            child: OrigamiIcon(
              spec.glyph,
              size: 26,
              color: color,
              fill: selected,
              // 广场 Tab 纸鸟选中时轻振翅。
              animate: selected && spec.glyph == OrigamiGlyph.bird,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            // 5 Tab 均分 62px Row：字号 12→11 防「展览厅」三字挤换行。
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.path, this.label, this.glyph);
  final String path;
  final String label;
  final OrigamiGlyph glyph;
}
