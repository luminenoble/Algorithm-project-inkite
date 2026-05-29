import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部 Tab 主框架。包裹 4 个核心 Tab 的导航。
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabSpec>[
    _TabSpec('/writing', '写作', Icons.edit_note_outlined, Icons.edit_note),
    _TabSpec('/square', '广场', Icons.public_outlined, Icons.public),
    _TabSpec('/gallery', '展览厅', Icons.collections_outlined, Icons.collections),
    _TabSpec('/me', '我的', Icons.person_outline, Icons.person),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
