import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// GET/PUT /v1/settings/booking (owner/admin: settings.manage).
class BookingSettingsNotifier extends AsyncNotifier<BookingSettings> {
  @override
  Future<BookingSettings> build() async {
    requireActive(ref);
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    return ref.watch(apiClientProvider).get<BookingSettings>(Endpoints.bookingSettings,
        decode: (d) => BookingSettings.fromJson(JsonRead.object(d)), cancelToken: cancel);
  }

  /// Sends only `edited.diff(original)`; an empty diff makes no request and returns the original.
  Future<BookingSettings> save(BookingSettings edited) async {
    final original = state.requireValue;
    final body = edited.diff(original);
    if (body.isEmpty) return original;
    return _put(body);
  }

  /// PUT {"telegram_bot_token": token}; the response adds telegram_webhook_ok / telegram_error.
  Future<BookingSettings> connectTelegram(String token) => _put(BookingSettings.telegramTokenBody(token.trim()));

  /// PUT {"telegram_bot_token": ""}.
  Future<BookingSettings> disconnectTelegram() => _put(BookingSettings.telegramTokenBody(''));

  Future<BookingSettings> _put(Map<String, dynamic> body) async {
    final saved = await ref.read(apiClientProvider).put<BookingSettings>(Endpoints.bookingSettings,
        body: body, decode: (d) => BookingSettings.fromJson(JsonRead.object(d)));
    if (ref.mounted) state = AsyncData(saved);
    return saved;
  }
}

final bookingSettingsProvider =
    AsyncNotifierProvider.autoDispose<BookingSettingsNotifier, BookingSettings>(BookingSettingsNotifier.new);
