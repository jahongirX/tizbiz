import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every "now" / "today" in the app is `ref.read(clockProvider)()`.
///
/// Tests pin it to `DateTime.utc(2026, 10, 17, 7)` (Saturday 17 Oct 2026, 12:00 Tashkent).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
