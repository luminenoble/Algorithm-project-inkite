import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Callable Cloud Functions 客户端（HTTPS 直调实现）。
///
/// 不走 `cloud_functions` 包——它在 Windows 桌面上没有原生 pigeon handler
/// (CLAUDE.md §7 同款 firebase_storage 不直连的策略)。
/// 改用 Firebase Auth ID token + http POST 直接命中 v2 onCall 端点：
///
/// ```
/// POST https://<region>-<project>.cloudfunctions.net/<name>
/// Authorization: Bearer <id-token>
/// Content-Type: application/json
/// Body: {"data": <args>}
/// ```
///
/// 成功 → 200 + `{"result": ...}`；失败 → 非 2xx + `{"error": {"status","message"}}`。
/// gRPC status 字符串转 callable 风格小写 dash code，对齐之前 cloud_functions 包的语义。
class OrigamiService {
  OrigamiService._();
  static final OrigamiService instance = OrigamiService._();

  static const String _region = 'asia-east1';
  static const String _projectId = 'inkite-demo';

  String _functionUrl(String name) =>
      'https://$_region-$_projectId.cloudfunctions.net/$name';

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CallableException('unauthenticated', '请先登录');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CallableException('unauthenticated', '无法获取登录凭证');
    }

    final http.Response res;
    try {
      res = await http.post(
        Uri.parse(_functionUrl(name)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'data': data}),
      );
    } catch (e) {
      throw CallableException('unavailable', '网络错误：$e');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      final preview =
          res.body.length > 200 ? '${res.body.substring(0, 200)}…' : res.body;
      throw CallableException(
        'internal',
        'HTTP ${res.statusCode} 响应非 JSON：$preview',
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final result = body['result'];
      if (result is Map) return Map<String, dynamic>.from(result);
      throw const CallableException('internal', '响应缺少 result 字段');
    }

    final err = body['error'];
    if (err is Map) {
      final status = (err['status'] as String?) ?? 'UNKNOWN';
      final message =
          (err['message'] as String?) ?? 'HTTP ${res.statusCode}';
      throw CallableException(_statusToCode(status), message);
    }
    throw CallableException('internal', 'HTTP ${res.statusCode}');
  }

  /// gRPC 风格的 SCREAMING_SNAKE → callable lower-dash 风格。
  /// 例：`FAILED_PRECONDITION` → `failed-precondition`。
  static String _statusToCode(String status) {
    return status.toLowerCase().replaceAll('_', '-');
  }

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
    final data = await _call('generateOrigami', {
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

  /// F2：**自由 AI** 折纸生成（对应 `generateAiOrigami` Callable）。
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
    final data = await _call('generateAiOrigami', {
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

/// Callable 调用失败的统一异常类型。
///
/// `code` 对齐 v2 onCall 的 gRPC status 小写 dash 形式：
/// `unauthenticated` / `invalid-argument` / `failed-precondition` /
/// `resource-exhausted` / `internal` / `unavailable` / 其他。
class CallableException implements Exception {
  const CallableException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CallableException($code): $message';
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
