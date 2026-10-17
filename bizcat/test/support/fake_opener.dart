import 'package:bizcat/core/launcher.dart';

/// Records every opened [Uri]; answers [result] (default true).
final class FakeUrlOpener implements UrlOpener {
  FakeUrlOpener({this.result = true});

  final List<Uri> opened = [];

  /// What [open] returns (set false to simulate "cannot open").
  bool result;

  Uri? get last => opened.isEmpty ? null : opened.last;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
