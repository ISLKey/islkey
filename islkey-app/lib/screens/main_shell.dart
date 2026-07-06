import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fire_provider.dart';
import '../theme.dart';
import 'fire_screen.dart';
import 'home_screen.dart';

/// Role-conditional shell. A pure key holder sees just the Doors screen (the app
/// as it always was). When the logged-in person is also a fire marshal/warden,
/// a bottom navigation bar appears with Doors + Fire. The interface adapts to the
/// roles the person holds — this is the "ISL Platform App" pattern.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fireProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fire = ref.watch(fireProvider);

    // When a fire event becomes active, surface the Fire tab automatically.
    ref.listen(fireProvider, (prev, next) {
      final wasActive = prev?.activeIncident != null;
      final isActive = next.activeIncident != null;
      if (next.isMarshal && isActive && !wasActive && mounted) {
        setState(() => _index = 1);
      }
    });

    if (!fire.isMarshal) {
      // Unchanged single-screen experience for non-marshals.
      return const HomeScreen();
    }

    final alarmActive = fire.activeIncident != null;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), FireScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Doors',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alarmActive,
              backgroundColor: ISLTheme.fireColour,
              child: const Icon(Icons.local_fire_department_outlined),
            ),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: 'Fire',
          ),
        ],
      ),
    );
  }
}
