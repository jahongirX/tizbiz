import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/profile/providers.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/ui.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/bz_icons.dart';
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
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.only(bottom: BzSpace.xxxl),
          children: [
            _GradientHeader(
              child: Column(
                children: [
                  const _Avatar(initials: null),
                  const SizedBox(height: BzSpace.m),
                  Text('Profil', style: BzText.sora(context, 22, color: BzColors.white)),
                  const SizedBox(height: BzSpace.xs),
                  Text(
                    'Bronlar, sevimlilar va bonuslar uchun kiring.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: BzColors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: BzSpace.l),
                  _WhiteCard(
                    key: const Key('profile-login'),
                    title: 'Kirish',
                    subtitle: 'Telefon raqam orqali, parolsiz',
                    icon: BzIcons.user,
                    onTap: () => unawaited(context.push(AppRoutes.loginWith(from: AppRoutes.profile))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BzSpace.l),
            const _AppSection(),
          ],
        ),
      );
    }

    final profile = ref.watch(profileProvider);
    final user = profile.value ?? consumer;
    final stats = user.stats;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: BzSpace.xxxl),
          children: [
            _GradientHeader(
              child: Column(
                children: [
                  _Header(user: user),
                  const SizedBox(height: BzSpace.l),
                  _StatsRow(stats: stats, loading: profile.isLoading && stats == null),
                ],
              ),
            ),
            const SizedBox(height: BzSpace.l),
            BzGroup(
              children: [
                BzRow(
                  icon: BzIcons.bookings,
                  tileIcon: false,
                  title: 'Bronlarim',
                  onTap: () => context.go(AppRoutes.bookings),
                ),
                BzRow(
                  icon: BzIcons.heart,
                  tileIcon: false,
                  title: 'Sevimlilar',
                  onTap: () => context.go(AppRoutes.favorites),
                ),
                BzRow(
                  icon: BzIcons.wallet,
                  tileIcon: false,
                  title: 'Hamyon',
                  onTap: () => unawaited(context.push(AppRoutes.wallet)),
                ),
                BzRow(
                  icon: BzIcons.review,
                  tileIcon: false,
                  title: 'Sharhlarim',
                  onTap: () => unawaited(context.push(AppRoutes.myReviews)),
                ),
                BzRow(
                  icon: BzIcons.map,
                  tileIcon: false,
                  title: 'Xaritadan qidirish',
                  onTap: () => unawaited(context.push(AppRoutes.map)),
                ),
              ],
            ),
            const SizedBox(height: BzSpace.l),
            const _AppSection(),
            const SizedBox(height: BzSpace.l),
            BzGroup(
              children: [
                BzRow(
                  key: const Key('profile-logout'),
                  icon: BzIcons.logout,
                  tileIcon: false,
                  title: 'Chiqish',
                  danger: true,
                  showChevron: false,
                  trailing: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _busy ? null : () => unawaited(_signOut()),
                ),
              ],
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

/// The indigo gradient block at the top with rounded bottom corners.
class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B44A8), BzColors.indigo700, BzColors.indigo],
        ),
      ),
      padding: EdgeInsets.fromLTRB(BzSpace.gutter, top + BzSpace.m, BzSpace.gutter, BzSpace.xl),
      child: Column(
        children: [
          Text(
            'Profil',
            style: BzText.sora(context, 20, weight: FontWeight.w600, color: BzColors.white),
          ),
          const SizedBox(height: BzSpace.l),
          child,
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.onEdit});

  final String? initials;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      height: 88,
      child: Material(
        color: BzColors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (initials == null)
                const Icon(BzIcons.profileBold, size: 44, color: BzColors.indigo700)
              else
                Text(initials!, style: BzText.sora(context, 30, color: BzColors.indigo)),
              if (onEdit != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: BzColors.indigo.withValues(alpha: 0.85),
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      'Tahrirlash',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: BzColors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white card inside the gradient header (title, subtitle, chevron).
class _WhiteCard extends StatelessWidget {
  const _WhiteCard({super.key, required this.title, this.subtitle, required this.onTap, this.icon});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: BzColors.white,
      borderRadius: BorderRadius.circular(BzRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.xl, vertical: BzSpace.l),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, color: BzColors.indigo), const SizedBox(width: BzSpace.m)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BzText.sora(context, 18, color: BzColors.indigo)),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: BzColors.muted)),
                  ],
                ),
              ),
              const Icon(BzIcons.chevronRight, color: BzColors.muted, size: 20),
            ],
          ),
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
    void edit() => unawaited(context.push(AppRoutes.profileEdit));
    return Row(
      children: [
        _Avatar(initials: initials(user.name ?? ''), onEdit: edit),
        const SizedBox(width: BzSpace.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                key: const Key('profile-display-name'),
                style: BzText.sora(context, 22, color: BzColors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: BzSpace.xs),
              Text(
                Phone.format(user.phone),
                style: theme.textTheme.bodyLarge?.copyWith(color: BzColors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tahrirlash',
          icon: const Icon(BzIcons.edit, color: BzColors.white),
          onPressed: edit,
        ),
      ],
    );
  }
}

/// Bookings / reviews / favorites counters in one white card.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.loading});

  final ConsumerStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String v(int? n) => n == null ? (loading ? '...' : '—') : '$n';
    return Material(
      color: BzColors.white,
      borderRadius: BorderRadius.circular(BzRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatTile(
              label: 'Bronlar',
              value: v(stats?.appointmentsTotal),
              onTap: () => context.go(AppRoutes.bookings),
            ),
            const VerticalDivider(width: 1, indent: 14, endIndent: 14, color: BzColors.border),
            _StatTile(
              label: 'Sharhlar',
              value: v(stats?.reviewsTotal),
              onTap: () => unawaited(context.push(AppRoutes.myReviews)),
            ),
            const VerticalDivider(width: 1, indent: 14, endIndent: 14, color: BzColors.border),
            _StatTile(
              label: 'Sevimlilar',
              value: v(stats?.favoritesTotal),
              onTap: () => context.go(AppRoutes.favorites),
            ),
          ],
        ),
      ),
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BzSpace.l, horizontal: BzSpace.s),
          child: Column(
            children: [
              Text(value, style: BzText.sora(context, 22, color: BzColors.indigo)),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: BzColors.muted)),
            ],
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
    return BzGroup(
      children: [
        BzRow(
          icon: BzIcons.location,
          tileIcon: false,
          title: 'Shahar',
          trailingText: cityLabel(city),
          onTap: () => unawaited(context.push(AppRoutes.city)),
        ),
        const BzRow(
          icon: BzIcons.language,
          tileIcon: false,
          title: 'Til',
          subtitle: 'Ruscha tez orada',
          trailingText: "O'zbekcha",
        ),
        BzRow(
          icon: BzIcons.shop,
          tileIcon: false,
          title: 'Biznesingizni ulang',
          trailing: const Icon(BzIcons.openExternal, size: 20),
          onTap: () => unawaited(_openRegister(ref)),
        ),
        BzRow(
          icon: BzIcons.info,
          tileIcon: false,
          title: 'Ilova haqida',
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
