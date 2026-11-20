import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/ui/coach_launcher.dart';
import 'package:tekto/features/settings/domain/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings (T091): language (FR-033), units (FR-034), health sync (FR-012), regenerate plan
/// (FR-046 / FR-002), subscription, data export and account deletion (FR-037), privacy policy
/// (FR-038). Preferences save to the device and sync later, so they work offline.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ExportLink? _export;
  bool _busy = false;

  SettingsService? get _service => ref.read(settingsServiceProvider);

  @override
  void initState() {
    super.initState();
    // The device may have changed zone since the last launch (travel).
    WidgetsBinding.instance.addPostFrameCallback((_) => _service?.syncTimezone().catchError((Object _) => false));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = ref.watch(settingsServiceProvider);
    final settings = service == null ? null : ref.watch(_settingsProvider(service)).value;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle), actions: const [CoachButton(screen: 'settings')]),
      body: ListView(
        children: [
          _SectionHeader(l.settingsPreferences),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'fr', label: Text('FR')),
              ],
              selected: {settings?.language ?? Localizations.localeOf(context).languageCode},
              onSelectionChanged: service == null ? null : (v) => service.setLanguage(v.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: Text(l.settingsUnits),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lb', label: Text('lb')),
              ],
              selected: {settings?.unit ?? 'kg'},
              onSelectionChanged: service == null ? null : (v) => service.setUnit(v.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline),
            title: Text(l.settingsHealthSync),
            value: settings?.healthSyncEnabled ?? false,
            onChanged: service == null ? null : service.setHealthSync,
            activeThumbColor: AppColors.glacier,
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l.settingsEditProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(l.settingsRegeneratePlan),
            enabled: !_busy && service != null,
            onTap: _regenerate,
          ),
          const Divider(),
          _SectionHeader(l.settingsSubscription),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(l.settingsManageSubscription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/subscription'),
          ),
          const Divider(),
          _SectionHeader(l.settingsAccount),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l.settingsExportData),
            subtitle: Text(l.settingsExportDataConfirm),
            enabled: !_busy && service != null,
            onTap: _exportData,
          ),
          if (_export case final link?)
            Card(
              key: const Key('export-link'),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: ListTile(
                title: Text(l.settingsExportReady),
                subtitle: SelectableText(link.url.toString(), maxLines: 2),
                trailing: TextButton(
                  onPressed: () => launchUrl(link.url, mode: LaunchMode.externalApplication),
                  child: Text(l.settingsExportOpen),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.settingsPrivacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(l.settingsDeleteAccount, style: const TextStyle(color: AppColors.danger)),
            enabled: !_busy && service != null,
            onTap: _deleteAccount,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(
      title: l.settingsRegeneratePlan,
      body: l.settingsRegeneratePlanBody,
      action: l.settingsRegenerateConfirm,
    );
    if (ok != true) return;
    await _run(() async {
      try {
        await _service!.regeneratePlan();
        if (mounted) _toast(l.settingsRegenerateDone);
      } on Object {
        if (mounted) _toast(l.settingsRegenerateFailed);
      }
    });
  }

  Future<void> _exportData() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      try {
        final link = await _service!.exportData();
        if (mounted) setState(() => _export = link);
      } on Object {
        if (mounted) _toast(l.settingsExportFailed);
      }
    });
  }

  /// Two steps (T091): an explanation, then a final, explicit confirmation.
  Future<void> _deleteAccount() async {
    final l = AppLocalizations.of(context);
    final first = await _confirm(
      title: l.settingsDeleteAccount,
      body: l.settingsDeleteAccountConfirm,
      action: l.settingsDeleteAccount,
      destructive: true,
    );
    if (first != true || !mounted) return;
    final second = await _confirm(
      title: l.settingsDeleteAccountFinalTitle,
      body: l.settingsDeleteAccountFinalBody,
      action: l.settingsDeleteAccountConfirmSecond,
      destructive: true,
    );
    if (second != true || !mounted) return;

    await _run(() async {
      try {
        await _service!.deleteAccount();
        HapticFeedback.mediumImpact();
        if (mounted) context.go('/onboarding/welcome');
      } on Object {
        if (mounted) _toast(l.settingsDeleteFailed);
      }
    });
  }

  Future<bool?> _confirm(
      {required String title, required String body, required String action, bool destructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

final _settingsProvider = StreamProvider.autoDispose.family<UserSettings?, SettingsService>((ref, s) => s.watch());

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.mist),
        ),
      );
}
