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
