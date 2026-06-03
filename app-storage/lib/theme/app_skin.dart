import 'package:flutter/widgets.dart';

import 'ink_skin.dart';
import 'paper_skin.dart';

/// 当前生效皮肤 = 一套纸张皮肤 + 一套墨水皮肤（`docs/fronted-design.md` §8）。
///
/// 页面只认 `context.skin.xxx`（见 `skin_controller.dart` 的 `SkinX` 扩展），
/// 不直接引用 [PaperSkin] / [InkSkin] 的字段，便于整体换装。
@immutable
class AppSkin {
  const AppSkin({
    required this.paper,
    required this.ink,
    this.dark = false,
  });

  final PaperSkin paper;
  final InkSkin ink;

  /// 暗色模式（预留，§1.1 注）。
  final bool dark;

  // —— 纸面令牌（转发自 [paper]）——
  Color get paperBase => paper.paperBase;
  Color get paperShade => paper.paperShade;
  Color get paperHighlight => paper.paperHighlight;
  Color get surfaceCard => paper.surfaceCard;
  Color get foldLightTint => paper.foldLightTint;

  // —— 墨色 / 点缀令牌（转发自 [ink]）——
  Color get inkPrimary => ink.inkPrimary;
  Color get inkSecondary => ink.inkSecondary;
  Color get inkFaint => ink.inkFaint;
  Color get accentVermilion => ink.accentVermilion;
  Color get accentSeal => ink.accentSeal;
  Color get goldLeaf => ink.goldLeaf;

  /// 当前墨水是否启用魔法（渐变）笔触。
  bool get magicStroke => ink.strokeEffect == InkStrokeEffect.gradient;

  /// 默认皮肤「宣纸 · 松烟墨」。
  static const defaultSkin = AppSkin(
    paper: PaperSkin.xuanDefault,
    ink: InkSkin.pineSoot,
  );

  AppSkin copyWith({PaperSkin? paper, InkSkin? ink, bool? dark}) => AppSkin(
        paper: paper ?? this.paper,
        ink: ink ?? this.ink,
        dark: dark ?? this.dark,
      );
}
