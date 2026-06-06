import 'functions_client.dart';

// CallableException 现住在 functions_client.dart；re-export 保持既有
// `import '.../origami_service.dart'` 的调用方（如 ai_origami_card.dart）不破坏。
export 'functions_client.dart' show CallableException;

/// 折纸发放相关的 Callable 封装。底层 HTTPS 直调走 [FunctionsClient]。
class OrigamiService {
  OrigamiService._();
  static final OrigamiService instance = OrigamiService._();

  /// 触发**官方挑战**折纸发放（对应 `generateOrigami` Callable）。
  ///
  /// CF 幂等：同 (uid, challengeId) 重复调用返回首次记录。
  /// 抛 [CallableException] 时 `code` 可能为：
  /// - `unauthenticated` / `invalid-argument` / `failed-precondition`
  Future<OrigamiResult> generate({
    required String challengeId,
    String? style,
    bool live = false,
  }) async {
    final data = await FunctionsClient.instance.call('generateOrigami', {
      'challengeId': challengeId,
      'style': ?style,
      if (live) 'live': true,
    });
    return OrigamiResult(
      origamiId: data['origamiId'] as String,
      imageUrl: data['imageUrl'] as String,
      style: data['style'] as String,
      source: data['source'] as String,
    );
  }

  /// F2:**自由 AI** 折纸生成（对应 `generateAiOrigami` Callable）。
  /// 用户必须传入恰好 3 个非空关键词；这些词会织进 Replicate prompt，
  /// 并随 origami 文档落库（`origami.words`）。周配额由 CF 维护。
  ///
  /// 自由 AI 折纸**不再分类到 zen/steampunk/ink** —— 3 词就是它的全部身份。
  ///
  /// 抛 [CallableException] 时 `code` 可能为：
  /// - `unauthenticated`：未登录
  /// - `invalid-argument`：关键词数量 / 长度不合法（客户端应预先校验）
  /// - `resource-exhausted`：本周配额已用完
  /// - `internal`：Replicate 调用失败，配额已自动退回
  Future<AiOrigamiResult> generateAiFree({
    required List<String> words,
  }) async {
    final data = await FunctionsClient.instance.call('generateAiOrigami', {
      'words': words,
    });
    final quota = Map<String, dynamic>.from(data['quota'] as Map);
    return AiOrigamiResult(
      origamiId: data['origamiId'] as String,
      imageUrl: data['imageUrl'] as String,
      words: (data['words'] as List).map((e) => e.toString()).toList(),
      quotaUsed: (quota['used'] as num).toInt(),
      quotaLimit: (quota['limit'] as num).toInt(),
      windowExpiresAt: DateTime.fromMillisecondsSinceEpoch(
        (quota['windowExpiresAtMs'] as num).toInt(),
      ),
      bonusLikes: quota['bonusLikes'] as bool,
      bonusChallenges: quota['bonusChallenges'] as bool,
    );
  }
}

class OrigamiResult {
  const OrigamiResult({
    required this.origamiId,
    required this.imageUrl,
    required this.style,
    required this.source,
  });

  final String origamiId;
  final String imageUrl;
  final String style;
  final String source;
}

/// F2:自由 AI 折纸生成结果（含本次调用后的配额快照）。
/// 不带 `style`——自由 AI 折纸已不再做 zen/steampunk/ink 分类。
class AiOrigamiResult {
  const AiOrigamiResult({
    required this.origamiId,
    required this.imageUrl,
    required this.words,
    required this.quotaUsed,
    required this.quotaLimit,
    required this.windowExpiresAt,
    required this.bonusLikes,
    required this.bonusChallenges,
  });

  final String origamiId;
  final String imageUrl;
  final List<String> words;
  final int quotaUsed;
  final int quotaLimit;
  final DateTime windowExpiresAt;
  final bool bonusLikes;
  final bool bonusChallenges;
}
