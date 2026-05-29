import 'package:flutter/material.dart';

/// 模块 G — 角色查询（Wikipedia + Reddit 聚合）。
/// 已完成的查询系统由 P4 在阶段 2 集成嵌入；这里只占位以确认目录约定。
class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('角色查询')),
      body: const Center(child: Text('角色查询 (模块 G — 由 P4 嵌入)')),
    );
  }
}
