import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Tiyin shown as so'm: `Money.format` ("150 000 so'm") or `Money.compact` ("150 ming so'm").
class MoneyText extends StatelessWidget {
  const MoneyText(this.tiyin, {super.key, this.style, this.compact = false});

  final int? tiyin;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = tiyin;
    final text = t == null ? '—' : (compact ? Money.compact(t) : Money.format(t));
    return Text(text, style: style, maxLines: 1, softWrap: false);
  }
}
