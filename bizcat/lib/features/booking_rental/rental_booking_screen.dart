import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/booking_rental/providers.dart';
import 'package:bizcat/features/booking_rental/widgets/rental_calendar.dart';
import 'package:bizcat/features/booking_rental/widgets/rental_steps.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const String _title = 'Sanani band qilish';

/// `/b/:slug/rent`: session -> guests -> date -> confirm (port of web RentalEngineApp.vue).
class RentalBookingScreen extends ConsumerStatefulWidget {
  const RentalBookingScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<RentalBookingScreen> createState() => _RentalBookingScreenState();
}

class _RentalBookingScreenState extends ConsumerState<RentalBookingScreen> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storefrontProvider(widget.slug));
    final data = store.value;

    if (data != null && !(store.hasError && !store.isLoading)) {
      final flow = bookingFlowFor(data);
      if (flow != BookingFlow.rental) {
        if (!_redirected) {
          _redirected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.replace(bookingEntryPath(widget.slug, flow));
          });
        }
        return const _PlainScaffold(body: _DetailLoading());
      }
      if (rentalHall(data) == null || rentalHallService(data) == null) {
        return _PlainScaffold(
          body: EmptyState(
            icon: Icons.event_busy,
            title: rentalNoHallMessage,
            actionLabel: data.business.phone == null ? null : "Qo'ng'iroq qilish",
            onAction: data.business.phone == null ? null : () => unawaited(callPhone(ref, data.business.phone)),
          ),
        );
      }
      return _RentalFlowView(slug: widget.slug, store: data);
    }

    return _PlainScaffold(
      body: AsyncBody<StorefrontData>(
        value: store,
        loading: const _DetailLoading(),
        onRetry: () => ref.invalidate(storefrontProvider(widget.slug)),
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PlainScaffold extends StatelessWidget {
  const _PlainScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text(_title)), body: body);
}

class _RentalFlowView extends ConsumerStatefulWidget {
  const _RentalFlowView({required this.slug, required this.store});

  final String slug;
  final StorefrontData store;

  @override
  ConsumerState<_RentalFlowView> createState() => _RentalFlowViewState();
}

class _RentalFlowViewState extends ConsumerState<_RentalFlowView> {
  late final TextEditingController _guests;
  late final TextEditingController _notes;
  final FocusNode _guestsFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  RentalFlowController get _flow => ref.read(rentalFlowProvider(widget.slug).notifier);

  @override
  void initState() {
    super.initState();
    final s = ref.read(rentalFlowProvider(widget.slug));
    _guests = TextEditingController(text: '${s.guests}');
    _notes = TextEditingController(text: s.notes);
    _guestsFocus.addListener(() {
      if (!_guestsFocus.hasFocus) _flow.clampGuests();
    });
  }

  @override
  void dispose() {
    _guests.dispose();
    _notes.dispose();
    _guestsFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (!_flow.back()) popOrGo(context, AppRoutes.business(widget.slug));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final appt = await _flow.submit(widget.store);
    if (!mounted || appt == null) return;
    context.go(AppRoutes.appointment(appt.id, created: true));
  }

  void _continueGuests() {
    FocusScope.of(context).unfocus();
    _flow.submitGuests();
  }

  @override
  Widget build(BuildContext context) {
    final provider = rentalFlowProvider(widget.slug);
    final state = ref.watch(provider);

    ref.listen(provider.select((s) => s.guests), (_, next) {
      if (int.tryParse(_guests.text) != next) {
        _guests.value = TextEditingValue(
          text: '$next',
          selection: TextSelection.collapsed(offset: '$next'.length),
        );
      }
    });
    ref.listen(provider.select((s) => s.step), (prev, next) {
      if (prev != next && _scroll.hasClients) _scroll.jumpTo(0);
    });

    final business = widget.store.business;
    final step = state.step;

    final Widget content = switch (step) {
      RentalStep.session => _SessionStep(
          selected: state.session,
          onPick: _flow.pickSession,
        ),
      RentalStep.guests => _GuestsStep(
          state: state,
          controller: _guests,
          focusNode: _guestsFocus,
          onStep: _flow.stepGuests,
          onChanged: (t) => _flow.setGuests(int.tryParse(t) ?? 0),
          onSubmitted: _continueGuests,
        ),
      RentalStep.date => _DateStep(slug: widget.slug, timezone: business.timezone, state: state),
      RentalStep.confirm => _ConfirmStep(
          slug: widget.slug,
          store: widget.store,
          state: state,
          notes: _notes,
          onNotes: _flow.setNotes,
          onRetry: _submit,
        ),
    };

    final Widget? bottom = switch (step) {
      RentalStep.guests => BottomActionBar(
          child: PrimaryButton(label: 'Davom etish', onPressed: _continueGuests),
        ),
      RentalStep.confirm => BottomActionBar(
          child: CtaButton(label: 'Bron qilish', loading: state.submitting, onPressed: _submit),
        ),
      _ => null,
    };

    return PopScope(
      canPop: step == RentalStep.session && !state.submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flow.back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(_title),
          leading: IconButton(
            tooltip: 'Orqaga',
            icon: const BackButtonIcon(),
            onPressed: state.submitting ? null : _back,
          ),
        ),
        bottomNavigationBar: bottom,
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxxl),
          children: [
            BusinessMiniHeader(
              name: business.name,
              logo: business.logo,
              brandColor: business.brandColor,
              subtitle: business.tagline ?? business.address,
            ),
            const SizedBox(height: BzSpace.l),
            StepHeader(step: step.index + 1, total: RentalStep.values.length, title: rentalStepTitle(step)),
            const SizedBox(height: BzSpace.xl),
            content,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- session

class _SessionStep extends StatelessWidget {
  const _SessionStep({required this.selected, required this.onPick});

  final RentalSession? selected;
  final ValueChanged<RentalSession> onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RentalStepLabel("To'y vaqtini tanlang", hint: 'Narxlar bir mehmon uchun taxminiy hisoblangan.'),
          const SizedBox(height: BzSpace.l),
          for (final s in RentalSession.values) ...[
            RentalSessionCard(session: s, selected: selected == s, onTap: () => onPick(s)),
            const SizedBox(height: BzSpace.m),
          ],
        ],
      );
}

// ---------------------------------------------------------------- guests

class _GuestsStep extends StatelessWidget {
  const _GuestsStep({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onStep,
    required this.onChanged,
    required this.onSubmitted,
  });

  final RentalFlowState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = state.session ?? RentalSession.evening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RentalStepLabel('Nechta mehmon kutilyapti?'),
        const SizedBox(height: BzSpace.l),
        GuestStepper(
          controller: controller,
          focusNode: focusNode,
          value: state.guests,
          onStep: onStep,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: BzSpace.s),
        Text(
          '${RentalPricing.minGuests}–${RentalPricing.maxGuests} kishi · '
          'har stolga ~${RentalPricing.seatsPerTable} kishi',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: BzSpace.xl),
        GuestSummaryCard(session: session, guests: state.clampedGuests),
      ],
    );
  }
}

// ---------------------------------------------------------------- date

class _DateStep extends ConsumerWidget {
  const _DateStep({required this.slug, required this.timezone, required this.state});

  final String slug;
  final String timezone;
  final RentalFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booked = ref.watch(bookedDaysProvider(slug));
    final flow = ref.read(rentalFlowProvider(slug).notifier);
    final session = state.session ?? RentalSession.evening;
    final today = flow.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RentalStepLabel(
          "To'y sanasini tanlang",
          hint: '${RentalPricing.title(session)} · ${RentalPricing.hours(session)} · '
              '${state.clampedGuests} kishi',
        ),
        const SizedBox(height: BzSpace.l),
        RentalCalendar(
          month: state.visibleMonth,
          today: today,
          lastDay: rentalHorizonEnd(today),
          session: session,
          booked: booked,
          selected: state.date,
          canPrev: flow.canPrevMonth,
          canNext: flow.canNextMonth,
          onPrev: flow.prevMonth,
          onNext: flow.nextMonth,
          onPick: flow.pickDate,
          onRetry: () => ref.invalidate(bookedDaysProvider(slug)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- confirm

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.slug,
    required this.store,
    required this.state,
    required this.notes,
    required this.onNotes,
    required this.onRetry,
  });

  final String slug;
  final StorefrontData store;
  final RentalFlowState state;
  final TextEditingController notes;
  final ValueChanged<String> onNotes;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = state.session ?? RentalSession.evening;
    final guests = state.clampedGuests;
    final service = rentalHallService(store);
    final date = state.date;
    final error = state.submitError;
    final notesError = error is ApiException ? error.fieldError('notes') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCard(
          rows: [
            SummaryRow(label: 'Vaqt', value: '${RentalPricing.title(session)} · ${RentalPricing.hours(session)}'),
            SummaryRow(label: 'Sana', value: date == null ? '—' : UzDates.dayMonthYear(date)),
            SummaryRow(label: 'Mehmonlar', value: '$guests kishi · ${RentalPricing.tables(guests)} stol'),
            SummaryRow(label: 'Bir kishiga', value: Money.format(RentalPricing.perGuestTiyin(session))),
            SummaryRow(
              label: 'Jami taxminan',
              value: Money.format(RentalPricing.totalTiyin(session, guests)),
              emphasize: true,
            ),
            if (service != null && service.requiresDeposit)
              SummaryRow(label: "Oldindan to'lov", value: Money.format(service.depositTiyin)),
          ],
        ),
        const SizedBox(height: BzSpace.m),
        Text(
          "Bron so'rovi yuboriladi, to'yxona mudiri siz bilan bog'lanadi. "
          "Yakuniy narx menyu va qo'shimcha xizmatlarga qarab o'zgarishi mumkin.",
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: BzSpace.xl),
        TextField(
          key: const ValueKey('rental-notes-field'),
          controller: notes,
          onChanged: onNotes,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          enabled: !state.submitting,
          decoration: InputDecoration(
            labelText: 'Izoh (ixtiyoriy)',
            hintText: 'Masalan: kelin-kuyov stoli, karnay-surnay',
            alignLabelWithHint: true,
            errorText: notesError,
          ),
        ),
        if (error != null && notesError == null) ...[
          const SizedBox(height: BzSpace.m),
          _SubmitAlert(slug: slug, error: error, onRetry: onRetry),
        ],
      ],
    );
  }
}

class _SubmitAlert extends StatelessWidget {
  const _SubmitAlert({required this.slug, required this.error, required this.onRetry});

  final String slug;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (isRentalNoHall(e)) return const RentalAlert(message: rentalNoHallMessage);
    if (e is ApiException && (e.isForbidden || e.isNotFound)) {
      return RentalAlert(
        message: e.message,
        action: PrimaryButton(
          label: 'Biznes sahifasiga',
          onPressed: () => popOrGo(context, AppRoutes.business(slug)),
        ),
      );
    }
    if (isOffline(e)) {
      return RentalAlert(
        message: errorText(e),
        action: SecondaryButton(label: 'Qayta urinish', icon: Icons.refresh, onPressed: onRetry),
      );
    }
    return RentalAlert(message: errorText(e));
  }
}

/// LoadingView(detail) overflows on wide/short viewports (its 16:9 box grows with the width), so
/// it is clipped inside a non-scrolling scroll view. TODO(S0): move to shared (fix LoadingView).
class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: LoadingView(kind: LoadingKind.detail),
      );
}
