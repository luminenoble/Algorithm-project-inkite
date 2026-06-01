import 'package:flutter/material.dart';

import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/origami_service.dart';

/// F2：自由 AI 折纸入口卡片。
///
/// 用户必须填入 3 个关键词才能召唤——这 3 词会织进 Replicate prompt
/// 并随 origami 文档落库（`origami.words`），所以折纸藏品天然带「主题感」。
///
/// 实时展示用户本周 AI 配额状态（读 `users/{uid}.aiUsage`），bonus 锁定态
/// chip 与剩余次数。
class AiOrigamiCard extends StatefulWidget {
  const AiOrigamiCard({super.key});

  @override
  State<AiOrigamiCard> createState() => _AiOrigamiCardState();
}

class _AiOrigamiCardState extends State<AiOrigamiCard> {
  static const int _maxWordLength = 16;

  final List<TextEditingController> _controllers =
      List.generate(3, (_) => TextEditingController());
  bool _summoning = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String>? _collectWords() {
    final words = _controllers
        .map((c) => c.text.trim())
        .toList(growable: false);
    if (words.any((w) => w.isEmpty)) {
      setState(() => _error = '请填满 3 个关键词');
      return null;
    }
    if (words.any((w) => w.length > _maxWordLength)) {
      setState(() => _error = '单个关键词不超过 $_maxWordLength 字');
      return null;
    }
    setState(() => _error = null);
    return words;
  }

  Future<void> _summon() async {
    if (_summoning) return;
    final words = _collectWords();
    if (words == null) return;

    setState(() => _summoning = true);
    try {
      final r = await OrigamiService.instance.generateAiFree(words: words);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '折纸已生成（${r.words.join(" · ")}） · 本周剩余 ${r.quotaLimit - r.quotaUsed}/${r.quotaLimit}',
          ),
        ),
      );
      // 清空输入框，方便下次召唤
      for (final c in _controllers) {
        c.clear();
      }
    } on CallableException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'resource-exhausted' => e.message,
        'invalid-argument' => e.message,
        'internal' => 'AI 生成失败，配额已退回',
        'unauthenticated' => '请先登录',
        _ => '生成失败：${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _summoning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, snap) {
        final profile = snap.data;
        if (profile == null) return const SizedBox.shrink();
        return _Card(
          controllers: _controllers,
          usage: profile.aiUsage,
          stats: profile.stats,
          summoning: _summoning,
          error: _error,
          onSummon: _summon,
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.controllers,
    required this.usage,
    required this.stats,
    required this.summoning,
    required this.error,
    required this.onSummon,
  });

  final List<TextEditingController> controllers;
  final UserAiUsage usage;
  final UserStats stats;
  final bool summoning;
  final String? error;
  final VoidCallback onSummon;

  static const int _baseQuota = 3;
  static const Duration _weekDuration = Duration(days: 7);

  ({int used, int limit, DateTime? expiresAt}) _resolveQuota() {
    final limit = _baseQuota +
        (usage.bonusLikes ? 1 : 0) +
        (usage.bonusChallenges ? 1 : 0);
    if (usage.weekStartAt == null) {
      return (used: 0, limit: limit, expiresAt: null);
    }
    final expiresAt = usage.weekStartAt!.add(_weekDuration);
    if (DateTime.now().isAfter(expiresAt)) {
      return (used: 0, limit: limit, expiresAt: null);
    }
    return (used: usage.count, limit: limit, expiresAt: expiresAt);
  }

  @override
  Widget build(BuildContext context) {
    final q = _resolveQuota();
    final remaining = q.limit - q.used;
    final exhausted = remaining <= 0;
    final canSummon = !summoning && !exhausted;

    return Card(
      color: const Color(0xFFFBF8F0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFB8893A), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_fix_high,
                    color: Color(0xFFB8893A), size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 折纸召唤',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B2622),
                      ),
                ),
                const Spacer(),
                _QuotaPill(used: q.used, limit: q.limit),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exhausted
                  ? '本周配额已用完，${q.expiresAt == null ? "可立即重置" : _expiresText(q.expiresAt!)}'
                  : '写下三个关键词，AI 会把它们织进折纸里',
              style: TextStyle(
                fontSize: 13,
                color: exhausted
                    ? const Color(0xFF9A2D1F)
                    : const Color(0xFF6B6258),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            _WordInputs(
              controllers: controllers,
              enabled: canSummon,
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A2D1F),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _BonusRow(usage: usage, stats: stats),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: canSummon ? onSummon : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB8893A),
                    disabledBackgroundColor: const Color(0xFFC9C0B2),
                  ),
                  icon: summoning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(summoning ? '召唤中…' : '召唤折纸'),
                ),
                const SizedBox(width: 12),
                if (!exhausted)
                  Text(
                    '剩余 $remaining 次',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6258),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _expiresText(DateTime t) {
    final diff = t.difference(DateTime.now());
    if (diff.inDays >= 1) return '${diff.inDays} 天后重置';
    if (diff.inHours >= 1) return '${diff.inHours} 小时后重置';
    return '${diff.inMinutes} 分钟后重置';
  }
}

class _WordInputs extends StatelessWidget {
  const _WordInputs({required this.controllers, required this.enabled});

  final List<TextEditingController> controllers;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: TextField(
              controller: controllers[i],
              enabled: enabled,
              maxLength: 16,
              decoration: InputDecoration(
                hintText: '词 ${i + 1}',
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFC9C0B2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFC9C0B2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFB8893A)),
                ),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFB8893A).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$used / $limit',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB8893A),
        ),
      ),
    );
  }
}

/// 显示 bonus 解锁状态：likes>20 +1 / 5 篇官方 +1
class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.usage, required this.stats});

  final UserAiUsage usage;
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _BonusChip(
          unlocked: usage.bonusLikes,
          unlockedText: '已获 20 赞 · +1 配额',
          lockedText: '点赞 ${stats.likesReceived}/20',
        ),
        _BonusChip(
          unlocked: usage.bonusChallenges,
          unlockedText: '5 篇官方挑战 · +1 配额',
          lockedText: '官方挑战 ${stats.officialChallengesCount}/5',
        ),
      ],
    );
  }
}

class _BonusChip extends StatelessWidget {
  const _BonusChip({
    required this.unlocked,
    required this.unlockedText,
    required this.lockedText,
  });

  final bool unlocked;
  final String unlockedText;
  final String lockedText;

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? const Color(0xFFB8893A)
        : const Color(0xFFC9C0B2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFFB8893A).withValues(alpha: 0.10)
            : const Color(0xFFF5F1E8),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            unlocked ? unlockedText : lockedText,
            style: TextStyle(
              fontSize: 11,
              color: unlocked
                  ? const Color(0xFF2B2622)
                  : const Color(0xFF6B6258),
              fontWeight: unlocked ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
