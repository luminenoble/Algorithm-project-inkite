import 'package:cloud_firestore/cloud_firestore.dart';

/// `charactersCache/{characterKey}` 文档的强类型映射。
///
/// 由「开拓」栏离线导入脚本（`functions/scripts/import_characters.mjs`，方案 A）
/// 从姊妹项目 ISR-scraper 聚合写入；客户端只读（`firestore.rules` 强制）。
/// 旧 5 字段（name / wikiSummary / wikiUrl / redditPosts / cachedAt）接口冻结不动，
/// 新增字段全部可空、缺省给安全默认，保持向后兼容（design.md §7）。
class CharacterCache {
  const CharacterCache({
    required this.key,
    required this.name,
    required this.wikiSummary,
    required this.wikiUrl,
    required this.redditPosts,
    required this.cachedAt,
    this.source = '',
    this.tag = '',
    this.popularity = 0,
    this.obscurity = 0,
    this.searchTokens = const [],
  });

  final String key;
  final String name;
  final String wikiSummary;
  final String wikiUrl;
  final List<Map<String, dynamic>> redditPosts;
  final DateTime? cachedAt;

  /// 主条目来源：`fandom` / `wikipedia`（徽标配色锚点）。
  final String source;

  /// 条目语义标签：`canon` / `fanon` / `meta` / `crossover`（ISR `Hit.tag`）。
  final String tag;

  /// ISR popularity，「开拓」落地页热度排序用。
  final num popularity;

  /// ISR obscurity（冷门度），可做「发现冷门角色」入口。
  final num obscurity;

  /// 角色名 normalize 后的累进前缀 + 分词，供 app 端 `array-contains` 名称搜索。
  final List<String> searchTokens;

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
      source: (data['source'] as String?) ?? '',
      tag: (data['tag'] as String?) ?? '',
      popularity: (data['popularity'] as num?) ?? 0,
      obscurity: (data['obscurity'] as num?) ?? 0,
      searchTokens: ((data['searchTokens'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
