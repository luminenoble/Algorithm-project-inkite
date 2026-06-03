import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

/// 纸张皮肤（`docs/fronted-design.md` §8.1）。
///
/// 一套皮肤 = 一组纸面令牌 + 可选纹理；切皮肤 = 整体替换令牌，页面逻辑零改动。
@immutable
class PaperSkin {
  const PaperSkin({
    required this.id,
    required this.displayName,
    required this.paperBase,
    required this.paperShade,
    required this.paperHighlight,
    required this.surfaceCard,
    this.textureAsset,
    this.unlockWords,
    Color? foldLightTint,
  }) : foldLightTint = foldLightTint ?? paperHighlight;

  /// 皮肤唯一标识（如 `xuan_default` / `kraft`）。
  final String id;

  /// 展示名（皮肤选择器用）。
  final String displayName;

  final Color paperBase;
  final Color paperShade;
  final Color paperHighlight;
  final Color surfaceCard;

  /// 纸纹贴图资源（可空 = 纯色）。本版默认无纹理，留资源 seam。
  final String? textureAsset;

  /// 解锁绑定的三个官方词语（null/空 = 免费）。
  /// 用户已发布的故事 `words` 命中这三词即解锁（见 `data/unlock_state.dart`）。
  final List<String>? unlockWords;

  /// 折叠转场折痕受光着色（默认取 [paperHighlight]）。
  final Color foldLightTint;

  /// 默认皮肤「宣纸」—— 取 [DesignTokens] 默认值（单一事实来源）。
  static const xuanDefault = PaperSkin(
    id: 'xuan_default',
    displayName: '宣纸',
    paperBase: DesignTokens.paperBase,
    paperShade: DesignTokens.paperShade,
    paperHighlight: DesignTokens.paperHighlight,
    surfaceCard: DesignTokens.surfaceCard,
  );

  /// 预置「牛皮纸」—— 词语解锁：秋 / 霜 / 信笺。
  static const kraft = PaperSkin(
    id: 'kraft',
    displayName: '牛皮纸',
    paperBase: Color(0xFFD9C7A8),
    paperShade: Color(0xFFC4AD82),
    paperHighlight: Color(0xFFEBDCC1),
    surfaceCard: Color(0xFFE4D4B6),
    unlockWords: ['秋', '霜', '信笺'],
  );

  /// 预置「雪浪笺」—— 冷调宣纸，词语解锁：雪 / 梅 / 夜。
  static const snow = PaperSkin(
    id: 'snow',
    displayName: '雪浪笺',
    paperBase: Color(0xFFEFF3F6),
    paperShade: Color(0xFFD2DBE2),
    paperHighlight: Color(0xFFFAFCFE),
    surfaceCard: Color(0xFFE7EDF2),
    unlockWords: ['雪', '梅', '夜'],
  );

  /// 内置可选纸张皮肤（默认免费 + 词语解锁项）。
  static const presets = <PaperSkin>[xuanDefault, kraft, snow];
}
