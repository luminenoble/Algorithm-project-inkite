import 'package:cloud_firestore/cloud_firestore.dart';

import 'storybook.dart' show kDefaultChapter;

enum StoryMode { official, free, diary, essay, fanfic }

enum StoryVisibility { private, public }

/// 广场排序方式。
/// - [hotScore]：排行榜（依赖 T1.7 维护的 `hotScore` 字段）
/// - [newest]：按 `createdAt` 倒序
enum SquareSort { hotScore, newest }

/// `stories/{storyId}` 文档的强类型映射。
///
/// `likeCount` / `commentCount` / `hotScore` 由 Cloud Functions 维护，
/// 客户端禁写（T1.4 规则强制）。`toCreateMap` / `toUpdateMap` 都不写这三个字段。
class Story {
  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.mode,
    required this.challengeId,
    required this.words,
    required this.visibility,
    required this.publishedToSquare,
    required this.storybookId,
    required this.chapterName,
    required this.likeCount,
    required this.commentCount,
    required this.hotScore,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final StoryMode mode;
  final String? challengeId;
  final List<String>? words;
  final StoryVisibility visibility;
  final bool publishedToSquare;

  /// 所属故事书文档 ID（T6）。创建时由写作流补默认书 ID（非空）。
  final String storybookId;

  /// 所属章节名（T6）。未指定时为 [kDefaultChapter]（非空）。
  final String chapterName;

  final int likeCount;
  final int commentCount;
  final num hotScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Story.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Story(
      id: snap.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      mode: _parseMode(data['mode']),
      challengeId: data['challengeId'] as String?,
      words: (data['words'] as List?)
          ?.map((e) => e.toString())
          .toList(growable: false),
      visibility: _parseVisibility(data['visibility']),
      publishedToSquare: (data['publishedToSquare'] as bool?) ?? false,
      // 迁移前旧 story 无此两字段 → 防御性默认，保证渲染不崩（§1.1）。
      storybookId: (data['storybookId'] as String?) ?? '',
      chapterName: (data['chapterName'] as String?) ?? kDefaultChapter,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      hotScore: (data['hotScore'] as num?) ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 客户端 create 用的 payload。
  /// 不包含 `id` / CF-only 计数 / 服务端时间戳（由调用方在外层补 serverTimestamp）。
  Map<String, dynamic> toCreateMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'body': body,
      'mode': mode.name,
      if (challengeId != null) 'challengeId': challengeId,
      if (words != null) 'words': words,
      'visibility': visibility.name,
      'publishedToSquare': publishedToSquare,
      // 两字段非空必带（调用方在 create 前已补默认书/章节，§3.2 调用约定）。
      'storybookId': storybookId,
      'chapterName': chapterName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static StoryMode _parseMode(Object? raw) {
    final s = raw?.toString();
    return StoryMode.values.firstWhere(
      (m) => m.name == s,
      orElse: () => StoryMode.free,
    );
  }

  static StoryVisibility _parseVisibility(Object? raw) {
    final s = raw?.toString();
    return StoryVisibility.values.firstWhere(
      (v) => v.name == s,
      orElse: () => StoryVisibility.private,
    );
  }
}
