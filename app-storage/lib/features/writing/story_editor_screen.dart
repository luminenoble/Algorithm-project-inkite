import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/origami_service.dart';
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
  bool _loading = false;
  bool _submitting = false;

  bool get _isEditMode => _editingStoryId != null;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra ?? {};
    _editingStoryId = extra['storyId'] as String?;

    if (_isEditMode) {
      _mode = StoryMode.free;
      _loading = true;
      _loadExisting();
    } else {
      _mode = _parseMode(extra['mode']);
      _challengeId = extra['challengeId'] as String?;
      _words = (extra['words'] as List?)?.cast<String>();
      _inspirationWords =
          (extra['inspirationWords'] as List?)?.cast<String>();
    }
  }

  Future<void> _loadExisting() async {
    try {
      final story =
          await StoryRepository.instance.getById(_editingStoryId!);
      if (!mounted) return;
      if (story == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('故事不存在或已删除')),
        );
        context.go('/writing/mine');
        return;
      }
      setState(() {
        _titleController.text = story.title;
        _bodyController.text = story.body;
        _mode = story.mode;
        _challengeId = story.challengeId;
        _words = story.words;
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
          likeCount: 0,
          commentCount: 0,
          hotScore: 0,
          createdAt: null,
          updatedAt: null,
        );

        await StoryRepository.instance.create(story);
      }

      // T4.2：官方挑战发布成功 → fire-and-forget 调 generateOrigami。
      // CF 幂等保证重复发布不会刷出第二件折纸；失败仅日志，不影响发布主流程。
      final triggerOrigami = publish &&
          _mode == StoryMode.official &&
          _challengeId != null;
      if (triggerOrigami) {
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
      context.go(_isEditMode ? '/writing/mine' : '/writing');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backRoute = _isEditMode ? '/writing/mine' : '/writing';
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
          ? const Center(child: CircularProgressIndicator())
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
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: '正文',
                      hintText: '开始你的故事……',
                      border: OutlineInputBorder(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E0D0), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          const Icon(Icons.shuffle, size: 20, color: Color(0xFF6B6258)),
          const SizedBox(width: 12),
          Text(
            '灵感词：',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B6258),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: words
                  .map((w) => Text(
                        w,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B2622),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E0D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF9A2D1F)),
          const SizedBox(width: 12),
          Text(
            '挑战词：',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B6258),
            ),
          ),
          const SizedBox(width: 8),
          ...words.map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(w, style: const TextStyle(fontWeight: FontWeight.w600)),
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
