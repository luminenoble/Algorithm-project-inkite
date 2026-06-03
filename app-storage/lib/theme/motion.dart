import 'package:flutter/animation.dart';

/// 动效级别（`docs/fronted-design.md` §7.1）。
///
/// 响应系统「减少动态效果」偏好应自动降到 [reduced]。
enum MotionLevel {
  /// 全动效：翻书折叠 / 纸鸟 / 合拢 / 摊开等折纸动作齐全。
  full,

  /// 仅淡入淡出：富动效退为标准 Fade。
  reduced,

  /// 几乎无动效：转场瞬切。
  off;

  String get displayName => switch (this) {
        MotionLevel.full => '全动效',
        MotionLevel.reduced => '淡入淡出',
        MotionLevel.off => '关闭',
      };

  /// 是否启用「完整折纸动效」（翻书折叠 / 纸鸟飞行 / 合拢 / 摊开）。
  /// 仅 [full] 为真；[reduced] 退淡入淡出，[off] 直接切。
  bool get useRichMotion => this == MotionLevel.full;

  /// 按级别缩放时长：[off] → 零（瞬切）；其余按原值。
  Duration scale(Duration d) =>
      this == MotionLevel.off ? Duration.zero : d;
}

/// 时长 / 缓动令牌（§1.4）。折纸动作偏「硬挺纸张」，缓动带「折到位的顿挫」。
abstract final class Motion {
  Motion._();

  /// hover / 按下态反馈
  static const durInstant = Duration(milliseconds: 120);

  /// 翻页折叠主转场单段
  static const durFold = Duration(milliseconds: 420);

  /// 纸鸟飞过 / 飞出
  static const durBirdFly = Duration(milliseconds: 900);

  /// 他人文章展开
  static const durUnfold = Duration(milliseconds: 520);

  /// 保存合拢
  static const durSaveFold = Duration(milliseconds: 600);

  /// 折到位顿挫（折叠类）
  static const curveFold = Cubic(0.45, 0.05, 0.30, 1.0);

  /// 起飞加速 → 滑翔（纸鸟类）
  static const curveFly = Cubic(0.22, 0.61, 0.36, 1.0);

  /// 展开类
  static const curveUnfold = Curves.easeOutCubic;
}
