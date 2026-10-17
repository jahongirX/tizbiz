import 'package:material_ui/material_ui.dart';

/// Shown while the session boots (token + /auth/me).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/brand/tizbiz-logo.png', height: 48, semanticLabel: 'TizBiz'),
              const SizedBox(height: 24),
              const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
        ),
      );
}
