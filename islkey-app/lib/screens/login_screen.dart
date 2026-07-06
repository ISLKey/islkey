import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/isl_error_codes.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  void _onDigit(String digit) {
    if (_pin.length >= 8) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _login() async {
    if (_pin.length < 4) {
      setState(() => _error = 'Enter your PIN to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).pinLogin(pin: _pin);
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
          case 401:
            msg = 'Incorrect PIN. Please try again.';
          case 404:
            msg = 'Account not found. Please contact your manager.';
          case 403:
            msg = 'Your account has been deactivated. Please contact your manager.';
          default:
            msg = e.message;
        }
      }
      setState(() {
        _error = msg;
        _pin = '';
        _loading = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _pin = '';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      authProvider.select((s) => s.profile != null),
    );
    final branding = ref.watch(
      authProvider.select((s) => s.profile?.branding),
    );
    final brandColour = branding != null
        ? ISLTheme.fromHex(branding.brandColour)
        : ISLTheme.primary;

    return Scaffold(
      backgroundColor: ISLTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              ISLLogo(logoUrl: branding?.logoUrl),
              const SizedBox(height: 12),
              if (branding != null)
                Text(
                  branding.customerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: brandColour,
                  ),
                ),
              const SizedBox(height: 48),
              const Text(
                'Enter your PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ISLTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              PinDisplay(
                filledCount: _pin.length,
                totalCount: 8,
                colour: brandColour,
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              NumericKeypad(
                onDigit: _onDigit,
                onDelete: _onDelete,
                colour: brandColour,
              ),
              const SizedBox(height: 24),
              if (_loading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: brandColour),
                  onPressed: _pin.length >= 4 ? _login : null,
                  child: const Text('Sign in'),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Forgotten PIN'),
                      content: const Text(
                        'Contact your system manager to reset your PIN.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Forgotten your PIN?',
                  style: TextStyle(color: ISLTheme.textMuted, fontSize: 13),
                ),
              ),
              if (!hasProfile)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    );
                  },
                  child: const Text(
                    'Set up for the first time',
                    style: TextStyle(color: ISLTheme.textMuted, fontSize: 13),
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
