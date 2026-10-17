import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/clock.dart';

/// Lists refresh every 60 s while visible (no push in this iteration).
const kPollInterval = Duration(seconds: 60);

/// Tests override it to false (no periodic timers).
final pollingEnabledProvider = Provider<bool>((ref) => true);

/// Calls [onTick] every [interval] while: the app lifecycle is resumed, TickerMode is enabled
/// (the shell branch is visible) and the enclosing route is current. Also calls it once on resume
/// when the last tick is older than [interval].
class PollWhileVisible extends ConsumerStatefulWidget {
  const PollWhileVisible({super.key, this.interval = kPollInterval, required this.onTick, required this.child});

  final Duration interval;
  final VoidCallback onTick;
  final Widget child;

  @override
  ConsumerState<PollWhileVisible> createState() => _PollWhileVisibleState();
}

class _PollWhileVisibleState extends ConsumerState<PollWhileVisible> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastTick;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = WidgetsBinding.instance.lifecycleState;
    _resumed = s == null || s == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PollWhileVisible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _timer?.cancel();
      _timer = null;
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _resumed;
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && !wasResumed && _visible) {
      final last = _lastTick;
      if (last == null || _now().difference(last) > widget.interval) _tick();
    }
  }

  DateTime _now() => ref.read(clockProvider)();

  bool get _enabled => ref.read(pollingEnabledProvider);

  bool get _visible {
    if (!mounted) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _sync() {
    if (!_enabled) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _lastTick ??= _now();
    _timer ??= Timer.periodic(widget.interval, (_) {
      if (_resumed && _visible) _tick();
    });
  }

  void _tick() {
    _lastTick = _now();
    widget.onTick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Registers the TickerMode dependency so a branch switch re-runs didChangeDependencies.
    TickerMode.valuesOf(context);
    return widget.child;
  }
}
