import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/character_cache.dart';
import '../../data/repositories/characters_cache_repository.dart';
import '../../theme/design_tokens.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import 'widgets/character_badge.dart';

/// 角色详情页 `/explore/character/:key`。
///
/// 用 `watchByKey` 拿实时文档（虽只读，stream 与其他详情页风格一致）。
/// 分「官方权威」（wikiSummary + 外链）与「民间二创」（redditPosts）两区块，
/// source/tag 徽标按 ISR 光谱语义配色（角色查询-todo §5.2）。
class CharacterDetailScreen extends StatelessWidget {
  const CharacterDetailScreen({super.key, required this.characterKey});

  final String characterKey;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/explore'),
        ),
        title: const Text('角色'),
      ),
      body: StreamBuilder<CharacterCache?>(
        stream: CharactersCacheRepository.instance.watchByKey(characterKey),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: BrushLoading());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败：${snap.error}',
                    style: TextStyle(color: skin.accentSeal)),
              ),
            );
          }
          final c = snap.data;
          if (c == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('角色不存在或未收录',
                    style: TextStyle(color: skin.inkSecondary)),
              ),
            );
          }
          return _DetailBody(character: c);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.character});
  final CharacterCache character;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final c = character;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          c.name.isEmpty ? '（无名）' : c.name,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: skin.inkPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (c.source.isNotEmpty) CharacterBadge.source(context, c.source),
            if (c.tag.isNotEmpty) CharacterBadge.tag(context, c.tag),
            if (c.obscurity > 0)
              Text(
                '冷门度 ${c.obscurity.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: skin.inkSecondary),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          icon: OrigamiGlyph.seal,
          color: skin.accentVermilion,
          text: '官方权威',
        ),
        const SizedBox(height: 10),
        if (c.wikiSummary.isNotEmpty)
          SelectableText(
            c.wikiSummary,
            style:
                TextStyle(fontSize: 15, height: 1.75, color: skin.inkPrimary),
          )
        else
          Text('暂无官方摘要',
              style: TextStyle(fontSize: 14, color: skin.inkSecondary)),
        if (c.wikiUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LinkButton(label: '查看官方条目', url: c.wikiUrl),
        ],
        if (c.redditPosts.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle(
            icon: OrigamiGlyph.bird,
            color: skin.inkSecondary,
            text: '民间二创',
          ),
          const SizedBox(height: 10),
          for (final post in c.redditPosts) _RedditPostTile(post: post),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.icon, required this.color, required this.text});
  final OrigamiGlyph icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      children: [
        OrigamiIcon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.inkPrimary,
          ),
        ),
      ],
    );
  }
}

class _RedditPostTile extends StatelessWidget {
  const _RedditPostTile({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final title = (post['title'] as String?)?.trim() ?? '';
    final snippet = (post['snippet'] as String?)?.trim() ?? '';
    final url = (post['url'] as String?)?.trim() ?? '';
    final source = (post['source'] as String?)?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.surfaceCard,
        border: Border.all(color: skin.inkFaint),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (source.isNotEmpty) ...[
                CharacterBadge.source(context, source),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.isEmpty ? '（无标题）' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: skin.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (snippet.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 13, height: 1.5, color: skin.inkSecondary),
            ),
          ],
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            _LinkButton(label: '阅读原帖', url: url),
          ],
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});
  final String label;
  final String url;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _open(context),
        icon: Icon(Icons.open_in_new, size: 16, color: skin.accentVermilion),
        label: Text(label, style: TextStyle(color: skin.accentVermilion)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
