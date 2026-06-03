import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/gallery/zen_garden_screen.dart';
import '../features/me/me_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/square/rank_screen.dart';
import '../features/square/square_screen.dart';
import '../features/square/story_detail_screen.dart';
import '../features/writing/challenge_stories_screen.dart';
import '../features/writing/my_stories_screen.dart';
import '../features/writing/random_words_screen.dart';
import '../features/writing/story_editor_screen.dart';
import '../features/writing/writing_screen.dart';
import '../services/auth_service.dart';
import 'fold_transition.dart';

/// 路由守卫：未登录跳 /login，已登录在 /login 时跳回 /writing。
String? _redirect(BuildContext context, GoRouterState state) {
  final loggedIn = AuthService.instance.currentUser != null;
  final goingToLogin = state.matchedLocation == '/login';
  if (!loggedIn && !goingToLogin) return '/login';
  if (loggedIn && goingToLogin) return '/writing';
  return null;
}

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthRefresh(),
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        // Tab 级路由：翻页方向由 MainShell 按 Tab 索引差设定（foldDirection）。
        GoRoute(
          path: '/writing',
          pageBuilder: (_, state) => foldPage(state, const WritingScreen()),
          routes: [
            // 子页一律前进向翻书折叠（§3.3）。
            GoRoute(
              path: 'editor',
              pageBuilder: (_, state) => foldPage(
                state,
                StoryEditorScreen(extra: state.extra as Map<String, dynamic>?),
                direction: FoldDirection.forward,
              ),
            ),
            GoRoute(
              path: 'challenge/:id',
              pageBuilder: (_, state) => foldPage(
                state,
                ChallengeStoriesScreen(
                    challengeId: state.pathParameters['id']!),
                direction: FoldDirection.forward,
              ),
            ),
            GoRoute(
              path: 'random',
              pageBuilder: (_, state) =>
                  foldPage(state, const RandomWordsScreen(),
                      direction: FoldDirection.forward),
            ),
            GoRoute(
              path: 'mine',
              pageBuilder: (_, state) => foldPage(state, const MyStoriesScreen(),
                  direction: FoldDirection.forward),
            ),
          ],
        ),
        GoRoute(
          path: '/square',
          pageBuilder: (_, state) => foldPage(state, const SquareScreen()),
          routes: [
            GoRoute(
              path: 'story/:id',
              pageBuilder: (_, state) => foldPage(
                state,
                StoryDetailScreen(storyId: state.pathParameters['id']!),
                direction: FoldDirection.forward,
              ),
            ),
            GoRoute(
              path: 'rank',
              pageBuilder: (_, state) => foldPage(state, const RankScreen(),
                  direction: FoldDirection.forward),
            ),
          ],
        ),
        GoRoute(
          path: '/gallery',
          pageBuilder: (_, state) => foldPage(state, const GalleryScreen()),
          routes: [
            GoRoute(
              path: 'room/zen-garden',
              pageBuilder: (_, state) => foldPage(state, const ZenGardenScreen(),
                  direction: FoldDirection.forward),
            ),
          ],
        ),
        GoRoute(
          path: '/me',
          pageBuilder: (_, state) => foldPage(state, const MeScreen()),
        ),
      ],
    ),
  ],
);

/// 把 AuthService.authStateChanges 桥接到 GoRouter 的 refreshListenable。
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    AuthService.instance.authStateChanges.listen((_) => notifyListeners());
  }
}
