import 'package:flutter/material.dart';

import '../../data/models/storybook.dart';
import '../../theme/app_skin.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';

/// 内置预设封面（`docs/next-design-detailed.md` §0.2「默认封面」）。
///
/// 项目无图片 asset，预设封面**全部按皮肤令牌程序化绘制**（折纸折痕 +
/// 半透明造型图标），既零成本零 Storage 依赖，又随皮肤整体换装、不硬编码颜色
/// （守 `fronted-design.md` §8.4）。故事书 `coverUrl` 为空时回落预设，
/// 按 `coverAssetId` 选定或 `storybookId` 哈希取一张。

/// 单个预设的「角色取色」——值由当前 [AppSkin] 解析，故切皮肤即换装。
class CoverPreset {
  const CoverPreset({
    required this.id,
    required this.label,
    required this.top,
    required this.bottom,
    required this.accent,
    required this.glyph,
  });

  final String id;
  final String label;
  final Color Function(AppSkin) top;
  final Color Function(AppSkin) bottom;
  final Color Function(AppSkin) accent;
  final OrigamiGlyph glyph;
}

/// 预设目录。顺序即哈希取模顺序。
final List<CoverPreset> kCoverPresets = [
  CoverPreset(
    id: 'cover_zen_01',
    label: '宣纸',
    top: (s) => s.paperHighlight,
    bottom: (s) => s.paperShade,
    accent: (s) => s.inkSecondary,
    glyph: OrigamiGlyph.bird,
  ),
  CoverPreset(
    id: 'cover_ink_02',
    label: '松烟',
    top: (s) => s.inkSecondary,
    bottom: (s) => s.inkPrimary,
    accent: (s) => s.paperHighlight,
    glyph: OrigamiGlyph.emptyPaper,
  ),
  CoverPreset(
    id: 'cover_vermilion_03',
    label: '朱砂',
    top: (s) => s.accentVermilion,
    bottom: (s) => s.accentSeal,
    accent: (s) => s.paperHighlight,
    glyph: OrigamiGlyph.pen,
  ),
  CoverPreset(
    id: 'cover_gold_04',
    label: '金箔',
    top: (s) => s.goldLeaf,
    bottom: (s) => s.accentSeal,
    accent: (s) => s.paperHighlight,
    glyph: OrigamiGlyph.box,
  ),
  CoverPreset(
    id: 'cover_kraft_05',
    label: '牛皮',
    top: (s) => s.paperShade,
    bottom: (s) => s.inkSecondary,
    accent: (s) => s.paperHighlight,
    glyph: OrigamiGlyph.seal,
  ),
  CoverPreset(
    id: 'cover_indigo_06',
    label: '靛青',
    top: (s) => s.surfaceCard,
    bottom: (s) => s.inkPrimary,
    accent: (s) => s.accentVermilion,
    glyph: OrigamiGlyph.lens,
  ),
];

int _hash(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return h;
}

/// 解析故事书应回落的预设：优先 `coverAssetId`，否则按 `storybookId` 哈希。
CoverPreset presetFor({String? coverAssetId, required String storybookId}) {
  if (coverAssetId != null) {
    for (final p in kCoverPresets) {
      if (p.id == coverAssetId) return p;
    }
  }
  final seed = storybookId.isEmpty ? coverAssetId ?? '' : storybookId;
  return kCoverPresets[_hash(seed) % kCoverPresets.length];
}

/// 故事书封面：`coverUrl` 优先（`Image.network`，**客户端不直连 Storage**——
/// CF 已把 URL 写进 Firestore），否则回落程序化预设。加载/失败均回落预设，不空白。
class StorybookCover extends StatelessWidget {
  const StorybookCover({super.key, required this.book});

  final Storybook book;

  @override
  Widget build(BuildContext context) {
    final url = book.coverUrl;
    final preset = presetFor(
      coverAssetId: book.coverAssetId,
      storybookId: book.id,
    );
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return CoverPresetView(
            preset: preset,
            child: const Center(
              child: BrushLoading(size: 24, showSlowHint: false),
            ),
          );
        },
        errorBuilder: (_, _, _) => CoverPresetView(preset: preset),
      );
    }
    return CoverPresetView(preset: preset);
  }
}

/// 程序化预设封面绘制：对角折痕渐变底 + 居中半透明折纸造型。
class CoverPresetView extends StatelessWidget {
  const CoverPresetView({super.key, required this.preset, this.child});

  final CoverPreset preset;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [preset.top(skin), preset.bottom(skin)],
        ),
      ),
      child: CustomPaint(
        painter: _FoldLinesPainter(tint: preset.accent(skin)),
        child: Center(
          child: child ??
              Opacity(
                opacity: 0.85,
                child: OrigamiIcon(
                  preset.glyph,
                  size: 40,
                  color: preset.accent(skin),
                ),
              ),
        ),
      ),
    );
  }
}

/// 极淡的对角折痕线，强化「纸被折过」的母题。
class _FoldLinesPainter extends CustomPainter {
  _FoldLinesPainter({required this.tint});
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tint.withValues(alpha: 0.18);
    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.62),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height),
      Offset(size.width * 0.72, 0),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FoldLinesPainter old) => old.tint != tint;
}
