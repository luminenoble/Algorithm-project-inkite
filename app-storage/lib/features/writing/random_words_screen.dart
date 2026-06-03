import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/skin_controller.dart';
import 'random_words.dart';

/// 自由创作随机词生成器。
///
/// - 本地词库 [kRandomWordPool] 随机抽 1–3 词
/// - "换一批" 刷新；"用这些词写" → 跳编辑器（`mode=free` + inspirationWords 提示）
/// - 随机词本身不入库（schema §设计原则 5）
class RandomWordsScreen extends StatefulWidget {
  const RandomWordsScreen({super.key});

  @override
  State<RandomWordsScreen> createState() => _RandomWordsScreenState();
}

class _RandomWordsScreenState extends State<RandomWordsScreen> {
  static const _maxWords = 3;
  int _wordCount = 3;
  late List<String> _picked;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _picked = _pickWords(_wordCount);
  }

  List<String> _pickWords(int n) {
    final pool = List<String>.from(kRandomWordPool)..shuffle(_rng);
    return pool.take(n).toList(growable: false);
  }

  void _reshuffle() {
    setState(() => _picked = _pickWords(_wordCount));
  }

  void _changeCount(int n) {
    setState(() {
      _wordCount = n;
      _picked = _pickWords(n);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/writing'),
        ),
        title: const Text('随机词灵感'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('词数', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var n = 1; n <= _maxWords; n++)
                  ChoiceChip(
                    label: Text('$n 词'),
                    selected: _wordCount == n,
                    onSelected: (sel) {
                      if (sel) _changeCount(n);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _picked
                      .map((w) => _WordCard(word: w))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reshuffle,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('换一批'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/writing/editor', extra: {
                      'mode': 'free',
                      'inspirationWords': _picked,
                    }),
                    icon: const Icon(Icons.edit),
                    label: const Text('用这些词写'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.paperShade, width: 1.5),
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: skin.inkPrimary,
        ),
      ),
    );
  }
}
