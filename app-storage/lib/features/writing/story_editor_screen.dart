import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/models/storybook.dart';
import '../../data/repositories/story_repository.dart';
import '../../data/repositories/storybook_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/origami_service.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/paper_bird_overlay.dart';
import '../common/magic_ink.dart';

/// 故事编辑器页面。
///
/// 通过 GoRouter extra 传入参数（互斥两类）：
///
/// **新建模式：**
/// - `mode`: 'official' | 'free' | 'diary' | 'essay' | 'fanfic'
/// - `challengeId`: (official) 挑战 ID
/// - `words`: (official) 三词快照
/// - `inspirationWords`: (free 随机词) 灵感词，仅 UI 显示不入库
///
/// **编辑模式：**
/// - `storyId`: 既有故事 ID → 拉取并预填，提交走 `update`
///
/// **故事书归属（T6，所有模式可选）：**
/// - `storybookId` / `chapterName`: 新故事直接落入指定故事书/章节；缺省落默认书。
/// - `fromStorybook`: 从某故事书内部屏进来；保存/返回时回到该屏。
class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late StoryMode _mode;
  String? _challengeId;
  List<String>? _words;
  List<String>? _inspirationWords;
  String? _editingStoryId;

  /// T6：故事所属故事书 / 章节。新建时由 extra 指定或落默认书（_submit 内补齐）；
  /// 编辑时从既有 story 读出。保存后用于 `StorybookRepository.touch`。
  String? _storybookId;
  String? _chapterName;

  /// 从某故事书内部屏进入时记下，保存/返回时回到该屏。
  String? _returnStorybookId;

  bool _loading = false;
  bool _submitting = false;

  bool get _isEditMode => _editingStoryId != null;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra ?? {};
    _editingStoryId = extra['storyId'] as String?;
    _returnStorybookId = extra['fromStorybook'] as String?;

    if (_isEditMode) {
      _mode = StoryMode.free;
      _loading = true;
      _loadExisting();
    } else {
      _mode = _parseMode(extra['mode']);
      _challengeId = extra['challengeId'] as String?;
      _words = (extra['words'] as List?)?.cast<String>();
      _inspirationWords = (extra['inspirationWords'] as List?)?.cast<String>();
      _storybookId = extra['storybookId'] as String?;
      _chapterName = extra['chapterName'] as String?;
    }
  }

  Future<void> _loadExisting() async {
    try {
      final story = await StoryRepository.instance.getById(_editingStoryId!);
      if (!mounted) return;
      if (story == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('故事不存在或已删除')),
        );
        context.go(_destination());
        return;
      }
      setState(() {
        _titleController.text = story.title;
        _bodyController.text = story.body;
        _mode = story.mode;
        _challengeId = story.challengeId;
        _words = story.words;
        _storybookId = story.storybookId;
        _chapterName = story.chapterName;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败：$e')),
      );
      setState(() => _loading = false);
    }
  }

  StoryMode _parseMode(Object? raw) {
    final s = raw?.toString();
    return StoryMode.values.firstWhere(
      (m) => m.name == s,
      orElse: () => StoryMode.free,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    // 折纸动效（§6）：发布 → 纸鸟飞向广场方向；保存 → 纸张合拢印记。
    // 与异步写库并行，先给即时反馈；动效级别非 full 时内部自动跳过。
    if (publish) {
      launchPaperBird(context);
    } else {
      playPaperFold(context, label: '已保存');
    }

    setState(() => _submitting = true);

    try {
      if (_isEditMode) {
        await StoryRepository.instance.update(
          _editingStoryId!,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          visibility:
              publish ? StoryVisibility.public : StoryVisibility.private,
          publishedToSquare: publish,
        );
      } else {
        final uid = AuthService.instance.currentUid!;
        final profile = await UserRepository.instance.getProfile(uid);
        final authorName = profile?.displayName ?? '';

        // 未指定故事书 → 落该用户默认书（惰性创建，§3.2 调用约定）。
        if (_storybookId == null || _storybookId!.isEmpty) {
          final defaultBook =
              await StorybookRepository.instance.getOrCreateDefault(uid);
          _storybookId = defaultBook.id;
        }
        _chapterName ??= kDefaultChapter;

        final story = Story(
          id: '',
          authorId: uid,
          authorName: authorName,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          mode: _mode,
          challengeId: _challengeId,
          words: _words,
          visibility:
              publish ? StoryVisibility.public : StoryVisibility.private,
          publishedToSquare: publish,
          storybookId: _storybookId!,
          chapterName: _chapterName!,
          likeCount: 0,
          commentCount: 0,
          hotScore: 0,
          createdAt: null,
          updatedAt: null,
        );

        await StoryRepository.instance.create(story);
      }

      // 刷新故事书 updatedAt，让总览「修改时间排序」准确（§3.2 调用约定）。
      final touchId = _storybookId;
      if (touchId != null && touchId.isNotEmpty) {
        // ignore: discarded_futures
        StorybookRepository.instance.touch(touchId);
      }

      // T4.2：官方挑战发布成功 → fire-and-forget 调 generateOrigami。
      // CF 幂等保证重复发布不会刷出第二件折纸；失败仅日志，不影响发布主流程。
      final triggerOrigami =
          publish && _mode == StoryMode.official && _challengeId != null;
      if (triggerOrigami) {
        // §6.2 step5：官方挑战发布串接金箔奖励鸟，飞向展览厅方向。
        if (mounted) {
          launchPaperBird(context, color: context.skin.goldLeaf);
        }
        // ignore: discarded_futures
        OrigamiService.instance.generate(challengeId: _challengeId!).then(
          (r) => debugPrint(
              '[T4.2] origami unlocked: id=${r.origamiId} style=${r.style} source=${r.source}'),
          onError: (Object e) =>
              debugPrint('[T4.2] origami generation failed: $e'),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish
                ? (triggerOrigami
                    ? '已发布到广场 · 折纸藏品已发放，去展览厅看看'
                    : '已发布到广场')
                : '草稿已保存',
          ),
        ),
      );
      context.go(_destination());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 返回 / 保存后的去向：
  /// - 从某故事书内部屏进来 → 回该屏；
  /// - 编辑既有故事 → 回故事书总览；
  /// - 落地页新建 → 回写作落地页。
  String _destination() {
    final from = _returnStorybookId;
    if (from != null && from.isNotEmpty) return '/writing/storybooks/$from';
    return _isEditMode ? '/writing/storybooks' : '/writing';
  }

  @override
  Widget build(BuildContext context) {
    final backRoute = _destination();
    final title = _isEditMode
        ? '编辑故事'
        : (_mode == StoryMode.official ? '官方挑战' : '自由创作');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backRoute),
        ),
        title: Text(title),
        actions: [
          const MagicInkChip(),
          TextButton(
            onPressed: (_submitting || _loading)
                ? null
                : () => _submit(publish: false),
            child: const Text('保存草稿'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: (_submitting || _loading)
                ? null
                : () => _submit(publish: true),
            child: const Text('发布'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: (_loading || _submitting)
          ? const Center(child: BrushLoading())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_words != null && _words!.isNotEmpty) ...[
                    _ChallengeWordsBar(words: _words!),
                    const SizedBox(height: 16),
                  ],
                  if (_inspirationWords != null &&
                      _inspirationWords!.isNotEmpty) ...[
                    _InspirationWordsBar(words: _inspirationWords!),
                    const SizedBox(height: 16),
                  ],
                  _ModeSelector(
                    mode: _mode,
                    locked: _mode == StoryMode.official,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '给你的故事起个名字',
                    ),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w500),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: '正文',
                      hintText: '开始你的故事……',
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    minLines: 12,
                    style: const TextStyle(fontSize: 16, height: 1.75),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入正文' : null,
                  ),
                ],
              ),
            ),
    );
  }
}

/// 随机词灵感提示栏（不入库，仅写作时参考）。
class _InspirationWordsBar extends StatelessWidget {
  const _InspirationWordsBar({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.paperShade),
      ),
      child: Row(
        children: [
          Icon(Icons.shuffle, size: 20, color: skin.inkSecondary),
          const SizedBox(width: 12),
          Text('灵感词：',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: words
                  .map((w) => Text(
                        w,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: skin.inkPrimary,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 官方挑战三词提示栏。
class _ChallengeWordsBar extends StatelessWidget {
  const _ChallengeWordsBar({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: skin.paperBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.paperShade),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: skin.accentSeal),
          const SizedBox(width: 12),
          Text('挑战词：',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          ...words.map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(w,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  visualDensity: VisualDensity.compact,
                ),
              )),
        ],
      ),
    );
  }
}

/// 故事模式选择器。
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.locked,
    required this.onChanged,
  });

  final StoryMode mode;
  final bool locked;
  final ValueChanged<StoryMode> onChanged;

  static const _labels = {
    StoryMode.official: '官方挑战',
    StoryMode.free: '自由',
    StoryMode.diary: '日记',
    StoryMode.essay: '随笔',
    StoryMode.fanfic: '同人',
  };

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Row(
        children: [
          Text('模式：', style: Theme.of(context).textTheme.bodyMedium),
          Chip(label: Text(_labels[mode] ?? mode.name)),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('模式：', style: Theme.of(context).textTheme.bodyMedium),
        for (final entry in _labels.entries)
          if (entry.key != StoryMode.official)
            ChoiceChip(
              label: Text(entry.value),
              selected: mode == entry.key,
              onSelected: (selected) {
                if (selected) onChanged(entry.key);
              },
            ),
      ],
    );
  }
}
