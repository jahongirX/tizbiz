import 'package:material_ui/material_ui.dart';

/// Temporary body of a route until its feature lands: AppBar(title) + "Tez orada".
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Tez orada')),
      );
}
