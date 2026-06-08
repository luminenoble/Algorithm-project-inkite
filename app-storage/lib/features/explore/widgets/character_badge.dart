import 'package:flutter/material.dart';

import '../../../theme/app_skin.dart';
import '../../../theme/skin_controller.dart';

/// 「官方权威↔民间二创」光谱徽标（角色查询-todo §5.3 / ISR design.md 同款语义）。
///
/// tag 配色：canon=朱砂、fanon=墨蓝、meta/crossover=灰；
/// source 用于 redditPosts 区分 reddit / ao3 配色。徽标在「开拓」落地页卡片
/// 与角色详情页复用，集中在此保证配色一致。
class CharacterBadge extends StatelessWidget {
  const CharacterBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  /// 按 ISR 语义标签取色（canon/fanon/meta/crossover）。
  factory CharacterBadge.tag(BuildContext context, String tag) {
    final skin = context.skin;
    return CharacterBadge(
      label: _tagLabel(tag),
      color: tagColor(skin, tag),
    );
  }

  /// 按来源取色（fandom/wikipedia/reddit/ao3）。
  factory CharacterBadge.source(BuildContext context, String source) {
    return CharacterBadge(
      label: _sourceLabel(source),
      color: sourceColor(context.skin, source),
    );
  }

  static Color tagColor(AppSkin skin, String tag) {
    switch (tag.toLowerCase()) {
      case 'canon':
        return skin.accentVermilion;
      case 'fanon':
        return _inkBlue;
      default: // meta / crossover / 未知
        return skin.inkSecondary;
    }
  }

  static Color sourceColor(AppSkin skin, String source) {
    switch (source.toLowerCase()) {
      case 'wikipedia':
      case 'fandom':
        return skin.accentVermilion;
      case 'reddit':
        return _redditOrange;
      case 'ao3':
        return _inkBlue;
      default:
        return skin.inkSecondary;
    }
  }

  static String _tagLabel(String tag) {
    switch (tag.toLowerCase()) {
      case 'canon':
        return '官方设定';
      case 'fanon':
        return '同人设定';
      case 'meta':
        return '考据';
      case 'crossover':
        return '联动';
      default:
        return tag.isEmpty ? '其他' : tag;
    }
  }

  static String _sourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'wikipedia':
        return 'Wikipedia';
      case 'fandom':
        return 'Fandom';
      case 'reddit':
        return 'Reddit';
      case 'ao3':
        return 'AO3';
      default:
        return source.isEmpty ? '未知来源' : source;
    }
  }

  // 墨蓝：同人/AO3 二创侧；灰：考据。与项目朱砂主调拉开冷暖。
  static const _inkBlue = Color(0xFF3A567A);
  static const _redditOrange = Color(0xFFB5531C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
