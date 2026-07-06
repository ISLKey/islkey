import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureHttpForDebug();
  runApp(
    const ProviderScope(
      child: ISLKeyApp(),
    ),
  );
}

class ISLKeyApp extends ConsumerWidget {
  const ISLKeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Apply customer branding as theme once loaded.
    final brandColour = authState.profile?.branding.brandColour;
    final themeColour =
        brandColour != null ? ISLTheme.fromHex(brandColour) : ISLTheme.primary;

    return MaterialApp(
      title: 'ISLKey',
      debugShowCheckedModeBanner: false,
      theme: ISLTheme.buildTheme(themeColour),
      home: const SplashScreen(),
    );
  }
}
