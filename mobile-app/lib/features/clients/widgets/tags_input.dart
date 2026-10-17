import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

const kMaxTags = 10;
const kMaxTagLength = 32;

/// Error for adding [tag] to [tags], or null when it can be added.
String? tagError(String tag, List<String> tags) {
  final t = tag.trim();
  if (t.isEmpty) return null;
  if (t.length > kMaxTagLength) return 'Teg $kMaxTagLength belgidan oshmasligi kerak';
  if (tags.length >= kMaxTags) return "Ko'pi bilan $kMaxTags ta teg";
  if (tags.any((x) => x.toLowerCase() == t.toLowerCase())) return 'Bu teg allaqachon bor';
  return null;
}

/// Chips with delete + a field that adds a tag on Enter / comma (each ≤ 32 chars, max 10).
class TagsInput extends StatefulWidget {
  const TagsInput({super.key, required this.tags, required this.onChanged, this.errorText});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  /// Server-side error (pointer `tags`).
  final String? errorText;

  @override
  State<TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<TagsInput> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final t = raw.replaceAll(',', '').trim();
    final err = tagError(t, widget.tags);
    setState(() => _error = err);
    if (t.isEmpty || err != null) return;
    _ctrl.clear();
    widget.onChanged([...widget.tags, t]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in widget.tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => widget.onChanged([...widget.tags]..remove(tag)),
                    deleteButtonTooltipMessage: "O'chirish",
                  ),
              ],
            ),
          ),
        TextField(
          controller: _ctrl,
          enabled: widget.tags.length < kMaxTags,
          maxLength: kMaxTagLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Teglar',
            hintText: widget.tags.length < kMaxTags ? "Teg yozing va Enter bosing" : "Ko'pi bilan $kMaxTags ta teg",
            counterText: '',
            errorText: _error ?? widget.errorText,
            suffixIcon: IconButton(
              tooltip: "Qo'shish",
              icon: Icon(Icons.add, color: c.primary),
              onPressed: () => _add(_ctrl.text),
            ),
          ),
          onChanged: (v) {
            if (v.endsWith(',')) _add(v);
          },
          onSubmitted: _add,
        ),
      ],
    );
  }
}
