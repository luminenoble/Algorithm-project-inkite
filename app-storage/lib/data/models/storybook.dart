import 'package:cloud_firestore/cloud_firestore.dart';

/// 默认章节名常量（`docs/next-design-detailed.md` §0.2）。
/// 故事未指定章节时落入此章。
const String kDefaultChapter = '未分章';

/// 默认「未分类」故事书的固定书名。默认书禁改名。
const String kDefaultStorybookTitle = '未分类';

/// 每用户默认故事书的确定性 ID（`default_{uid}`），便于惰性创建幂等
/// （§0.2「默认故事书」）。
String defaultStorybookId(String uid) => 'default_$uid';

/// 故事书总览排序方式（对应「创建时间 / 修改时间排序」）。
enum StorybookSort { createdAt, updatedAt }

/// `storybooks/{storybookId}` 文档的强类型映射（`docs/schema-design/design.md` §8）。
///
/// `coverUrl` 由 Cloud Function `uploadStorybookCover` 写入，**前端禁写**
/// （安全规则强制）。故 [toCreateMap] / 各 update 都不含 `coverUrl`。
/// `coverAssetId`（内置预设）是纯前端开关，可直写。
class Storybook {
  const Storybook({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.coverUrl,
    required this.coverAssetId,
    required this.chapterOrder,
    required this.isDefault,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;

  /// CF 维护，前端禁写；为空时前端回落内置预设。
  final String? coverUrl;

  /// 选用的内置预设封面 ID（如 `cover_zen_01`），与 [coverUrl] 互斥，
  /// [coverUrl] 优先。前端可写。
  final String? coverAssetId;

  /// 章节展示顺序（章节名数组）；缺省按 story 的 `createdAt` 推断。
  final List<String> chapterOrder;

  /// 是否默认「未分类」书。默认书禁删、禁改名（可换封面、可 pin）。
  final bool isDefault;

  /// 是否置顶。总览中 pinned 优先排前。
  final bool pinned;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Storybook.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Storybook(
      id: snap.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      title: (data['title'] as String?) ?? kDefaultStorybookTitle,
      coverUrl: data['coverUrl'] as String?,
      coverAssetId: data['coverAssetId'] as String?,
      chapterOrder: (data['chapterOrder'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      isDefault: (data['isDefault'] as bool?) ?? false,
      pinned: (data['pinned'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 客户端 create 用的 payload。
  /// **不含** `coverUrl`（CF 维护）、`id`（自动生成）；时间戳用 serverTimestamp。
  Map<String, dynamic> toCreateMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      if (coverAssetId != null) 'coverAssetId': coverAssetId,
      'chapterOrder': chapterOrder,
      'isDefault': isDefault,
      'pinned': pinned,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 当前排序维度对应的时间（总览卡片副文用）。
  DateTime? timeFor(StorybookSort sort) =>
      sort == StorybookSort.createdAt ? createdAt : updatedAt;
}
