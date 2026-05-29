import 'package:cloud_firestore/cloud_firestore.dart';

/// `challenges/{challengeId}` 文档的强类型映射。
/// 写入端为运营 / Console，客户端只读（T1.4 规则保证）。
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.words,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String title;
  final List<String> words;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final DateTime? createdAt;

  factory Challenge.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Challenge(
      id: snap.id,
      title: (data['title'] as String?) ?? '',
      words: ((data['words'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      startAt: (data['startAt'] as Timestamp?)?.toDate(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      isActive: (data['isActive'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
