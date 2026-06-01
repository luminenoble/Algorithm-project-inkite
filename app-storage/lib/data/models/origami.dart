import 'package:cloud_firestore/cloud_firestore.dart';

/// `origami/{origamiId}` 文档的强类型映射。
/// 全部由 Cloud Function `generateOrigami` / `generateAiOrigami` 写入，客户端只读。
class Origami {
  const Origami({
    required this.id,
    required this.ownerId,
    required this.imageUrl,
    required this.style,
    required this.sourceChallengeId,
    required this.source,
    required this.createdAt,
    required this.words,
  });

  final String id;
  final String ownerId;
  final String imageUrl;
  final String style;

  /// 官方挑战发放的折纸：对应挑战 ID。
  /// F2 自由 AI 发放：CF 写入 null（前端读到时为空串 fallback）。
  final String sourceChallengeId;
  final String source; // 'pregen' | 'flux'
  final DateTime? createdAt;

  /// F2 自由 AI 发放时，CF 把用户输入的 3 个关键词写入；其他来源为 null。
  final List<String>? words;

  factory Origami.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Origami(
      id: snap.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      style: (data['style'] as String?) ?? '',
      sourceChallengeId: (data['sourceChallengeId'] as String?) ?? '',
      source: (data['source'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      words: (data['words'] as List?)
          ?.map((e) => e.toString())
          .toList(growable: false),
    );
  }
}
