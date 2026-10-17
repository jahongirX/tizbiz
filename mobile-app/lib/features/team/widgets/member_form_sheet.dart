import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/team/actions.dart';
import 'package:tizbiz_biznes/features/team/providers.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kPasswordRequiredDetail = 'Yangi foydalanuvchi uchun parol talab qilinadi.';

/// Add (member == null) or edit (role + staff link) a team member. Pops with the saved member.
class MemberFormSheet extends ConsumerStatefulWidget {
  const MemberFormSheet({super.key, this.member});

  final TeamMember? member;

  static Future<TeamMember?> show(BuildContext context, {TeamMember? member}) => showModalBottomSheet<TeamMember>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => MemberFormSheet(member: member),
      );

  @override
  ConsumerState<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends ConsumerState<MemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  late BizRole _role;
  int? _staffId;
  bool _submitted = false;
  bool _saving = false;
  bool _dirty = false;
  Map<String, String> _fieldErrors = const {};
  String? _banner;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    _role = widget.member?.role ?? BizRole.staff;
    if (_role == BizRole.unknown) _role = BizRole.staff;
    _staffId = widget.member?.staffId;
    for (final c in [_phone, _name, _password]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  List<Staff> _staffOptions(List<Staff> all) {
    final me = widget.member?.userId;
    return [
      for (final s in all)
        if ((s.userId == null || (me != null && s.userId == me)) && (s.isActive || s.id == _staffId)) s,
    ];
  }

  void _applyError(Object e) {
    final fields = <String, String>{};
    String? banner;
    if (e is ApiException) {
      if (e.status == 400 && e.detail.trim() == kPasswordRequiredDetail) {
        fields['password'] = e.detail;
      } else if (e.isValidation && e.hasFieldErrors) {
        const known = {'phone', 'name', 'role', 'password', 'staff_id'};
        for (final entry in e.fieldErrors.entries) {
          if (known.contains(entry.key)) {
            fields[entry.key] = entry.value;
          } else {
            banner ??= entry.value;
          }
        }
      } else {
        banner = e.message;
      }
    } else {
      banner = errorText(e);
    }
    setState(() {
      _fieldErrors = fields;
      _banner = banner;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _fieldErrors = const {};
      _banner = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final actions = ref.read(teamActionsProvider);
    final member = widget.member;
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      TeamMember saved;
      if (member == null) {
        final pw = _password.text;
        saved = await actions.add(TeamMemberInput(
          phone: Phone.normalize(_phone.text) ?? _phone.text.trim(),
          name: _name.text.trim(),
          role: _role,
          password: pw.isEmpty ? null : pw,
          staffId: _staffId,
        ));
      } else {
        final roleChanged = _role != member.role;
        final linkChanged = _staffId != member.staffId;
        if (!roleChanged && !linkChanged) {
          nav.pop(member);
          return;
        }
        saved = await actions.patch(
          member.userId,
          TeamMemberPatch(
            role: roleChanged ? _role : null,
            staffId: linkChanged ? _staffId : null,
            unlinkStaff: linkChanged && _staffId == null,
          ),
        );
        if (member.userId == ref.read(currentUserIdProvider)) {
          await ref.read(sessionProvider.notifier).refreshMe();
        }
      }
      if (!mounted) return;
      nav.pop(saved);
    } catch (e) {
      if (!mounted) return;
      _applyError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _maybeLeave() async {
    final leave = await confirmAction(context,
        title: "O'zgarishlar saqlanmaydi. Chiqasizmi?", confirmLabel: 'Chiqish', destructive: true);
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final options = _staffOptions(staffAsync.value ?? const []);
    final selected = options.any((s) => s.id == _staffId) ? _staffId : null;
    final insets = MediaQuery.viewInsetsOf(context);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_isEdit ? (widget.member!.name ?? "A'zoni tahrirlash") : "A'zo qo'shish",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (!_isEdit) ...[
                  PhoneField(controller: _phone, errorText: _fieldErrors['phone'], enabled: !_saving),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 128,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: 'Ism', errorText: _fieldErrors['name'], counterText: ''),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Ismni kiriting' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<BizRole>(
                  key: const ValueKey('team-role'),
                  initialValue: _role,
                  decoration: InputDecoration(labelText: 'Rol', errorText: _fieldErrors['role']),
                  items: const [
                    DropdownMenuItem(value: BizRole.staff, child: Text('Xodim')),
                    DropdownMenuItem(value: BizRole.admin, child: Text('Administrator')),
                    DropdownMenuItem(value: BizRole.owner, child: Text('Egasi')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _role = v ?? BizRole.staff;
                            _dirty = true;
                          }),
                ),
                const SizedBox(height: 12),
                if (!_isEdit) ...[
                  TextFormField(
                    controller: _password,
                    enabled: !_saving,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Parol',
                      helperText: 'Yangi foydalanuvchi uchun majburiy',
                      errorText: _fieldErrors['password'],
                    ),
                    validator: (v) =>
                        (v ?? '').isNotEmpty && v!.length < 6 ? "Parol kamida 6 belgidan iborat bo'lsin" : null,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<int?>(
                  key: ValueKey('team-staff-${options.length}'),
                  initialValue: selected,
                  decoration: InputDecoration(
                    labelText: 'Xodim profili',
                    errorText: _fieldErrors['staff_id'],
                    helperText: staffAsync.hasError
                        ? "Xodimlar ro'yxati yuklanmadi: ${errorText(staffAsync.error!)}"
                        : (staffAsync.isLoading && !staffAsync.hasValue ? 'Yuklanmoqda...' : null),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text("Bog'lamaslik")),
                    for (final s in options) DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _staffId = v;
                            _dirty = true;
                          }),
                ),
                const SizedBox(height: 20),
                FormErrorBanner(message: _banner),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Saqlash' : "Qo'shish"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
