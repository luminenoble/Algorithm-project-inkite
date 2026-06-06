import 'dart:convert';
import 'dart:typed_data';

import 'functions_client.dart';

/// 故事书封面上传的 Callable 封装（T6.0，`docs/next-design-detailed.md` §3.1）。
///
/// 守 `CLAUDE.md` §7「客户端不直连 Storage」：把图片 bytes 转 base64 交给
/// `uploadStorybookCover` CF，由 CF 写 Storage 并回写 `storybooks.coverUrl`。
/// CF 回写后 `StorybookRepository.watchById` 会自动刷新封面，故本方法只需
/// 返回新 URL 供即时反馈。
class StorybookService {
  StorybookService._();
  static final StorybookService instance = StorybookService._();

  /// 封面大小上限（与 CF 端 `MAX_COVER_BYTES` 一致），客户端先行拦截给友好提示。
  static const int maxCoverBytes = 1024 * 1024;

  /// 上传自定义封面。[bytes] 超 [maxCoverBytes] 抛 [CallableException]
  /// `invalid-argument`（不发起网络请求）。
  ///
  /// 抛 [CallableException] 时 `code` 可能为：
  /// - `unauthenticated`：未登录
  /// - `permission-denied`：故事书不属于本人
  /// - `invalid-argument`：图过大 / 参数缺失
  /// - `not-found`：故事书不存在
  Future<String> uploadCover(
    String storybookId,
    Uint8List bytes, {
    String contentType = 'image/png',
  }) async {
    if (bytes.isEmpty) {
      throw const CallableException('invalid-argument', '封面图为空');
    }
    if (bytes.length > maxCoverBytes) {
      throw const CallableException('invalid-argument', '封面图过大（≤1MB）');
    }
    final data = await FunctionsClient.instance.call('uploadStorybookCover', {
      'storybookId': storybookId,
      'imageBase64': base64Encode(bytes),
      'contentType': contentType,
    });
    return data['coverUrl'] as String;
  }
}
