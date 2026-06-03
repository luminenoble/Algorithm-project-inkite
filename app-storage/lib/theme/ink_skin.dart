import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

/// 墨水皮肤的笔触特效（`docs/fronted-design.md` §8.1）。
enum InkStrokeEffect {
  /// 无特效
  none,

  /// 晕染
  bleed,

  /// 渐变流彩（魔法墨水）
  gradient,
}

/// 墨水皮肤（§8.1）。覆盖墨色令牌 + 点缀色 + 笔触特效。
@immutable
class InkSkin {
  const InkSkin({
    required this.id,
    required this.displayName,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkFaint,
    required this.accentVermilion,
    required this.accentSeal,
    required this.goldLeaf,
    this.strokeEffect = InkStrokeEffect.none,
    this.requiresUnlock = false,
    this.gradientStroke,
    this.unlockWords,
  });

  final String id;
  final String displayName;

  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkFaint;
  final Color accentVermilion;
  final Color accentSeal;
  final Color goldLeaf;

  /// 笔触特效标记。
  final InkStrokeEffect strokeEffect;

  /// 是否需解锁（对应 `users.unlocks.magicInk`，§8.3）。
  final bool requiresUnlock;

  /// 渐变笔触用色（`strokeEffect == gradient` 时）。
  final List<Color>? gradientStroke;

  /// 解锁绑定的三个官方词语（null/空 = 免费）。
  /// 用户已发布故事 `words` 命中即解锁；魔法墨水另认旧 `magicInk` 旗标（OR）。
  final List<String>? unlockWords;

  /// 默认墨水「松烟墨」—— 取 [DesignTokens] 默认值。
  static const pineSoot = InkSkin(
    id: 'pine_soot',
    displayName: '松烟墨',
    inkPrimary: DesignTokens.inkPrimary,
    inkSecondary: DesignTokens.inkSecondary,
    inkFaint: DesignTokens.inkFaint,
    accentVermilion: DesignTokens.accentVermilion,
    accentSeal: DesignTokens.accentSeal,
    goldLeaf: DesignTokens.goldLeaf,
  );

  /// 预置「朱砂」—— 词语解锁：火 / 朱 / 印。
  static const vermilion = InkSkin(
    id: 'vermilion',
    displayName: '朱砂',
    inkPrimary: Color(0xFF3B2A24),
    inkSecondary: Color(0xFF7A5A4A),
    inkFaint: Color(0xFFD8C6B8),
    accentVermilion: Color(0xFFDC2626),
    accentSeal: Color(0xFF991B1B),
    goldLeaf: DesignTokens.goldLeaf,
    requiresUnlock: true,
    unlockWords: ['火', '朱', '印'],
  );

  /// 「魔法墨水」—— 词语解锁：星 / 梦 / 流光（另认旧 `magicInk` 旗标，OR）。
  /// 解锁后启用渐变笔触（§8.3）。
  static const magicFlow = InkSkin(
    id: 'magic_flow',
    displayName: '魔法墨水',
    inkPrimary: Color(0xFF2B2540),
    inkSecondary: Color(0xFF6B6280),
    inkFaint: Color(0xFFC9C0D8),
    accentVermilion: Color(0xFF7C3AED),
    accentSeal: Color(0xFF5B21B6),
    goldLeaf: DesignTokens.goldLeaf,
    strokeEffect: InkStrokeEffect.gradient,
    requiresUnlock: true,
    gradientStroke: [Color(0xFF7C3AED), Color(0xFFC2410C)],
    unlockWords: ['星', '梦', '流光'],
  );

  /// 内置墨水皮肤（含 1 套锁定演示）。
  static const presets = <InkSkin>[pineSoot, vermilion, magicFlow];
}
