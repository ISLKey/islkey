import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/doors_provider.dart';
import '../providers/sites_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

/// Lets a user link their account to an additional site by entering the site
/// code shown in that site's ISLKey admin. Calls POST /site/link.
class LinkSiteScreen extends ConsumerStatefulWidget {
  final Color brandColour;

  const LinkSiteScreen({super.key, required this.brandColour});

  @override
  ConsumerState<LinkSiteScreen> createState() => _LinkSiteScreenState();
}

class _LinkSiteScreenState extends ConsumerState<LinkSiteScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the site code from your admin.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(sitesProvider.notifier).link(code);
      if (!mounted) return;
      // Refresh doors so the newly linked site's doors appear.
      ref.read(doorsProvider.notifier).loadDoors();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      String msg;
      switch (e.statusCode) {
        case 409:
          msg = 'You are already linked to this site.';
        case 422:
          msg = 'Site code not found. Please check and try again.';
        default:
          msg = e.message;
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
      appBar: AppBar(
        backgroundColor: widget.brandColour,
        title: const Text('Link Another Site'),
        leading: const BackButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Enter the site code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ISLTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your site administrator shows this code in the ISLKey admin. '
              'Linking lets you unlock that site\'s doors with the same PIN.',
              style: TextStyle(fontSize: 14, color: ISLTheme.textMuted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _link(),
              inputFormatters: [
                _UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                hintText: 'e.g. TE2001',
                filled: true,
                fillColor: ISLTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.brandColour,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _link,
                child: const Text('Link Site'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Forces text input to upper-case as the user types (site codes are upper-case).
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
