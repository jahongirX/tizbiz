import 'package:flutter_riverpod/flutter_riverpod.dart';

/// false in tests: network images render their placeholder instead.
final netImagesEnabledProvider = Provider<bool>((_) => true);
