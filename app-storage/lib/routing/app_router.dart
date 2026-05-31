import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/gallery/gallery_screen.dart';
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
        GoRoute(
          path: '/writing',
          builder: (_, _) => const WritingScreen(),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (_, state) => StoryEditorScreen(
                extra: state.extra as Map<String, dynamic>?,
              ),
            ),
            GoRoute(
              path: 'challenge/:id',
              builder: (_, state) => ChallengeStoriesScreen(
                challengeId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'random',
              builder: (_, _) => const RandomWordsScreen(),
            ),
            GoRoute(
              path: 'mine',
              builder: (_, _) => const MyStoriesScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/square',
          builder: (_, _) => const SquareScreen(),
          routes: [
            GoRoute(
              path: 'story/:id',
              builder: (_, state) => StoryDetailScreen(
                storyId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'rank',
              builder: (_, _) => const RankScreen(),
            ),
          ],
        ),
        GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
        GoRoute(path: '/me', builder: (_, _) => const MeScreen()),
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
