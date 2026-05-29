// 占位 widget 测试。完整的端到端验证由 T1.5 (Auth) 与各模块 owner 补齐。
//
// 不直接 pumpWidget(InkiteApp) 是因为 main() 会调用 Firebase.initializeApp，
// 而单元测试环境下没有 firebase_options.dart 真实配置。后续可在测试中
// mock FirebaseAuth / FirebaseFirestore，或单独测每个 Screen Widget。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: trivial widget renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('inkite'))),
    );
    expect(find.text('inkite'), findsOneWidget);
  });
}
