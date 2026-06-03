import 'package:flutter/material.dart';

import '../../../data/unlock_state.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/origami_icon.dart';
import '../../../widgets/origami_icons.dart';
import '../hall.dart';

/// 展馆切换器：横向 chips。选中描朱砂，锁定显锁形。
///
/// 点锁定馆给 SnackBar 提示所需三词，不切换。
class HallSwitcher extends StatelessWidget {
  const HallSwitcher({
    super.key,
    required this.resolver,
    required this.selectedId,
    required this.onSelect,
  });

  final UnlockResolver resolver;
  final String selectedId;
  final ValueChanged<GalleryHall> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final hall in galleryHalls)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _HallChip(
                hall: hall,
                selected: hall.id == selectedId,
                unlocked: hall.unlockedBy(resolver),
                onTap: () {
                  if (!hall.unlockedBy(resolver)) {
                    final words = hall.unlockWords?.join(' / ') ?? '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('「$words」—— 以这三词发布官方故事即可解锁')),
                    );
                    return;
                  }
                  onSelect(hall);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HallChip extends StatelessWidget {
  const _HallChip({
    required this.hall,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final GalleryHall hall;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final accent = skin.accentVermilion;
    final Color border = selected ? accent : skin.inkFaint;
    final Color fg = !unlocked
        ? skin.inkFaint
        : (selected ? accent : skin.inkPrimary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : skin.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(
              unlocked ? hall.glyph : OrigamiGlyph.lock,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              hall.name,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
