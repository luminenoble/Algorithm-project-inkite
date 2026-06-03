import 'package:flutter/widgets.dart';

/// 设计令牌原始常量 —— 默认皮肤「宣纸 · 松烟墨」的取值
/// （`docs/fronted-design.md` §1.1 / §1.3）。
///
/// 颜色字面量只允许出现在 `lib/theme/` 这一层（皮肤定义即设计令牌层）；
/// 页面与组件一律通过 [AppSkin] / `context.skin` 读取，**禁止**在 widget 内
/// 写死 §1.1 的字面量（设计 §8.4）。
abstract final class DesignTokens {
  DesignTokens._();

  // —— 色彩令牌（§1.1，默认浅色「宣纸 · 松烟墨」）——
  /// 纸面主背景（宣纸暖白）
  static const paperBase = Color(0xFFF5F1E8);

  /// 纸面阴影 / 折痕暗面
  static const paperShade = Color(0xFFE7E0D0);

  /// 纸面高光 / 折痕亮面
  static const paperHighlight = Color(0xFFFFFDF7);

  /// 主墨色（正文 / 主文字，松烟墨）
  static const inkPrimary = Color(0xFF2B2622);

  /// 次墨色（辅助文字）
  static const inkSecondary = Color(0xFF6B6258);

  /// 极淡墨（分隔线 / 禁用）
  static const inkFaint = Color(0xFFC9C0B2);

  /// 朱砂点缀（主操作 / 点赞选中 / Top3）
  static const accentVermilion = Color(0xFFC2410C);

  /// 印章红（已发布印章 / 官方挑战徽标）
  static const accentSeal = Color(0xFF9A2D1F);

  /// 卡片底
  static const surfaceCard = Color(0xFFFBF8F0);

  /// 金箔（解锁 / 折纸藏品边框）
  static const goldLeaf = Color(0xFFB8893A);

  // —— 暗色皮肤预留（§1.1 注；非首版必做，仅令牌替换）——
  static const darkPaperBase = Color(0xFF1E1B17);
  static const darkInkPrimary = Color(0xFFEDE6D8);

  // —— 形状 / 圆角（§1.3）——
  static const radiusCard = 12.0;
  static const radiusButton = 10.0;
  static const radiusDialog = 16.0;

  // —— 间距基数：4 的倍数（§1.3）——
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  /// 桌面端页面外边距
  static const pagePadding = 24.0;

  /// 列表项间距
  static const listGap = 12.0;
}
