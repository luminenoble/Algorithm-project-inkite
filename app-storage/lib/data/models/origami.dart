import 'package:cloud_firestore/cloud_firestore.dart';

/// `origami/{origamiId}` 文档的强类型映射。
/// 全部由 Cloud Function `generateOrigami`（T1.8）写入，客户端只读。
class Origami {
  const Origami({
    required this.id,
    required this.ownerId,
    required this.imageUrl,
    required this.style,
    required this.sourceChallengeId,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String imageUrl;
  final String style;
  final String sourceChallengeId;
  final String source; // 'pregen' | 'flux'
  final DateTime? createdAt;

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
    );
  }
}
