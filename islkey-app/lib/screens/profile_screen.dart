import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/sites_provider.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'link_site_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _websiteUrl = 'https://i-s-l.co.uk';
  static const _privacyUrl = 'https://i-s-l.co.uk/privacy';

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $url'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider.select((s) => s.profile));
    if (profile == null) return const SizedBox.shrink();

    final brandColour = ISLTheme.fromHex(profile.branding.brandColour);
    final linkedSites = ref.watch(sitesProvider);

    return Scaffold(
      backgroundColor: ISLTheme.background,
      appBar: AppBar(
        backgroundColor: brandColour,
        title: const Text('Profile'),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ISLTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: const Border.fromBorderSide(
                BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: brandColour.withOpacity(0.12),
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: brandColour,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ISLTheme.textPrimary,
                        ),
                      ),
                      Text(
                        profile.branding.customerName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ISLTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeading('Your Sites'),

          Container(
            decoration: BoxDecoration(
              color: ISLTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: const Border.fromBorderSide(
                BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              children: [
                _SiteRow(
                  name: profile.branding.customerName,
                  isPrimary: true,
                  colour: brandColour,
                ),
                for (final site in linkedSites)
                  _SiteRow(
                    name: site.siteName,
                    isPrimary: false,
                    colour: brandColour,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.add_business_outlined,
            label: 'Link to Another Site',
            colour: brandColour,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LinkSiteScreen(brandColour: brandColour),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeading('About'),

          _SettingsTile(
            icon: Icons.public,
            label: 'Visit our website',
            colour: brandColour,
            onTap: () => _openUrl(context, _websiteUrl),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            colour: brandColour,
            onTap: () => _openUrl(context, _privacyUrl),
          ),

          const SizedBox(height: 24),
          const SectionHeading('Session'),

          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            colour: ISLTheme.error,
            onTap: () => _confirmSignOut(context, ref),
          ),

          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                const Text(
                  'ISLKey by ISL Technologies',
                  style: TextStyle(fontSize: 11, color: ISLTheme.textMuted),
                ),
                const SizedBox(height: 2),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final v = snap.data;
                    final text = v == null
                        ? ''
                        : 'Version ${v.version} (${v.buildNumber})';
                    return Text(
                      text,
                      style: const TextStyle(
                          fontSize: 11, color: ISLTheme.textMuted),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Sign out',
                style: TextStyle(color: ISLTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.colour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ISLTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: colour, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colour,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colour.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  final String name;
  final bool isPrimary;
  final Color colour;

  const _SiteRow({
    required this.name,
    required this.isPrimary,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.business_outlined, color: colour, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ISLTheme.textPrimary,
              ),
            ),
          ),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colour.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Primary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colour,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
