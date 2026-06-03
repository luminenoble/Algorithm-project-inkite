import '../../data/models/origami.dart';
import '../../data/unlock_state.dart';
import '../../widgets/origami_icons.dart';

/// 展馆（`docs/fronted/unlock-halls.plan.md`）。
///
/// - 默认展馆 [GalleryHall.all]：恒解锁，展示全部折纸。
/// - 主题展馆：按 [Origami.style] 过滤，词语解锁；禅意阁另认旧 `rooms` 旗标（OR）。
class GalleryHall {
  const GalleryHall({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.glyph,
    this.style,
    this.unlockWords,
    this.legacyRoomId,
    this.isDefault = false,
  });

  /// 唯一标识（与折纸 style 对齐，如 `zen` / `steampunk` / `ink`；默认馆为 `all`）。
  final String id;
  final String name;
  final String subtitle;
  final OrigamiGlyph glyph;

  /// 过滤用的折纸 style；null = 不过滤（默认馆展示全部）。
  final String? style;

  /// 解锁绑定的三个官方词语（null = 免费/默认馆）。
  final List<String>? unlockWords;

  /// 旧 CF 旗标兼容：`users.unlocks.rooms` 含此 ID 也算解锁。
  final String? legacyRoomId;

  final bool isDefault;

  /// 该折纸是否属于本展馆。默认馆收纳全部。
  bool accepts(Origami o) => style == null || o.style == style;

  /// 是否解锁：词语命中 OR（如有）旧 rooms 旗标。
  bool unlockedBy(UnlockResolver r) {
    if (isDefault) return true;
    if (r.wordsSatisfied(unlockWords)) return true;
    final room = legacyRoomId;
    if (room != null && r.unlockedRooms.contains(room)) return true;
    return false;
  }
}

/// 展馆目录（单一事实来源；词表见计划 §1）。
const galleryHalls = <GalleryHall>[
  GalleryHall(
    id: 'all',
    name: '默认展馆',
    subtitle: '全部折纸藏品',
    glyph: OrigamiGlyph.box,
    isDefault: true,
  ),
  GalleryHall(
    id: 'zen',
    name: '禅意阁',
    subtitle: '松 · 月 · 石',
    glyph: OrigamiGlyph.bird,
    style: 'zen',
    unlockWords: ['松', '月', '石'],
    legacyRoomId: 'zen_garden',
  ),
  GalleryHall(
    id: 'steampunk',
    name: '机关坊',
    subtitle: '齿轮 · 黄铜 · 蒸汽',
    glyph: OrigamiGlyph.lens,
    style: 'steampunk',
    unlockWords: ['齿轮', '黄铜', '蒸汽'],
  ),
  GalleryHall(
    id: 'ink',
    name: '水墨轩',
    subtitle: '云 · 雨 · 远山',
    glyph: OrigamiGlyph.pen,
    style: 'ink',
    unlockWords: ['云', '雨', '远山'],
  ),
];
