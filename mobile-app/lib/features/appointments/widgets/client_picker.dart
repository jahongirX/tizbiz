import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

enum ClientMode { existing, newClient }

/// "Mavjud mijoz" (search, debounce 300 ms) / "Yangi mijoz" (name + phone).
class ClientPicker extends ConsumerStatefulWidget {
  const ClientPicker({
    super.key,
    required this.mode,
    required this.onMode,
    required this.selected,
    required this.onSelected,
    required this.nameController,
    required this.phoneController,
    this.nameError,
    this.phoneError,
    this.clientError,
  });

  final ClientMode mode;
  final ValueChanged<ClientMode> onMode;
  final Client? selected;
  final ValueChanged<Client?> onSelected;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String? nameError;
  final String? phoneError;

  /// "Mijozni tanlang" after a submit without a client.
  final String? clientError;

  @override
  ConsumerState<ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<ClientPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ClientMode>(
          segments: const [
            ButtonSegment(value: ClientMode.existing, label: Text('Mavjud mijoz'), icon: Icon(Icons.search)),
            ButtonSegment(value: ClientMode.newClient, label: Text('Yangi mijoz'), icon: Icon(Icons.person_add_alt)),
          ],
          selected: {widget.mode},
          onSelectionChanged: (s) => widget.onMode(s.first),
        ),
        const SizedBox(height: 12),
        if (widget.mode == ClientMode.newClient) ...[
          TextFormField(
            controller: widget.nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 128,
            decoration: InputDecoration(labelText: 'Ism', counterText: '', errorText: widget.nameError),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Ismni kiriting' : null,
          ),
          const SizedBox(height: 12),
          PhoneField(controller: widget.phoneController, errorText: widget.phoneError),
        ] else if (widget.selected != null)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.selected!.name),
              subtitle: Text(Phone.format(widget.selected!.phone)),
              trailing: TextButton(onPressed: () => widget.onSelected(null), child: const Text("O'zgartirish")),
            ),
          )
        else ...[
          TextField(
            controller: _search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Ism yoki telefon',
              errorText: widget.clientError,
            ),
            onChanged: _onSearch,
          ),
          const SizedBox(height: 8),
          _Results(query: _query, onSelected: widget.onSelected),
        ],
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.onSelected});

  final String query;
  final ValueChanged<Client?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final value = ref.watch(clientSearchProvider(query));
    if (value.hasValue) {
      final list = value.requireValue;
      if (list.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            query.isEmpty ? "Hali mijozlar yo'q. Yangi mijoz qo'shing." : 'Mijoz topilmadi',
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        );
      }
      return Column(
        children: [
          for (final cl in list)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(cl.name),
              subtitle: Text(Phone.format(cl.phone)),
              trailing: cl.visits == null ? null : Text('${cl.visits} tashrif', style: t.bodySmall),
              onTap: () => onSelected(cl),
            ),
        ],
      );
    }
    if (value.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(errorText(value.error!), style: t.bodySmall?.copyWith(color: c.danger)),
          ),
          TextButton(onPressed: () => ref.invalidate(clientSearchProvider(query)), child: const Text('Qayta urinish')),
        ],
      );
    }
    return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2));
  }
}
