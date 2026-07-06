import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/isl_error_codes.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'home_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1 — API base URL
  final _apiController =
      TextEditingController(text: 'https://i-s-l.co.uk/wp-json/');

  // Step 2 — Setup code + name
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  // Step 3 — PIN
  String _pin = '';
  String _confirmPin = '';
  bool _confirmingPin = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _apiController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage++;
      _error = null;
    });
  }

  void _onPinDigit(String digit) {
    setState(() {
      if (!_confirmingPin) {
        if (_pin.length < 8) _pin += digit;
      } else {
        if (_confirmPin.length < 8) _confirmPin += digit;
      }
      _error = null;
    });
  }

  void _onPinDelete() {
    setState(() {
      if (!_confirmingPin) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
      _error = null;
    });
  }

  void _confirmPinEntry() {
    if (_pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    setState(() {
      _confirmingPin = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_confirmPin != _pin) {
      setState(() => _error = 'PINs do not match. Please try again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).acceptInvitation(
            apiBase: _apiController.text.trim(),
            setupCode: _codeController.text.trim(),
            name: _nameController.text.trim(),
            pin: _pin,
          );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on ApiException catch (e) {
      String msg;
      final mapped = IslErrorCodes.messageFor(e.code);
      if (mapped != null) {
        msg = mapped;
      } else {
        switch (e.statusCode) {
          case 404:
            msg = 'This setup code is invalid or has already been used. '
                'Please ask your manager to send a new invitation.';
          case 410:
            msg = 'This setup code has expired. '
                'Please ask your manager to send a new invitation.';
          case 422:
            msg = 'Your PIN must be 4–8 digits.';
          default:
            msg = e.message;
        }
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ISLTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: ISLTheme.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(ISLTheme.primary),
              minHeight: 3,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepServer(controller: _apiController, onNext: _goNext),
                  _StepCode(
                    codeController: _codeController,
                    nameController: _nameController,
                    onNext: _goNext,
                  ),
                  _StepPin(
                    pin: _pin,
                    confirmPin: _confirmPin,
                    confirmingPin: _confirmingPin,
                    loading: _loading,
                    error: _error,
                    onDigit: _onPinDigit,
                    onDelete: _onPinDelete,
                    onConfirmTap: _confirmPinEntry,
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Server URL ───────────────────────────────────────────────────────

class _StepServer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;

  const _StepServer({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const ISLLogo(),
          const SizedBox(height: 40),
          const Text(
            'Welcome to ISLKey',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ISLTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the server address your manager provided.',
            style: TextStyle(fontSize: 15, color: ISLTheme.textMuted),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Server address',
              hintText: 'https://yourcompany.com/wp-json/',
            ),
          ),
          const Spacer(),
          ElevatedButton(onPressed: onNext, child: const Text('Continue')),
        ],
      ),
    );
  }
}

// ─── Step 2: Setup code + name ────────────────────────────────────────────────

class _StepCode extends StatelessWidget {
  final TextEditingController codeController;
  final TextEditingController nameController;
  final VoidCallback onNext;

  const _StepCode({
    required this.codeController,
    required this.nameController,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Enter your setup code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ISLTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your invitation email for the setup code.',
            style: TextStyle(fontSize: 15, color: ISLTheme.textMuted),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your full name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Setup code'),
          ),
          const Spacer(),
          ElevatedButton(onPressed: onNext, child: const Text('Continue')),
        ],
      ),
    );
  }
}

// ─── Step 3: PIN creation ─────────────────────────────────────────────────────

class _StepPin extends StatelessWidget {
  final String pin;
  final String confirmPin;
  final bool confirmingPin;
  final bool loading;
  final String? error;
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onConfirmTap;
  final VoidCallback onSubmit;

  const _StepPin({
    required this.pin,
    required this.confirmPin,
    required this.confirmingPin,
    required this.loading,
    required this.error,
    required this.onDigit,
    required this.onDelete,
    required this.onConfirmTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final displayPin = confirmingPin ? confirmPin : pin;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            confirmingPin ? 'Confirm your PIN' : 'Create a PIN',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ISLTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            confirmingPin
                ? 'Enter your PIN again to confirm.'
                : 'You will use this PIN every time you open the app.',
            style: const TextStyle(fontSize: 15, color: ISLTheme.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          PinDisplay(
            filledCount: displayPin.length,
            totalCount: 8,
            colour: ISLTheme.primary,
          ),
          const SizedBox(height: 24),
          if (error != null) ...[
            ErrorBanner(error!),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          NumericKeypad(
            onDigit: onDigit,
            onDelete: onDelete,
            colour: ISLTheme.primary,
          ),
          const SizedBox(height: 24),
          if (loading)
            const CircularProgressIndicator()
          else if (!confirmingPin)
            ElevatedButton(
              onPressed: pin.length >= 4 ? onConfirmTap : null,
              child: const Text('Set PIN'),
            )
          else
            ElevatedButton(
              onPressed: confirmPin.length >= 4 ? onSubmit : null,
              child: const Text('Confirm and finish setup'),
            ),
        ],
      ),
    );
  }
}
