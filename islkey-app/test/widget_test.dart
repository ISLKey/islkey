import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:islkey/main.dart';

void main() {
  testWidgets('ISLKey app boots to the splash screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ISLKeyApp()),
    );

    // The splash screen shows the ISLKey logo fallback and a progress spinner
    // while auth state resolves.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
