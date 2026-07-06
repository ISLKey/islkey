import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Navigate based on auth status once resolved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      switch (authState.status) {
        case AuthStatus.authenticated:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        case AuthStatus.unauthenticated:
        case AuthStatus.firstTimeSetup:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        case AuthStatus.loading:
          break;
      }
    });

    final branding = authState.profile?.branding;
    final colour = branding != null
        ? ISLTheme.fromHex(branding.brandColour)
        : ISLTheme.primary;

    return Scaffold(
      backgroundColor: colour,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ISLLogo(logoUrl: branding?.logoUrl, height: 72),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
