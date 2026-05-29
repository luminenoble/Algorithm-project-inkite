import 'package:flutter/material.dart';

/// P4 展览厅占位。
/// AI 折纸藏品画廊、主题房间、魔法墨水。
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('展览厅')),
      body: const Center(child: Text('展览厅 (P4)')),
    );
  }
}
