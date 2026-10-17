import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/booking_slot/providers.dart';
import 'package:bizcat/features/booking_slot/widgets.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/location_card.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const String _title = 'Navbatga yozilish';

/// Step titles under the StepHeader.
String slotStepTitle(SlotStep s) => switch (s) {
      SlotStep.service => 'Xizmat',
      SlotStep.staff => 'Mutaxassis',
      SlotStep.datetime => 'Vaqt',
      SlotStep.confirm => 'Tasdiqlash',
    };

/// `/b/:slug/book`: service -> staff -> date/time -> confirm (port of web SlotEngineApp.vue).
class SlotBookingScreen extends ConsumerStatefulWidget {
  const SlotBookingScreen({super.key, required this.slug, this.serviceId, this.staffId});

  final String slug;
  final int? serviceId;
  final int? staffId;

  @override
  ConsumerState<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends ConsumerState<SlotBookingScreen> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storefrontProvider(widget.slug));
    final data = store.value;

    if (data != null && !(store.hasError && !store.isLoading)) {
      final flow = bookingFlowFor(data);
      if (flow != BookingFlow.slot) {
        if (!_redirected) {
          _redirected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.replace(bookingEntryPath(widget.slug, flow));
          });
        }
        return const _PlainScaffold(body: _DetailLoading());
      }
      return _SlotFlowView(
        slug: widget.slug,
        store: data,
        serviceId: widget.serviceId,
        staffId: widget.staffId,
      );
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

class _SlotFlowView extends ConsumerStatefulWidget {
  const _SlotFlowView({required this.slug, required this.store, this.serviceId, this.staffId});

  final String slug;
  final StorefrontData store;
  final int? serviceId;
  final int? staffId;

  @override
  ConsumerState<_SlotFlowView> createState() => _SlotFlowViewState();
}

class _SlotFlowViewState extends ConsumerState<_SlotFlowView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _nameError;

  SlotFlowController get _flow => ref.read(slotFlowProvider(widget.slug).notifier);

  @override
  void initState() {
    super.initState();
    // Providers cannot be modified while the tree builds: init after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flow.init(widget.store, serviceId: widget.serviceId, staffId: widget.staffId);
      final s = ref.read(slotFlowProvider(widget.slug));
      _name.text = s.name;
      _notes.text = s.notes;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (!_flow.back()) popOrGo(context, AppRoutes.business(widget.slug));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final err = validateSlotName(_name.text);
    setState(() => _nameError = err);
    if (err != null) return;
    final appt = await _flow.submit();
    if (!mounted || appt == null) return;
    context.go(AppRoutes.appointment(appt.id, created: true));
  }

  @override
  Widget build(BuildContext context) {
    final provider = slotFlowProvider(widget.slug);
    final state = ref.watch(provider);
    ref.listen(provider.select((s) => s.step), (prev, next) {
      if (prev != next && _scroll.hasClients) _scroll.jumpTo(0);
    });

    final business = widget.store.business;

    if (!state.initialized) {
      return const _PlainScaffold(body: _DetailLoading());
    }

    final step = state.step;
    final Widget content = switch (step) {
      SlotStep.service => _ServiceStep(store: widget.store, selected: state.service, onPick: _flow.pickService),
      SlotStep.staff => _StaffStep(store: widget.store, selected: state.staff, onPick: _flow.pickStaff),
      SlotStep.datetime => _DateTimeStep(state: state, flow: _flow),
      SlotStep.confirm => _ConfirmStep(
          slug: widget.slug,
          store: widget.store,
          state: state,
          name: _name,
          notes: _notes,
          nameError: _nameError,
          onName: (v) {
            _flow.setName(v);
            if (_nameError != null) setState(() => _nameError = null);
          },
          onNotes: _flow.setNotes,
          onRetry: _submit,
        ),
    };

    return PopScope(
      canPop: step == SlotStep.service && !state.submitting,
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
        bottomNavigationBar: step == SlotStep.confirm
            ? BottomActionBar(
                child: CtaButton(label: 'Band qilish', loading: state.submitting, onPressed: _submit),
              )
            : null,
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(top: BzSpace.l, bottom: BzSpace.xxxl),
          children: [
            _Gutter(
              child: BusinessMiniHeader(
                name: business.name,
                logo: business.logo,
                brandColor: business.brandColor,
                subtitle: business.tagline ?? business.address,
              ),
            ),
            const SizedBox(height: BzSpace.l),
            _Gutter(child: StepHeader(step: state.stepNumber, total: SlotStep.values.length, title: slotStepTitle(step))),
            const SizedBox(height: BzSpace.xl),
            content,
          ],
        ),
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter), child: child);
}

// ---------------------------------------------------------------- service

class _ServiceStep extends ConsumerWidget {
  const _ServiceStep({required this.store, required this.selected, required this.onPick});

  final StorefrontData store;
  final Service? selected;
  final ValueChanged<Service> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = bookableServices(store);
    final phone = store.business.phone;
    if (services.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        title: "Hozircha onlayn yozilish uchun xizmatlar yo'q",
        actionLabel: Phone.telUri(phone) == null ? null : "Qo'ng'iroq qilish",
        onAction: Phone.telUri(phone) == null ? null : () => unawaited(callPhone(ref, phone)),
      );
    }
    return _Gutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SlotStepLabel('Xizmatni tanlang'),
          for (final s in services) ...[
            SlotServiceCard(service: s, selected: selected?.id == s.id, onTap: () => onPick(s)),
            const SizedBox(height: BzSpace.s),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- staff

class _StaffStep extends StatelessWidget {
  const _StaffStep({required this.store, required this.selected, required this.onPick});

  final StorefrontData store;
  final Staff? selected;
  final ValueChanged<Staff> onPick;

  @override
  Widget build(BuildContext context) {
    final staff = activeStaff(store);
    if (staff.isEmpty) {
      return const EmptyState(icon: Icons.person_off_outlined, title: 'Mutaxassislar topilmadi.');
    }
    return _Gutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SlotStepLabel('Mutaxassisni tanlang'),
          for (final m in staff) ...[
            SlotStaffCard(staff: m, selected: selected?.id == m.id, onTap: () => onPick(m)),
            const SizedBox(height: BzSpace.s),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- date + time

class _DateTimeStep extends StatelessWidget {
  const _DateTimeStep({required this.state, required this.flow});

  final SlotFlowState state;
  final SlotFlowController flow;

  @override
  Widget build(BuildContext context) {
    final key = flow.availabilityKey;
    final next = state.date.addDays(1);
    final error = state.submitError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Gutter(child: SlotStepLabel('Sanani tanlang')),
        SlotDayStrip(today: flow.today, selected: state.date, onPick: flow.pickDate),
        const SizedBox(height: BzSpace.xl),
        if (error != null) ...[
          _Gutter(child: SlotAlert(message: errorText(error))),
          const SizedBox(height: BzSpace.l),
        ],
        if (key != null)
          _Gutter(
            child: SlotTimes(
              availabilityKey: key,
              selected: state.slot,
              onPick: flow.pickSlot,
              onNextDay: next.isAfter(flow.lastDay) ? null : () => flow.pickDate(next),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- confirm

class _ConfirmStep extends ConsumerWidget {
  const _ConfirmStep({
    required this.slug,
    required this.store,
    required this.state,
    required this.name,
    required this.notes,
    required this.nameError,
    required this.onName,
    required this.onNotes,
    required this.onRetry,
  });

  final String slug;
  final StorefrontData store;
  final SlotFlowState state;
  final TextEditingController name;
  final TextEditingController notes;
  final String? nameError;
  final ValueChanged<String> onName;
  final ValueChanged<String> onNotes;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final business = store.business;
    final service = state.service!;
    final staff = state.staff!;
    final slot = state.slot!;
    final tz = business.timezone;
    final start = Dates.toBizLocal(slot.startUtc, tz);
    final end = Dates.toBizLocal(slot.endUtc, tz);
    final consumer = ref.watch(currentConsumerProvider);
    final error = state.submitError;
    final api = error is ApiException ? error : null;
    final nameServerError = api?.fieldError('name');
    final notesServerError = api?.fieldError('notes');
    final showAlert = error != null && nameServerError == null && notesServerError == null;

    return _Gutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryCard(
            rows: [
              SummaryRow(label: 'Xizmat', value: service.name),
              SummaryRow(label: 'Mutaxassis', value: staff.name),
              SummaryRow(label: 'Sana', value: UzDates.weekdayDayMonth(start.date)),
              SummaryRow(label: 'Vaqt', value: UzDates.timeRange(start, end)),
              SummaryRow(label: 'Davomiyligi', value: UzDates.duration(service.durationMin)),
              SummaryRow(label: 'Narxi', value: Money.format(service.priceTiyin), emphasize: true),
              if (service.requiresDeposit)
                SummaryRow(label: "Oldindan to'lov", value: Money.format(service.depositTiyin)),
            ],
          ),
          if (service.requiresDeposit) ...[
            const SizedBox(height: BzSpace.s),
            Text("Bron qilingandan so'ng Payme orqali to'lashingiz mumkin.", style: muted),
          ],
          const SizedBox(height: BzSpace.l),
          LocationCard(
            address: business.address,
            mapUrl: business.mapUrl,
            name: business.name,
            phone: business.phone,
          ),
          const SizedBox(height: BzSpace.xl),
          TextField(
            key: const ValueKey('slot-name-field'),
            controller: name,
            onChanged: onName,
            enabled: !state.submitting,
            maxLength: kSlotNameMax,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Ismingiz',
              counterText: '',
              errorText: nameError ?? nameServerError,
            ),
          ),
          const SizedBox(height: BzSpace.m),
          TextField(
            key: const ValueKey('slot-notes-field'),
            controller: notes,
            onChanged: onNotes,
            enabled: !state.submitting,
            maxLength: kSlotNotesMax,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Izoh (ixtiyoriy)',
              alignLabelWithHint: true,
              errorText: notesServerError,
            ),
          ),
          if (consumer != null) ...[
            const SizedBox(height: BzSpace.s),
            Text('Telefon: ${Phone.format(consumer.phone)}', style: muted),
          ],
          if (showAlert) ...[
            const SizedBox(height: BzSpace.l),
            _SubmitAlert(slug: slug, error: error, onRetry: onRetry),
          ],
        ],
      ),
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
    if (e is ApiException && (e.isForbidden || e.isNotFound)) {
      return SlotAlert(
        message: e.message,
        action: PrimaryButton(
          label: 'Biznes sahifasiga',
          onPressed: () => popOrGo(context, AppRoutes.business(slug)),
        ),
      );
    }
    if (e is ApiException && e.status == 422) return SlotAlert(message: e.message);
    return SlotAlert(
      message: errorText(e),
      action: SecondaryButton(label: 'Qayta urinish', icon: Icons.refresh, onPressed: onRetry),
    );
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
