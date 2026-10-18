import 'dart:async';

import 'package:bizcat/shared/widgets/brand.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Cold-start screen (BIZCAT-SPEC §9.1). No logic: the router leaves it once the session is known.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// After this long a muted 'Ulanish sekin...' line appears (the restore keeps running).
  static const slowAfter = Duration(seconds: 8);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = BzColors.white.withValues(alpha: 0.7);
    return Scaffold(
      backgroundColor: BzColors.indigo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(variant: BrandLogoVariant.onDark, width: 168),
            const SizedBox(height: BzSpace.xxl),
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: BzColors.white,
                  backgroundColor: BzColors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            const SizedBox(height: BzSpace.l),
            AnimatedOpacity(
              opacity: _slow ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text('Ulanish sekin...', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
            ),
          ],
        ),
      ),
    );
  }
}
