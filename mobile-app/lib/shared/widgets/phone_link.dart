import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// '+998 90 123 45 67' that dials on tap; '—' for null/empty.
class PhoneLink extends StatelessWidget {
  const PhoneLink(this.phone, {super.key, this.style});

  final String? phone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = phone?.trim();
    if (p == null || p.isEmpty) return Text('—', style: style);
    final uri = Phone.telUri(p);
    final text = Text(
      Phone.format(p),
      style: (style ?? const TextStyle()).copyWith(color: Theme.of(context).colorScheme.primary),
    );
    if (uri == null) return Text(Phone.format(p), style: style);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => launchUrl(uri),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: text),
    );
  }
}
