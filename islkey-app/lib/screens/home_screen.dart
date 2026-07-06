import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/door.dart';
import '../providers/auth_provider.dart';
import '../providers/doors_provider.dart';
import '../services/nfc_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'history_screen.dart';
import 'nfc_scan_screen.dart';
import 'profile_screen.dart';
import 'unlock_result_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _busyDoorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(doorsProvider.notifier).loadDoors();
    });
  }

  Future<void> _startNfcScan(Color brandColour) async {
    final available = await NfcService.isAvailable();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFC is not available on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NfcScanScreen(brandColour: brandColour),
      ),
    );
  }

  Future<void> _unlockDirect(Door door, Color brandColour) async {
    setState(() => _busyDoorId = door.id);
    final attempted =
        await ref.read(doorsProvider.notifier).unlockDoorDirect(door);
    if (!mounted) return;
    setState(() => _busyDoorId = null);
    if (attempted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnlockResultScreen(brandColour: brandColour),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Just unlocked — wait a moment before trying again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider.select((s) => s.profile));
    final doorsState = ref.watch(doorsProvider);

    if (profile == null) return const SizedBox.shrink();
    final brandColour = ISLTheme.fromHex(profile.branding.brandColour);

    return Scaffold(
      backgroundColor: ISLTheme.background,
      appBar: AppBar(
        backgroundColor: brandColour,
        title: ISLLogo(logoUrl: profile.branding.logoUrl, height: 36),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Access history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(doorsProvider.notifier).loadDoors(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Hello, ${profile.name.split(' ').first}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ISLTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Tap-to-unlock NFC card (primary flow).
              _TapToUnlockCard(
                brandColour: brandColour,
                onTap: () => _startNfcScan(brandColour),
              ),

              if (doorsState.fromCache) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.cloud_off, size: 16, color: ISLTheme.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Showing saved doors — you appear to be offline.',
                      style: TextStyle(fontSize: 12, color: ISLTheme.textMuted),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),
              const SectionHeading('Your Doors'),
              const SizedBox(height: 4),
              _buildDoorList(doorsState, brandColour),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoorList(DoorsState state, Color brandColour) {
    switch (state.listStatus) {
      case DoorsListStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      case DoorsListStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              ErrorBanner(state.listError ?? 'Could not load your doors.'),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandColour),
                onPressed: () => ref.read(doorsProvider.notifier).loadDoors(),
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      case DoorsListStatus.ready:
        if (state.doors.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 56, color: ISLTheme.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'No doors assigned to you yet.',
                    style: TextStyle(color: ISLTheme.textMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final door in state.doors)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DoorCard(
                  door: door,
                  brandColour: brandColour,
                  busy: _busyDoorId == door.id,
                  onUnlock: () => _unlockDirect(door, brandColour),
                ),
              ),
          ],
        );
    }
  }
}

// ─── Tap-to-unlock card ───────────────────────────────────────────────────────

class _TapToUnlockCard extends StatelessWidget {
  final Color brandColour;
  final VoidCallback onTap;

  const _TapToUnlockCard({required this.brandColour, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: brandColour,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.nfc_rounded, color: Colors.white, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Tap to Unlock',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hold your phone near the reader by the door',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Door card ────────────────────────────────────────────────────────────────

class _DoorCard extends StatelessWidget {
  final Door door;
  final Color brandColour;
  final bool busy;
  final VoidCallback onUnlock;

  const _DoorCard({
    required this.door,
    required this.brandColour,
    required this.busy,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ISLTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      door.doorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ISLTheme.textPrimary,
                      ),
                    ),
                    if (door.description != null &&
                        door.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        door.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ISLTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusDot(door: door),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                door.isOnline ? 'Online' : 'Offline',
                door.isOnline ? ISLTheme.onlineColour : ISLTheme.offlineColour,
                door.isOnline ? Icons.wifi : Icons.wifi_off,
              ),
              if (door.fireAlarmActive)
                _chip('Fire alarm', ISLTheme.fireColour,
                    Icons.local_fire_department),
              if (!door.hasController)
                _chip('No controller', ISLTheme.offlineColour,
                    Icons.power_off),
              if (door.lastSeen != null && door.hasController)
                _chip(
                  'Seen ${DateFormat('d MMM HH:mm').format(door.lastSeen!.toLocal())}',
                  ISLTheme.offlineColour,
                  Icons.schedule,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: busy
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColour,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: door.canUnlock ? onUnlock : null,
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(_unlockLabel()),
                  ),
          ),
        ],
      ),
    );
  }

  String _unlockLabel() {
    if (door.fireAlarmActive) return 'Fire alarm active';
    if (!door.hasController) return 'No controller fitted';
    if (door.status != 'active') return 'Door inactive';
    return 'Unlock';
  }

  Widget _chip(String label, Color colour, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colour),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Door door;
  const _StatusDot({required this.door});

  @override
  Widget build(BuildContext context) {
    final Color colour;
    if (door.fireAlarmActive) {
      colour = ISLTheme.fireColour;
    } else if (door.isOnline) {
      colour = ISLTheme.onlineColour;
    } else {
      colour = ISLTheme.offlineColour;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
    );
  }
}
