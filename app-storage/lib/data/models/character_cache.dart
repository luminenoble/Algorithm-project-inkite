import 'package:cloud_firestore/cloud_firestore.dart';

/// `charactersCache/{characterKey}` 文档的强类型映射。
/// 由模块 G 写入；客户端只读。`redditPosts` 内部结构由模块 G 定义，本层保留 raw。
class CharacterCache {
  const CharacterCache({
    required this.key,
    required this.name,
    required this.wikiSummary,
    required this.wikiUrl,
    required this.redditPosts,
    required this.cachedAt,
  });

  final String key;
  final String name;
  final String wikiSummary;
  final String wikiUrl;
  final List<Map<String, dynamic>> redditPosts;
  final DateTime? cachedAt;

  factory CharacterCache.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return CharacterCache(
      key: snap.id,
      name: (data['name'] as String?) ?? '',
      wikiSummary: (data['wikiSummary'] as String?) ?? '',
      wikiUrl: (data['wikiUrl'] as String?) ?? '',
      redditPosts: ((data['redditPosts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      cachedAt: (data['cachedAt'] as Timestamp?)?.toDate(),
    );
  }
}
