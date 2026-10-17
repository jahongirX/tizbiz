import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kReplyMaxLength = 1000;

String? validateReply(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return 'Javob matnini kiriting';
  if (t.length > kReplyMaxLength) return 'Javob $kReplyMaxLength belgidan oshmasligi kerak';
  return null;
}

/// Bottom sheet that writes or edits the business reply; pops the saved [Review].
class ReplySheet extends StatefulWidget {
  const ReplySheet({super.key, required this.review, required this.onSubmit});

  final Review review;
  final Future<Review> Function(String text) onSubmit;

  static Future<Review?> show(BuildContext context, {required Review review, required Future<Review> Function(String) onSubmit}) =>
      showModalBottomSheet<Review>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ReplySheet(review: review, onSubmit: onSubmit),
      );

  @override
  State<ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<ReplySheet> {
  final _form = GlobalKey<FormState>();
  late final _ctrl = TextEditingController(text: widget.review.reply ?? '');
  bool _submitted = false;
  bool _saving = false;
  String? _fieldError;
  String? _formError;

  bool get _dirty => _ctrl.text != (widget.review.reply ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _fieldError = null;
      _formError = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSubmit(_ctrl.text.trim());
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldError = e.fieldErrors['reply'];
        _formError = _fieldError == null ? e.message : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = 'Xatolik yuz berdi.';
      });
    }
  }

  Future<void> _maybeLeave() async {
    final leave = await confirmAction(context, title: "O'zgarishlar saqlanmaydi. Chiqasizmi?", confirmLabel: 'Chiqish');
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(r.hasReply ? 'Javobni tahrirlash' : 'Javob berish', style: Theme.of(context).textTheme.titleMedium),
              if ((r.comment ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${r.authorName}: ${r.comment!.trim()}', maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                maxLength: kReplyMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Javobingiz',
                  alignLabelWithHint: true,
                  errorText: _fieldError,
                ),
                validator: validateReply,
                onChanged: (_) => setState(() {}),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 8),
                FormErrorBanner(message: _formError),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Yuborish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
