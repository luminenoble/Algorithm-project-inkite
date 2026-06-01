import 'package:flutter/material.dart';

import '../../../data/models/origami.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goldEdge
              ? const Color(0xFFB8893A)
              : const Color(0xFFE7E0D0),
          width: goldEdge ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                  color: const Color(0xFFE7E0D0),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFE7E0D0),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF6B6258),
                ),
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6258),
                    ),
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
    final words = origami.words;
    if (words != null && words.isNotEmpty) {
      return _Pill(
        text: words.join(' · '),
        bg: const Color(0xFFFAF0E1),
        fg: const Color(0xFF6E4F1F),
      );
    }
    if (origami.style.isNotEmpty) {
      final label = _styleLabels[origami.style] ?? origami.style;
      return _Pill(
        text: label,
        bg: const Color(0xFFF5F1E8),
        fg: const Color(0xFF2B2622),
      );
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
