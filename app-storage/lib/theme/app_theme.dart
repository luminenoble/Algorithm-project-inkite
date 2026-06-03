import 'package:flutter/material.dart';

import 'app_skin.dart';
import 'design_tokens.dart';

/// 由 [AppSkin] 构建 Material [ThemeData]（`docs/fronted-design.md` §1）。
///
/// 把折纸令牌映射到 Material 组件主题，使默认 `AppBar` / `Card` / `Chip` /
/// 按钮 / 输入框等无需逐个改色即呈纸面色调；切皮肤时整张主题随之换装。
abstract final class AppTheme {
  AppTheme._();

  static ThemeData from(AppSkin skin) {
    final brightness = skin.dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: skin.accentVermilion,
      brightness: brightness,
    ).copyWith(
      primary: skin.accentVermilion,
      onPrimary: skin.paperHighlight,
      secondary: skin.accentSeal,
      onSecondary: skin.paperHighlight,
      surface: skin.surfaceCard,
      onSurface: skin.inkPrimary,
      surfaceContainerHighest: skin.paperShade,
      error: skin.accentSeal,
      onError: skin.paperHighlight,
      outline: skin.inkFaint,
      outlineVariant: skin.inkFaint,
    );

    final radiusButton =
        BorderRadius.circular(DesignTokens.radiusButton);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: skin.paperBase,
      canvasColor: skin.paperBase,
      dividerColor: skin.inkFaint,
      textTheme: _textTheme(skin),
      iconTheme: IconThemeData(color: skin.inkPrimary),
      appBarTheme: AppBarThemeData(
        backgroundColor: skin.paperBase,
        foregroundColor: skin.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: skin.paperShade,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: skin.inkPrimary,
        ),
        iconTheme: IconThemeData(color: skin.inkPrimary),
      ),
      cardTheme: CardThemeData(
        color: skin.surfaceCard,
        // 纸面「薄而轻」：极淡投影而非 Material 厚重阴影（§1.3）。
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: skin.paperShade,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: skin.paperBase,
        selectedColor: skin.accentVermilion,
        side: BorderSide(color: skin.inkFaint),
        labelStyle: TextStyle(color: skin.inkPrimary, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: skin.paperHighlight),
        shape: RoundedRectangleBorder(borderRadius: radiusButton),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: skin.accentVermilion,
          foregroundColor: skin.paperHighlight,
          shape: RoundedRectangleBorder(borderRadius: radiusButton),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: skin.accentVermilion),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: skin.inkPrimary,
          side: BorderSide(color: skin.inkFaint),
          shape: RoundedRectangleBorder(borderRadius: radiusButton),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: skin.inkSecondary,
          selectedForegroundColor: skin.paperHighlight,
          selectedBackgroundColor: skin.accentVermilion,
          side: BorderSide(color: skin.inkFaint),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: skin.surfaceCard,
        labelStyle: TextStyle(color: skin.inkSecondary),
        hintStyle: TextStyle(color: skin.inkSecondary),
        border: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: BorderSide(color: skin.inkFaint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: BorderSide(color: skin.inkFaint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusButton,
          borderSide: BorderSide(color: skin.accentVermilion, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: skin.paperHighlight,
        indicatorColor: skin.accentVermilion.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: skin.inkPrimary,
        contentTextStyle: TextStyle(color: skin.paperHighlight),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusButton),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: skin.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: skin.inkFaint,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: skin.accentVermilion,
      ),
    );
  }

  /// 字号 / 字重 / 行高对齐设计 §1.2。中文衬线 / 仿宋字体随实现期填充，
  /// 本版用系统默认字族（字体资源属后续 seam）。
  static TextTheme _textTheme(AppSkin skin) {
    final ink = skin.inkPrimary;
    final inkSub = skin.inkSecondary;
    return TextTheme(
      // 大标题（页眉 / 挑战词）
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: ink,
      ),
      // 文章标题
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: ink,
      ),
      // 卡片标题
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: ink,
      ),
      // 正文（行高偏大贴近稿纸）
      bodyLarge: TextStyle(fontSize: 16, height: 1.75, color: ink),
      // 摘要 / 卡片副文
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: inkSub),
      // 辅助 / 时间戳
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: inkSub),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    );
  }
}
