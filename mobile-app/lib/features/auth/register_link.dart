import 'package:url_launcher/url_launcher.dart';

/// Public sign-up page of the corporate site.
final Uri kRegisterUri = Uri.parse('https://tizbiz.uz/register');

/// Opens tizbiz.uz/register in the external browser.
Future<void> openRegister() async {
  await launchUrl(kRegisterUri, mode: LaunchMode.externalApplication);
}
