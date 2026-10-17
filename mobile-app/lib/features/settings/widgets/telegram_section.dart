import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/settings/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// 5. "Telegram bot": status, write-only token, connect / disconnect, webhook warning.
class TelegramSection extends ConsumerStatefulWidget {
  const TelegramSection({super.key, required this.settings});

  final BookingSettings settings;

  @override
  ConsumerState<TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends ConsumerState<TelegramSection> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  String? _banner;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<BookingSettings> Function() call, String okText) async {
    setState(() {
      _busy = true;
      _fieldError = null;
      _banner = null;
    });
    try {
      final saved = await call();
      if (!mounted) return;
      _token.clear();
      if (saved.telegramWebhookOk != false) showAppSnack(context, okText);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiException && e.fieldError('telegram_bot_token') != null) {
          _fieldError = e.fieldError('telegram_bot_token');
        } else {
          _banner = errorText(e);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final t = _token.text.trim();
    if (t.isEmpty) {
      setState(() => _fieldError = 'Tokenni kiriting');
      return;
    }
    await _run(() => ref.read(bookingSettingsProvider.notifier).connectTelegram(t), 'Bot ulandi');
  }

  Future<void> _disconnect() async {
    final ok = await confirmAction(context,
        title: 'Telegram botni uzasizmi?',
        message: "Mijozlar bot orqali yozila olmaydi.",
        confirmLabel: 'Uzish',
        destructive: true);
    if (!ok || !mounted) return;
    await _run(() => ref.read(bookingSettingsProvider.notifier).disconnectTelegram(), 'Bot uzildi');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = widget.settings;
    final connected = s.telegramConnected;
    return SectionCard(
      title: 'Telegram bot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(connected ? Icons.check_circle : Icons.link_off, size: 18, color: connected ? c.success : c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(connected
                    ? 'Ulangan: @${s.telegramBotUsername ?? ''}'
                    : 'Ulanmagan'),
              ),
              if (connected)
                TextButton(
                  onPressed: _busy ? null : _disconnect,
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  child: const Text('Uzish'),
                ),
            ],
          ),
          if (s.telegramWebhookOk == false) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.telegramError ?? "Webhook o'rnatilmadi.")),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: connected ? 'Yangi bot tokeni' : 'Bot tokeni',
              helperText: "@BotFather'dan olingan token. Webhook faqat https serverda ishlaydi.",
              helperMaxLines: 2,
              errorText: _fieldError,
            ),
          ),
          const SizedBox(height: 12),
          FormErrorBanner(message: _banner),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _connect,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ulash'),
            ),
          ),
        ],
      ),
    );
  }
}
