import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Calls [onTick] every [interval] while mounted, [enabled], visible (`TickerMode`) and the app is
/// resumed; also calls it on `AppLifecycleState.resumed` when [refreshOnResume].
///
/// In tests advance time with `tester.pump(interval)`.
class Poller extends StatefulWidget {
  const Poller({
    super.key,
    required this.interval,
    required this.onTick,
    this.enabled = true,
    this.refreshOnResume = true,
    required this.child,
  });

  final Duration interval;
  final VoidCallback onTick;
  final bool enabled;
  final bool refreshOnResume;
  final Widget child;

  @override
  State<Poller> createState() => _PollerState();
}

class _PollerState extends State<Poller> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _resumed = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final s = WidgetsBinding.instance.lifecycleState;
    _resumed = s == null || s == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  void _onLifecycle(AppLifecycleState s) {
    final wasResumed = _resumed;
    _resumed = s == AppLifecycleState.resumed;
    if (_resumed && !wasResumed && widget.refreshOnResume && widget.enabled && mounted) {
      widget.onTick();
    }
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(Poller old) {
    super.didUpdateWidget(old);
    if (old.interval != widget.interval) _timer?.cancel();
    if (old.interval != widget.interval) _timer = null;
    _sync();
  }

  void _sync() {
    final shouldRun = mounted && widget.enabled && _visible && _resumed;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (mounted && widget.enabled && _visible && _resumed) widget.onTick();
      });
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
