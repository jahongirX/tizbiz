import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/appointments/actions.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/features/appointments/widgets/client_picker.dart';
import 'package:tizbiz_biznes/features/appointments/widgets/rental_picker.dart';
import 'package:tizbiz_biznes/features/appointments/widgets/slot_picker.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Admin booking form (BIZNES-SPEC §9.4).
class AppointmentCreateScreen extends ConsumerStatefulWidget {
  const AppointmentCreateScreen({
    super.key,
    this.initialStaffId,
    this.initialDate,
    this.initialTime,
    this.initialClientId,
  });

  final int? initialStaffId;
  final LocalDate? initialDate;
  final HmTime? initialTime;
  final int? initialClientId;

  @override
  ConsumerState<AppointmentCreateScreen> createState() => _AppointmentCreateScreenState();
}

/// Server pointers -> form fields.
const _pointerName = {'name', 'client.name', 'client_name'};
const _pointerPhone = {'phone', 'client.phone', 'client_phone'};

class _AppointmentCreateScreenState extends ConsumerState<AppointmentCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _guests = TextEditingController();

  String _key = Idempotency.newKey();
  bool _submitted = false;
  bool _saving = false;
  bool _dirty = false;

  int? _staffId;
  int? _serviceId;
  late LocalDate _date;
  AvailabilitySlot? _slot;
  HmTime? _manual;
  RentalChoice? _rental;
  ClientMode _mode = ClientMode.existing;
  Client? _client;
  bool _clientSeeded = false;
  AppointmentStatus _status = AppointmentStatus.pending;

  String? _timeError;
  String? _banner;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _staffId = widget.initialStaffId;
    _manual = widget.initialTime;
    final a = ref.read(activeBusinessProvider);
    _date = widget.initialDate ?? bizToday(ref.read(clockProvider), a);
    _clientSeeded = widget.initialClientId == null;
    for (final c in [_name, _phone, _notes, _guests]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _notes, _guests]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Booking-defining change: new idempotency key, clear the time conflict.
  void _change(VoidCallback f) {
    setState(() {
      f();
      _dirty = true;
      _key = Idempotency.newKey();
      _timeError = null;
    });
  }

  ActiveBusiness get _a => ref.read(activeBusinessProvider)!;

  bool get _isRental => _a.engine == Engine.rental;

  String? _field(String pointer) => _fieldErrors[pointer];

  String? _fieldAny(Set<String> pointers) {
    for (final p in pointers) {
      final e = _fieldErrors[p];
      if (e != null) return e;
    }
    return null;
  }

  DateTime? get _startsAt {
    if (_manual != null) return Dates.localToUtc(_date, _manual!, _a.timezone);
    return _slot?.startUtc;
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    final formOk = _form.currentState?.validate() ?? false;
    final timeOk = _isRental ? _rental != null : _startsAt != null;
    final clientOk = _mode == ClientMode.newClient || _client != null;
    if (!timeOk) setState(() => _timeError = _isRental ? 'Seansni tanlang' : 'Vaqtni tanlang');
    if (!formOk || !timeOk || !clientOk) return;

    if (!_isRental) {
      final now = ref.read(clockProvider)();
      if (_startsAt!.isBefore(now)) {
        final ok = await confirmAction(
          context,
          title: "Bu vaqt o'tib ketgan. Baribir saqlansinmi?",
          confirmLabel: 'Saqlash',
        );
        if (!ok || !mounted) return;
      }
    }

    final notes = _notes.text.trim();
    final guests = int.tryParse(_guests.text.trim());
    final req = AdminBookingRequest(
      staffId: _staffId!,
      serviceId: _serviceId!,
      startsAt: _isRental ? null : _startsAt,
      date: _isRental ? _date : null,
      session: _isRental ? _rental!.session : null,
      guests: _isRental ? guests : null,
      clientId: _mode == ClientMode.existing ? _client!.id : null,
      clientName: _mode == ClientMode.newClient ? _name.text.trim() : null,
      clientPhone: _mode == ClientMode.newClient ? Phone.normalize(_phone.text) ?? _phone.text.trim() : null,
      notes: notes.isEmpty ? null : notes,
      status: _isRental ? null : _status,
    );

    setState(() => _saving = true);
    try {
      final res = await ref.read(appointmentActionsProvider).create(req, _key);
      if (!mounted) return;
      _dirty = false;
      showAppSnack(context, 'Yozuv yaratildi');
      context.pushReplacement(Routes.appointment(res.data.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _applyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyError(ApiException e) {
    if (e.isConflict) {
      _timeError = e.message;
      if (!_isRental && _staffId != null && _serviceId != null) {
        ref.invalidate(availabilityProvider((staffId: _staffId!, serviceId: _serviceId!, date: _date)));
      } else if (_isRental) {
        ref.invalidate(bookedDaysProvider(_a.slug));
      }
      return;
    }
    if (e.isValidation && e.hasFieldErrors) {
      _fieldErrors = e.fieldErrors;
      final shown = {
        'staff_id',
        'service_id',
        'starts_at',
        'date',
        'session',
        'notes',
        if (_isRental) 'guests',
        if (_mode == ClientMode.newClient) ...{..._pointerName, ..._pointerPhone},
      };
      final unmatched = [
        for (final entry in e.fieldErrors.entries)
          if (!shown.contains(entry.key)) entry.value,
      ];
      final timeErr = _field('starts_at') ?? _field('date') ?? _field('session');
      if (timeErr != null) _timeError = timeErr;
      _banner = unmatched.isEmpty ? null : unmatched.join('\n');
      return;
    }
    _banner = e.message;
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) return;
    final ok = await confirmAction(
      context,
      title: "O'zgarishlar saqlanmaydi. Chiqasizmi?",
      confirmLabel: 'Chiqish',
      destructive: true,
    );
    if (ok && mounted) {
      setState(() => _dirty = false);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.homeFor(_a));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeBusinessProvider);
    if (a == null) return const Scaffold(body: LoadingView());
    final staff = ref.watch(activeStaffProvider);
    final services = ref.watch(servicesListProvider);
    final categories = ref.watch(serviceCategoriesProvider);
    if (!_clientSeeded) {
      final initial = ref.watch(initialClientProvider(widget.initialClientId!));
      if (initial.hasValue) {
        _client = initial.requireValue;
        _clientSeeded = true;
      } else if (initial.hasError) {
        _clientSeeded = true;
      }
    }
    final loadError = staff.error ?? services.error;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Scaffold(
        appBar: AppBar(title: const Text('Yangi yozuv')),
        body: (!staff.hasValue || !services.hasValue)
            ? (loadError != null
                  ? ErrorView(
                      error: loadError,
                      onRetry: () {
                        ref.invalidate(staffListProvider);
                        ref.invalidate(servicesListProvider);
                      },
                    )
                  : const LoadingView())
            : _buildForm(context, a, staff.requireValue, services.requireValue, categories.value ?? const []),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ActiveBusiness a,
    List<Staff> staff,
    List<Service> services,
    List<ServiceCategory> cats,
  ) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final today = bizToday(ref.read(clockProvider), a);
    final rental = a.engine == Engine.rental;
    final staffIds = {for (final s in staff) s.id};
    final active = [
      for (final s in services)
        if (s.isActive) s,
    ];
    final serviceIds = {for (final s in active) s.id};
    if (_staffId != null && !staffIds.contains(_staffId)) _staffId = null;
    if (_serviceId != null && !serviceIds.contains(_serviceId)) _serviceId = null;
    final serviceItems = _serviceItems(active, cats, t, c);
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    return Form(
      key: _form,
      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            section(
              a.engine == Engine.medical ? 'Shifokor' : 'Xodim',
              DropdownButtonFormField<int>(
                key: const ValueKey('staff'),
                initialValue: _staffId,
                isExpanded: true,
                decoration: InputDecoration(hintText: 'Xodimni tanlang', errorText: _field('staff_id')),
                items: [
                  for (final s in staff)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        s.specialization == null ? s.name : '${s.name} · ${s.specialization}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (v) => v == null ? 'Xodimni tanlang' : null,
                onChanged: (v) => _change(() {
                  _staffId = v;
                  _slot = null;
                }),
              ),
            ),
            section(
              rental ? 'Buyum / zal' : 'Xizmat',
              DropdownButtonFormField<int>(
                key: const ValueKey('service'),
                initialValue: _serviceId,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: rental ? 'Buyum yoki zalni tanlang' : 'Xizmatni tanlang',
                  errorText: _field('service_id'),
                ),
                items: serviceItems,
                selectedItemBuilder: (ctx) => [
                  for (final item in serviceItems)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(_serviceName(active, item.value), overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (v) => v == null ? (rental ? 'Buyum yoki zalni tanlang' : 'Xizmatni tanlang') : null,
                onChanged: (v) => _change(() {
                  _serviceId = v;
                  _slot = null;
                }),
              ),
            ),
            if (rental)
              section(
                'Sana va seans',
                RentalPicker(
                  slug: a.slug,
                  today: today,
                  date: _date,
                  choice: _rental,
                  errorMessage: _timeError,
                  onDate: (d) => _change(() {
                    _date = d;
                    _rental = null;
                  }),
                  onChoice: (ch) => _change(() => _rental = ch),
                ),
              )
            else ...[
              section(
                'Sana',
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      locale: const Locale('uz'),
                      initialDate: _date.toUtcMidnight(),
                      firstDate: today.addDays(-365).toUtcMidnight(),
                      lastDate: today.addDays(365).toUtcMidnight(),
                    );
                    if (picked != null) {
                      _change(() {
                        _date = LocalDate.fromDateTime(picked);
                        _slot = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(UzDates.weekdayDayMonth(_date)),
                ),
              ),
              section(
                'Vaqt',
                SlotPicker(
                  staffId: _staffId,
                  serviceId: _serviceId,
                  date: _date,
                  selectedSlot: _slot,
                  manualTime: _manual,
                  errorMessage: _timeError,
                  onSlot: (s) => _change(() {
                    _slot = s;
                    _manual = null;
                  }),
                  onManual: (time) => _change(() {
                    _manual = time;
                    _slot = null;
                  }),
                ),
              ),
            ],
            if (rental)
              section(
                'Mehmonlar soni',
                TextFormField(
                  controller: _guests,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(hintText: 'Ixtiyoriy', errorText: _field('guests')),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    final n = int.tryParse(s);
                    return n == null || n < 1 || n > 5000 ? '1 dan 5000 gacha son kiriting' : null;
                  },
                ),
              ),
            section(
              'Mijoz',
              ClientPicker(
                mode: _mode,
                onMode: (m) => _change(() => _mode = m),
                selected: _client,
                onSelected: (cl) => _change(() => _client = cl),
                nameController: _name,
                phoneController: _phone,
                nameError: _fieldAny(_pointerName),
                phoneError: _fieldAny(_pointerPhone),
                clientError: _submitted && _mode == ClientMode.existing && _client == null ? 'Mijozni tanlang' : null,
              ),
            ),
            if (!rental)
              section(
                "Boshlang'ich holat",
                SegmentedButton<AppointmentStatus>(
                  segments: const [
                    ButtonSegment(value: AppointmentStatus.pending, label: Text('Kutilmoqda')),
                    ButtonSegment(value: AppointmentStatus.confirmed, label: Text('Tasdiqlangan')),
                    ButtonSegment(value: AppointmentStatus.arrived, label: Text('Keldi')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() {
                    _status = s.first;
                    _dirty = true;
                  }),
                ),
              ),
            section(
              'Izoh',
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(hintText: 'Ixtiyoriy', errorText: _field('notes')),
              ),
            ),
            if (_banner != null) ...[FormErrorBanner(message: _banner), const SizedBox(height: 12)],
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Saqlash'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _serviceName(List<Service> services, int? id) {
    for (final s in services) {
      if (s.id == id) return s.name;
    }
    return '';
  }

  /// Active services grouped by category (category order, then uncategorised "Boshqa"),
  /// with disabled header rows.
  List<DropdownMenuItem<int>> _serviceItems(
    List<Service> services,
    List<ServiceCategory> cats,
    TextTheme t,
    AppColors c,
  ) {
    final byCat = <int?, List<Service>>{};
    for (final s in services) {
      byCat.putIfAbsent(s.categoryId, () => []).add(s);
    }
    final known = {for (final cat in cats) cat.id};
    final groups = <({String? title, List<Service> items})>[
      for (final cat in cats)
        if (byCat[cat.id] != null) (title: cat.name, items: byCat[cat.id]!),
      if (byCat.entries.any((e) => !known.contains(e.key)))
        (
          title: cats.isEmpty ? null : 'Boshqa',
          items: [
            for (final e in byCat.entries)
              if (!known.contains(e.key)) ...e.value,
          ],
        ),
    ];
    var header = -1;
    return [
      for (final g in groups) ...[
        if (g.title != null)
          DropdownMenuItem<int>(
            value: header--,
            enabled: false,
            child: Text(
              g.title!,
              style: t.labelMedium?.copyWith(color: c.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
        for (final s in g.items)
          DropdownMenuItem<int>(
            value: s.id,
            child: Text(
              '${s.name} · ${UzDates.duration(s.durationMin)} · ${Money.format(s.priceTiyin)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ];
  }
}
