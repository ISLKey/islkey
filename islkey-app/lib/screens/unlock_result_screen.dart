import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/doors_provider.dart';
import '../theme.dart';

class UnlockResultScreen extends ConsumerStatefulWidget {
  final Color brandColour;

  const UnlockResultScreen({super.key, required this.brandColour});

  @override
  ConsumerState<UnlockResultScreen> createState() => _UnlockResultScreenState();
}

class _UnlockResultScreenState extends ConsumerState<UnlockResultScreen>
    with SingleTickerProviderStateMixin {
  Timer? _autoDismiss;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim =
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _scaleController.forward();

    final status = ref.read(doorsProvider).unlockStatus;
    if (status == UnlockStatus.success) {
      _autoDismiss = Timer(const Duration(seconds: 3), _dismiss);
    }
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(doorsProvider.notifier).reset();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    // Refresh the door list so relay/last-seen state is current.
    ref.read(doorsProvider.notifier).loadDoors();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doorsProvider);
    final isSuccess = state.unlockStatus == UnlockStatus.success;
    final doorName = state.unlockDoorName;
    final message = isSuccess
        ? (state.unlockMessage ?? 'Unlock sent.')
        : (state.unlockError ?? 'Please contact your system manager.');

    final bgColour =
        isSuccess ? ISLTheme.unlockColour : ISLTheme.unlockErrorColour;

    return Scaffold(
      backgroundColor: bgColour,
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.lock_open_rounded
                          : Icons.error_outline_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isSuccess ? 'Unlocking' : 'Unable to unlock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                if (doorName != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    doorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Tap anywhere to dismiss',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
