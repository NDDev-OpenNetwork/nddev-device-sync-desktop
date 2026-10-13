import 'package:flutter/widgets.dart';
import 'package:nds_native/nds_native.dart' as native;

/// One platform lifecycle adapter. Rust owns the activity decision; screens
/// consume it and the current client receives the same raw native lifecycle.
class ApplicationActivity extends ValueNotifier<bool> {
  ApplicationActivity({
    required this.nativeReady,
    this.onLifecycle,
    this.onBridgeFailure,
  }) : super(false) {
    _listener = AppLifecycleListener(onStateChange: _changed);
    _changed(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.detached,
    );
  }

  final bool nativeReady;
  final ValueChanged<native.ClientLifecycle>? onLifecycle;
  final VoidCallback? onBridgeFailure;
  late final AppLifecycleListener _listener;
  native.ClientLifecycle _state = native.ClientLifecycle.detached;
  native.NdsClient? _client;

  void attach(native.NdsClient? client) {
    _client = client;
    if (nativeReady) _apply();
  }

  void _changed(AppLifecycleState state) {
    _state = switch (state) {
      AppLifecycleState.resumed => native.ClientLifecycle.resumed,
      AppLifecycleState.inactive => native.ClientLifecycle.inactive,
      AppLifecycleState.hidden => native.ClientLifecycle.hidden,
      AppLifecycleState.paused => native.ClientLifecycle.paused,
      AppLifecycleState.detached => native.ClientLifecycle.detached,
    };
    if (!nativeReady) return;
    _apply();
    onLifecycle?.call(_state);
  }

  void _apply() {
    try {
      _client?.setLifecycle(state: _state);
      value = native.clientWorkPermitted(state: _state);
    } catch (_) {
      value = false;
      onBridgeFailure?.call();
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    _client = null;
    super.dispose();
  }
}

class ApplicationActivityScope extends InheritedNotifier<ApplicationActivity> {
  const ApplicationActivityScope({
    super.key,
    required ApplicationActivity activity,
    required super.child,
  }) : super(notifier: activity);

  static ApplicationActivity read(BuildContext context) => context
      .getInheritedWidgetOfExactType<ApplicationActivityScope>()!
      .notifier!;

  static ApplicationActivity of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ApplicationActivityScope>()!
      .notifier!;
}
