import 'package:flutter/widgets.dart';

import 'app_skin.dart';
import 'ink_skin.dart';
import 'motion.dart';
import 'paper_skin.dart';

/// 全局皮肤 + 动效级别状态（`docs/fronted-design.md` §7 / §8）。
///
/// **本版为内存态**，未做持久化——设计 §8.2 已明确「本版不必入 Firestore，
/// 跨端同步后续再说」。持久化 seam：日后接 `shared_preferences` 时，在 [load]
/// 读回、在 [_persist] 落地即可，其余调用方无需改动。
class SkinController extends ChangeNotifier {
  SkinController._();

  static final SkinController instance = SkinController._();

  AppSkin _skin = AppSkin.defaultSkin;
  // 默认 off：转场动画默认关闭（翻书折叠在 debug 下卡顿）。完整折纸动效仍保留，
  // 在「我的」页切 full 即可启用（建议 release/profile 构建下验证流畅度），
  // 或切 reduced 用轻量淡入淡出。
  MotionLevel _motion = MotionLevel.off;

  AppSkin get skin => _skin;
  MotionLevel get motion => _motion;

  void setPaper(PaperSkin paper) {
    if (paper.id == _skin.paper.id) return;
    _skin = _skin.copyWith(paper: paper);
    _persist();
    notifyListeners();
  }

  void setInk(InkSkin ink) {
    if (ink.id == _skin.ink.id) return;
    _skin = _skin.copyWith(ink: ink);
    _persist();
    notifyListeners();
  }

  void setMotion(MotionLevel level) {
    if (level == _motion) return;
    _motion = level;
    _persist();
    notifyListeners();
  }

  // —— 持久化 seam（本版无操作）——
  void _persist() {}

  /// 启动时读回偏好（本版无操作，留接入点）。
  Future<void> load() async {}
}

/// 把当前皮肤经 [InheritedNotifier] 下发，页面用 `context.skin` / `context.motion`
/// 读取并在切换时自动重建。
class SkinScope extends InheritedNotifier<SkinController> {
  const SkinScope({
    super.key,
    required SkinController controller,
    required super.child,
  }) : super(notifier: controller);

  static SkinController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkinScope>();
    assert(scope != null, 'SkinScope 未挂载到 widget 树（应在 main.dart 包裹）');
    return scope!.notifier!;
  }
}

/// 页面便捷读取：`context.skin.inkPrimary` / `context.motion`。
extension SkinX on BuildContext {
  AppSkin get skin => SkinScope.of(this).skin;
  MotionLevel get motion => SkinScope.of(this).motion;
}
