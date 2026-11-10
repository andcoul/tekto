import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// General settings screen — Preferences, Subscription, Account.
///
/// Routes: /settings
///
/// Fulfils FR-033, FR-034, FR-037, FR-038.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _language = 'en';
  String _units = 'kg';
  bool _healthSync = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ---- Preferences ----
          _SectionHeader('Preferences'),

          // Language toggle
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'fr', label: Text('FR')),
              ],
              selected: {_language},
              onSelectionChanged: (vals) => _setLanguage(vals.first),
            ),
          ),

          // Units toggle
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Units'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lb', label: Text('lb')),
              ],
              selected: {_units},
              onSelectionChanged: (vals) => _setUnits(vals.first),
            ),
          ),

          // Health sync toggle
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline),
            title: const Text('Health sync'),
            subtitle: const Text('Sync workouts to Apple Health / Google Fit'),
            value: _healthSync,
            onChanged: _setHealthSync,
            activeColor: AppColors.accent,
          ),

          const Divider(),

          // ---- Subscription ----
          _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Manage subscription'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/subscription'),
          ),

          const Divider(),

          // ---- Account ----
          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            subtitle: const Text('your@email.com'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete account',
                style: TextStyle(color: Colors.red)),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _language = lang);
    // Persist to Supabase
    try {
      final client = ref.read(tektoApiClientProvider);
      await client.patch<void>(
        '/rest/v1/users',
        data: {'language': lang},
        queryParameters: {'id': 'eq.me'},
      );
    } catch (_) {}
  }

  Future<void> _setUnits(String unit) async {
    setState(() => _units = unit);
    try {
      final client = ref.read(tektoApiClientProvider);
      await client.patch<void>(
        '/rest/v1/users',
        data: {'unit': unit},
        queryParameters: {'id': 'eq.me'},
      );
    } catch (_) {}
  }

  Future<void> _setHealthSync(bool enabled) async {
    setState(() => _healthSync = enabled);
    try {
      final client = ref.read(tektoApiClientProvider);
      await client.patch<void>(
        '/rest/v1/users',
        data: {'health_sync_enabled': enabled},
        queryParameters: {'id': 'eq.me'},
      );
    } catch (_) {}
  }

  Future<void> _exportData() async {
    try {
      final client = ref.read(tektoApiClientProvider);
      final resp = await client.post<Map<String, dynamic>>(
        '/functions/v1/export-data',
        data: {},
      );
      final url = resp.data?['download_url'] as String?;
      if (url != null && mounted) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and all data. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final client = ref.read(tektoApiClientProvider);
      await client.delete<void>(
        '/functions/v1/delete-account',
        data: {'confirm': true},
      );
      if (mounted) context.go('/auth');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.only(left: 16, top: 16, bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.onDarkSecondary,
              ),
        ),
      );
}
