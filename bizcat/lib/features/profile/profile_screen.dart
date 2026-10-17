import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/profile/providers.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/login_prompt.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The app version shown in "Ilova haqida" (pubspec `version`).
const kAppVersion = '0.1.0';

/// The Profil tab (BIZCAT-SPEC §9.12).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    final ok = await confirmDialog(context, title: 'Hisobdan chiqasizmi?', confirmLabel: 'Chiqish');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) setState(() => _busy = false);
    router.go(AppRoutes.home);
  }

  Future<void> _delete() async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DeleteAccountDialog()) ?? false;
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await deleteAccount(ref);
      showSnack("Hisobingiz o'chirildi.");
      router.go(AppRoutes.home);
    } on Object catch (e) {
      showErrorSnack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(profileProvider);
      await ref.read(profileProvider.future);
    } on Object {
      // The cached header stays; the error shows in the stats row.
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumer = ref.watch(currentConsumerProvider);
    if (consumer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: ListView(
          padding: const EdgeInsets.only(top: BzSpace.xxl, bottom: BzSpace.xxxl),
          children: const [
            LoginPromptView(
              title: 'Profil',
              message: 'Bronlar, sevimlilar va bonuslar uchun kiring.',
              from: AppRoutes.profile,
              icon: Icons.person_outline,
            ),
            SizedBox(height: BzSpace.xl),
            _AppSection(),
          ],
        ),
      );
    }

    final profile = ref.watch(profileProvider);
    final user = profile.value ?? consumer;
    final stats = user.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: BzSpace.xxxl),
          children: [
            _Header(user: user),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
              child: _StatsRow(stats: stats, loading: profile.isLoading && stats == null),
            ),
            const SizedBox(height: BzSpace.l),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Hamyon'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(context.push(AppRoutes.wallet)),
            ),
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Sharhlarim'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(context.push(AppRoutes.myReviews)),
            ),
            const _AppSection(),
            const SizedBox(height: BzSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
              child: SecondaryButton(
                label: 'Chiqish',
                icon: Icons.logout,
                loading: _busy,
                onPressed: _busy ? null : () => unawaited(_signOut()),
              ),
            ),
            const SizedBox(height: BzSpace.s),
            Center(
              child: DangerTextButton(label: "Hisobni o'chirish", onPressed: _busy ? null : () => unawaited(_delete())),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final ConsumerUser user;

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(p[0]));
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.s, BzSpace.l),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: BzColors.indigo,
            child: Text(initials(user.name ?? ''), style: theme.textTheme.titleLarge?.copyWith(color: BzColors.white)),
          ),
          const SizedBox(width: BzSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: BzSpace.xs),
                Text(
                  Phone.format(user.phone),
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tahrirlash',
            icon: const Icon(Icons.edit),
            onPressed: () => unawaited(context.push(AppRoutes.profileEdit)),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.loading});

  final ConsumerStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String v(int? n) => n == null ? (loading ? '...' : '—') : '$n';
    return Row(
      children: [
        _StatTile(label: 'Bronlar', value: v(stats?.appointmentsTotal), onTap: () => context.go(AppRoutes.bookings)),
        const SizedBox(width: BzSpace.m),
        _StatTile(
          label: 'Sharhlar',
          value: v(stats?.reviewsTotal),
          onTap: () => unawaited(context.push(AppRoutes.myReviews)),
        ),
        const SizedBox(width: BzSpace.m),
        _StatTile(label: 'Sevimlilar', value: v(stats?.favoritesTotal), onTap: () => context.go(AppRoutes.favorites)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BzSpace.m, horizontal: BzSpace.s),
            child: Column(
              children: [
                Text(value, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// City, language, "connect your business" and about: shown signed in and signed out.
class _AppSection extends ConsumerWidget {
  const _AppSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: const Text('Shahar'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cityLabel(city), style: TextStyle(color: muted)),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => unawaited(context.push(AppRoutes.city)),
        ),
        const ListTile(
          enabled: false,
          leading: Icon(Icons.translate),
          title: Text('Til'),
          subtitle: Text('Ruscha tez orada'),
          trailing: Text('O\'zbekcha'),
        ),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Biznesingizni ulang'),
          trailing: const Icon(Icons.open_in_new, size: 20),
          onTap: () => unawaited(_openRegister(ref)),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Ilova haqida'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Bizcat',
            applicationVersion: kAppVersion,
            applicationLegalese: 'TizBiz ekotizimi',
          ),
        ),
      ],
    );
  }

  Future<void> _openRegister(WidgetRef ref) async {
    final ok = await ref.read(urlOpenerProvider).open(Uri.parse('https://tizbiz.uz/register'));
    if (!ok) showSnack("Havolani ochib bo'lmadi.");
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text("Hisobni o'chirish"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Profilingiz o'chiriladi, sharhlaringiz anonim bo'lib qoladi. Bizneslardagi bron tarixi "
            "o'chmaydi. Bu amalni ortga qaytarib bo'lmaydi.",
          ),
          const SizedBox(height: BzSpace.m),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            title: const Text('Tushundim'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Bekor qilish')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text("O'chirish"),
        ),
      ],
    );
  }
}
