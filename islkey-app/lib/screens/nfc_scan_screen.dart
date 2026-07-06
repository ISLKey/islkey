import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/doors_provider.dart';
import '../services/nfc_service.dart';
import '../widgets/shared_widgets.dart';
import 'unlock_result_screen.dart';

class NfcScanScreen extends ConsumerStatefulWidget {
  final Color brandColour;

  const NfcScanScreen({super.key, required this.brandColour});

  @override
  ConsumerState<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends ConsumerState<NfcScanScreen> {
  bool _sessionStarted = false;
  bool _readHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    NfcService.stopSession();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_sessionStarted) return;
    _sessionStarted = true;

    ref.read(doorsProvider.notifier).startScanning();

    await NfcService.startSession(
      onRead: (uid) async {
        if (_readHandled) return;
        _readHandled = true;
        NfcService.stopSession();
        final attempted =
            await ref.read(doorsProvider.notifier).resolveAndUnlock(uid);
        if (!mounted) return;
        if (attempted) {
          _navigateToResult();
        } else {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Already sent — wait a moment before tapping again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onError: (error) {
        if (!mounted) return;
        ref.read(doorsProvider.notifier).reset();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => UnlockResultScreen(brandColour: widget.brandColour),
      ),
    );
  }

  void _cancel() {
    ref.read(doorsProvider.notifier).cancelScanning();
    NfcService.stopSession();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(doorsProvider.select((s) => s.unlockStatus));
    final busy = status == UnlockStatus.resolving ||
        status == UnlockStatus.unlocking;
    final busyLabel =
        status == UnlockStatus.resolving ? 'Reading door…' : 'Unlocking…';

    return Scaffold(
      backgroundColor: widget.brandColour,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    busy ? 'Please wait' : 'Ready to unlock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: busy ? null : _cancel,
                  ),
                ],
              ),
              const Spacer(),
              const PulsingRing(colour: Colors.white, size: 200),
              const SizedBox(height: 40),
              if (busy) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  busyLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ] else ...[
                const Text(
                  'Hold your phone near\nthe door reader',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The NFC tag is usually beside the door',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
              const Spacer(),
              if (!busy)
                TextButton(
                  onPressed: _cancel,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
