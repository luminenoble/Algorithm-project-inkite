import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/character_cache.dart';
import '../../data/repositories/characters_cache_repository.dart';
import '../../theme/design_tokens.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import 'widgets/character_badge.dart';

/// 「开拓」栏落地页：角色卡检索（方案 A，纯 Firestore 只读）。
///
/// 空查询展示 `listPopular` 默认热门角色；输入即（去抖后）调 `searchByName`
/// 前缀匹配。三态：加载中（毛笔 loading）/ 空结果（空态留白纸）/ 有结果列表。
/// 点卡片 → `/explore/character/:key`（角色查询-todo §5.1）。
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  final _repo = CharactersCacheRepository.instance;

  Timer? _debounce;
  String _query = '';
  late Future<List<CharacterCache>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listPopular();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      final q = value.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _future = q.isEmpty ? _repo.listPopular() : _repo.searchByName(q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final searching = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('开拓')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜角色名（如 hu tao / 钟离）',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: OrigamiIcon(OrigamiGlyph.lens,
                      size: 20, color: skin.inkSecondary),
                ),
                suffixIcon: searching
                    ? IconButton(
                        icon: Icon(Icons.close, color: skin.inkSecondary),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: skin.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusButton),
                  borderSide: BorderSide(color: skin.inkFaint),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusButton),
                  borderSide: BorderSide(color: skin.inkFaint),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusButton),
                  borderSide: BorderSide(color: skin.accentVermilion),
                ),
              ),
            ),
          ),
          if (!searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  OrigamiIcon(OrigamiGlyph.seal, size: 14, color: skin.goldLeaf),
                  const SizedBox(width: 6),
                  Text('热门角色',
                      style: TextStyle(fontSize: 13, color: skin.inkSecondary)),
                ],
              ),
            ),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final skin = context.skin;
    return FutureBuilder<List<CharacterCache>>(
      future: _future,
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
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return _Empty(searching: _query.isNotEmpty, query: _query);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _CharacterCard(character: list[i]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching, required this.query});
  final bool searching;
  final String query;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(OrigamiGlyph.emptyPaper, size: 56, color: skin.inkFaint),
            const SizedBox(height: 12),
            Text(
              searching
                  ? '没找到「$query」相关角色\n换个名字或试试英文名'
                  : '角色库还空着\n稍后再来开拓',
              textAlign: TextAlign.center,
              style: TextStyle(color: skin.inkSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character});
  final CharacterCache character;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final c = character;
    return Material(
      color: skin.surfaceCard,
      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        onTap: () => context.go('/explore/character/${c.key}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: skin.inkFaint),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name.isEmpty ? '（无名）' : c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: skin.inkPrimary,
                      ),
                    ),
                  ),
                  if (c.source.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    CharacterBadge.source(context, c.source),
                  ],
                  if (c.tag.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    CharacterBadge.tag(context, c.tag),
                  ],
                ],
              ),
              if (c.wikiSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  c.wikiSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: skin.inkSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
