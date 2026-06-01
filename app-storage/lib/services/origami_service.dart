import 'package:cloud_functions/cloud_functions.dart';

/// 折纸生成 Callable 的客户端包装。
///
/// 对应 `functions/src/generateOrigami.ts`。
/// CF 内部保证幂等（同 (uid, challengeId) 重复调用返回首次记录），所以
/// 这里不做客户端去重——业务逻辑里只在「官方挑战成功发布」时调一次即可。
class OrigamiService {
  OrigamiService._();
  static final OrigamiService instance = OrigamiService._();

  static const String _region = 'asia-east1';

  /// 触发折纸生成。
  /// - [challengeId] 必填，与已发布的 official story 的 `challengeId` 一致（防刷依据）
  /// - [style] 可选，缺省按 challengeId 哈希稳定选取
  /// - [live] = true 走 Replicate Flux Schnell 实拍（演示当天 1 次，约 ¥0.02）；
  ///   默认 false 走预生成池
  ///
  /// 抛 [FirebaseFunctionsException] 时 `code` 取值见 CF 实现：
  /// - `unauthenticated`：未登录
  /// - `invalid-argument`：缺 challengeId
  /// - `failed-precondition`：防刷未通过 / 素材池空
  Future<OrigamiResult> generate({
    required String challengeId,
    String? style,
    bool live = false,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('generateOrigami');
    final response = await callable.call<Map<Object?, Object?>>({
      'challengeId': challengeId,
      'style': ?style,
      if (live) 'live': true,
    });
    final data = Map<String, dynamic>.from(response.data);
    return OrigamiResult(
      origamiId: data['origamiId'] as String,
      imageUrl: data['imageUrl'] as String,
      style: data['style'] as String,
      source: data['source'] as String,
    );
  }

  /// F2：自由 AI 折纸生成。强制走 Replicate；周配额由 CF 维护。
  ///
  /// 抛 [FirebaseFunctionsException] 时 `code` 取值：
  /// - `unauthenticated`：未登录
  /// - `resource-exhausted`：本周配额已用完
  /// - `internal`：Replicate 调用失败，配额已自动退回
  Future<AiOrigamiResult> generateAiFree({String? style}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('generateAiOrigami');
    final response = await callable.call<Map<Object?, Object?>>({
      'style': ?style,
    });
    final data = Map<String, dynamic>.from(response.data);
    final quota = Map<String, dynamic>.from(data['quota'] as Map);
    return AiOrigamiResult(
      origamiId: data['origamiId'] as String,
      imageUrl: data['imageUrl'] as String,
      style: data['style'] as String,
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

/// F2：自由 AI 折纸生成结果（含本次调用后的配额快照）。
class AiOrigamiResult {
  const AiOrigamiResult({
    required this.origamiId,
    required this.imageUrl,
    required this.style,
    required this.quotaUsed,
    required this.quotaLimit,
    required this.windowExpiresAt,
    required this.bonusLikes,
    required this.bonusChallenges,
  });

  final String origamiId;
  final String imageUrl;
  final String style;
  final int quotaUsed;
  final int quotaLimit;
  final DateTime windowExpiresAt;
  final bool bonusLikes;
  final bool bonusChallenges;
}
