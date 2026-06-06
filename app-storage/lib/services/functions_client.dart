import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Callable Cloud Functions 客户端（HTTPS 直调实现）。
///
/// 不走 `cloud_functions` 包——它在 Windows 桌面上没有原生 pigeon handler
/// （`CLAUDE.md` §7 同款 firebase_storage 不直连的策略）。
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
/// gRPC status 字符串转 callable 风格小写 dash code，对齐 cloud_functions 包语义。
///
/// 这是 [OrigamiService]（折纸发放）与 `StorybookService`（封面上传）共用的
/// 底座，抽出避免重复实现 HTTP / 错误映射逻辑。
class FunctionsClient {
  FunctionsClient._();
  static final FunctionsClient instance = FunctionsClient._();

  static const String _region = 'asia-east1';
  static const String _projectId = 'inkite-demo';

  String _functionUrl(String name) =>
      'https://$_region-$_projectId.cloudfunctions.net/$name';

  /// 调用一个 v2 onCall 函数。成功返回其 `result` Map；失败抛 [CallableException]。
  Future<Map<String, dynamic>> call(
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
