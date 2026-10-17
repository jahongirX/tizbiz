import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/features/settings/providers.dart';
import 'package:tizbiz_biznes/features/settings/widgets/booking_section.dart';
import 'package:tizbiz_biznes/features/settings/widgets/brand_section.dart';
import 'package:tizbiz_biznes/features/settings/widgets/location_section.dart';
import 'package:tizbiz_biznes/features/settings/widgets/profile_section.dart';
import 'package:tizbiz_biznes/features/settings/widgets/telegram_section.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/star_rating.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Onlayn-yozuv sozlamalari": booking, profile, location, brand, Telegram bot, rating.
class BookingSettingsScreen extends ConsumerStatefulWidget {
  const BookingSettingsScreen({super.key});

  @override
  ConsumerState<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends ConsumerState<BookingSettingsScreen> {
  final Set<String> _dirty = {};

  ValueChanged<bool> _onDirty(String key) => (d) {
        if (!mounted) return;
        setState(() => d ? _dirty.add(key) : _dirty.remove(key));
      };

  Future<void> _confirmLeave() async {
    final nav = Navigator.of(context);
    final leave = await confirmAction(context,
        title: "O'zgarishlar saqlanmaydi. Chiqasizmi?", confirmLabel: 'Chiqish', destructive: true);
    if (!leave || !mounted) return;
    setState(_dirty.clear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nav.maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(bookingSettingsProvider);
    return PopScope(
      canPop: _dirty.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Onlayn-yozuv sozlamalari')),
        body: AsyncBody<BookingSettings>(
          value: value,
          onRetry: () => ref.invalidate(bookingSettingsProvider),
          data: (s) => MaxWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                BookingSection(key: const ValueKey('booking'), settings: s, onDirty: _onDirty('booking')),
                const SizedBox(height: 12),
                ProfileSection(key: const ValueKey('profile'), settings: s, onDirty: _onDirty('profile')),
                const SizedBox(height: 12),
                LocationSection(key: const ValueKey('location'), settings: s, onDirty: _onDirty('location')),
                const SizedBox(height: 12),
                BrandSection(key: const ValueKey('brand'), settings: s, onDirty: _onDirty('brand')),
                const SizedBox(height: 12),
                TelegramSection(key: const ValueKey('telegram'), settings: s),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Reyting',
                  child: Row(
                    children: [
                      StarRating(value: s.ratingAvg, size: 20),
                      const SizedBox(width: 8),
                      Text(s.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${s.ratingCount} ta sharh')),
                      TextButton(onPressed: () => context.go(Routes.reviews), child: const Text('Sharhlar')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
