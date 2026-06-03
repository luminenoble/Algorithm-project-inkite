import '../theme/ink_skin.dart';
import '../theme/paper_skin.dart';
import 'models/story.dart';
import 'models/user_profile.dart';

/// 把一组词语归一化成可比较的 key：去空白、转小写、排序后拼接。
///
/// 顺序无关——「松/月/石」与「石/松/月」视为同一组。
String wordKey(Iterable<String> words) {
  final norm = words
      .map((w) => w.trim().toLowerCase())
      .where((w) => w.isNotEmpty)
      .toList()
    ..sort();
  return norm.join('');
}

/// 词语绑定解锁的判定器（`docs/fronted/unlock-halls.plan.md`）。
///
/// **纯客户端只读派生**：由用户自己「已发布」故事的 `words` 快照算出解锁集，
/// 配合旧的 CF 旗标（`unlocks.magicInk` / `unlocks.rooms`）做 OR 兼容。
/// 不读写 `unlocks.*`（规则 CF-only 字段），零越权。
class UnlockResolver {
  UnlockResolver({
    required this.publishedSubwords,
    required this.magicInkFlag,
    required this.unlockedRooms,
  });

  /// 用户已发布故事中出现过的所有「单词」（已归一化）。
  /// 奖励的 `unlockWords` 全部落在此集合中即算命中。
  final Set<String> publishedSubwords;

  /// 旧旗标：`users.unlocks.magicInk`（互动分阈值，CF 维护）。
  final bool magicInkFlag;

  /// 旧旗标：`users.unlocks.rooms`（完成官方挑战 push，CF 维护）。
  final List<String> unlockedRooms;

  /// 从「我的故事」+ 用户档案构造。仅统计 `publishedToSquare == true` 的故事。
  factory UnlockResolver.from({
    required List<Story> myStories,
    required UserProfile? profile,
  }) {
    final subwords = <String>{};
    for (final s in myStories) {
      if (s.publishedToSquare != true) continue;
      final ws = s.words;
      if (ws == null) continue;
      for (final w in ws) {
        final n = w.trim().toLowerCase();
        if (n.isNotEmpty) subwords.add(n);
      }
    }
    return UnlockResolver(
      publishedSubwords: subwords,
      magicInkFlag: profile?.unlocks.magicInk ?? false,
      unlockedRooms: profile?.unlocks.rooms ?? const [],
    );
  }

  /// 词语条件是否满足：[unlockWords] 全部出现在已发布故事的词里。
  /// [unlockWords] 为空/null = 免费，恒解锁。
  bool wordsSatisfied(List<String>? unlockWords) {
    if (unlockWords == null || unlockWords.isEmpty) return true;
    for (final w in unlockWords) {
      final n = w.trim().toLowerCase();
      if (n.isEmpty) continue;
      if (!publishedSubwords.contains(n)) return false;
    }
    return true;
  }

  /// 纸张皮肤是否解锁（默认/免费纸恒解锁）。
  bool paperUnlocked(PaperSkin p) => wordsSatisfied(p.unlockWords);

  /// 墨水皮肤是否解锁。魔法墨水（渐变笔触）另认旧 `magicInk` 旗标（OR）。
  bool inkUnlocked(InkSkin i) {
    if (wordsSatisfied(i.unlockWords)) return true;
    if (i.strokeEffect == InkStrokeEffect.gradient && magicInkFlag) return true;
    return false;
  }
}
