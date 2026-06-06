import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../data/models/storybook.dart';
import '../../../data/repositories/storybook_repository.dart';
import '../../../services/functions_client.dart';
import '../../../services/storybook_service.dart';
import '../../../theme/skin_controller.dart';
import '../storybook_covers.dart';

/// 换封面入口（`docs/next-design-detailed.md` §5.4）。两种来源统一一处：
/// - **选内置预设**：即时 `setCoverAsset`（纯前端写 `coverAssetId`）。
/// - **上传自定义**：选本地图片 → 经 CF 写 Storage → 回写 `coverUrl`。
///
/// 守 `CLAUDE.md` §7：自定义上传只经 `uploadStorybookCover` CF，绝不直连 Storage。
Future<void> showCoverPicker(BuildContext context, Storybook book) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _CoverPickerSheet(book: book),
  );
}

class _CoverPickerSheet extends StatefulWidget {
  const _CoverPickerSheet({required this.book});
  final Storybook book;

  @override
  State<_CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<_CoverPickerSheet> {
  bool _uploading = false;

  Future<void> _pickPreset(CoverPreset preset) async {
    try {
      await StorybookRepository.instance
          .setCoverAsset(widget.book.id, preset.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('换封面失败：$e')));
    }
  }

  Future<void> _uploadCustom() async {
    if (_uploading) return;
    const group = XTypeGroup(
      label: '图片',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > StorybookService.maxCoverBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('封面图过大，请选 1MB 以内的图片')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await StorybookService.instance.uploadCover(
        widget.book.id,
        bytes,
        contentType: _contentTypeOf(file),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('封面已更新')));
    } on CallableException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'permission-denied' => '只能给自己的故事书换封面',
        'invalid-argument' => e.message,
        _ => '上传失败：${e.message}',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上传失败：$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _contentTypeOf(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('换封面', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '选一张内置预设，或上传自己的图片（≤1MB）',
              style: TextStyle(fontSize: 12, color: skin.inkSecondary),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                for (final preset in kCoverPresets)
                  _PresetTile(
                    preset: preset,
                    selected: widget.book.coverUrl == null &&
                        widget.book.coverAssetId == preset.id,
                    onTap: () => _pickPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadCustom,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(_uploading ? '上传中…' : '上传自定义封面'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final CoverPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? skin.accentVermilion : skin.paperShade,
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CoverPresetView(preset: preset),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preset.label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? skin.accentVermilion : skin.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
