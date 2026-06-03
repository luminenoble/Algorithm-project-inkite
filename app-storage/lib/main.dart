import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/skin_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SkinController.instance.load();
  runApp(const InkiteApp());
}

class InkiteApp extends StatelessWidget {
  const InkiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SkinController.instance;
    // SkinScope 下发当前皮肤；AnimatedBuilder 在切皮肤时重建 MaterialApp
    // 使整张 ThemeData 随之换装（折纸主题事实来源：docs/fronted-design.md §8）。
    return SkinScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp.router(
          title: 'Inkite',
          theme: AppTheme.from(controller.skin),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
