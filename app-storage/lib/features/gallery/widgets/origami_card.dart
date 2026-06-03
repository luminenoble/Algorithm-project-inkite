import 'package:flutter/material.dart';

import '../../../data/models/origami.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/brush_loading.dart';

/// 折纸藏品卡片：图片 + 风格标签 + 创建时间。
///
/// 图片走 `Image.network(origami.imageUrl)`，**客户端不直连 Storage**
/// （`CLAUDE.md` §7）。CF 写折纸时已经把 URL 写进 Firestore。
class OrigamiCard extends StatelessWidget {
  const OrigamiCard({
    super.key,
    required this.origami,
    this.goldEdge = false,
  });

  /// `magicInk` 解锁后画廊整体走金箔点缀（T4.4），通过这个开关把边框染金。
  final bool goldEdge;
  final Origami origami;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      decoration: BoxDecoration(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goldEdge ? skin.goldLeaf : skin.paperShade,
          width: goldEdge ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: skin.paperShade.withValues(alpha: 0.7),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              origami.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: skin.paperShade,
                  alignment: Alignment.center,
                  child: const BrushLoading(size: 28, showSlowHint: false),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: skin.paperShade,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined,
                    color: skin.inkSecondary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Expanded(child: _Tag(origami: origami)),
                const SizedBox(width: 6),
                if (origami.createdAt != null)
                  Text(
                    _formatDate(origami.createdAt!),
                    style: TextStyle(fontSize: 11, color: skin.inkSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }
}

/// 折纸卡片底部标签：
/// - F2 自由 AI 折纸（`words` 非空）→ 显示 3 词，例「幽谷 · 秋霜 · 画家」
/// - 官方挑战折纸（style 非空）→ 显示 style 标签
/// - 其它 → 空
class _Tag extends StatelessWidget {
  const _Tag({required this.origami});
  final Origami origami;

  static const _styleLabels = {
    'zen': '禅',
    'steampunk': '蒸汽',
    'ink': '水墨',
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final words = origami.words;
    if (words != null && words.isNotEmpty) {
      // F2 自由 AI 折纸：金箔色调标签，呼应 AI 召唤卡的识别色。
      return _Pill(
        text: words.join(' · '),
        bg: skin.goldLeaf.withValues(alpha: 0.14),
        fg: skin.inkPrimary,
      );
    }
    if (origami.style.isNotEmpty) {
      final label = _styleLabels[origami.style] ?? origami.style;
      return _Pill(text: label, bg: skin.paperBase, fg: skin.inkPrimary);
    }
    return const SizedBox.shrink();
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: fg),
      ),
    );
  }
}
