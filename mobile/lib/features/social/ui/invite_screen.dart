// Opening a friend's invite link (FR-049): accepting makes you friends at once.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/social_api.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(socialApiProvider).acceptInvite(widget.code);
      ref
        ..invalidate(leaderboardProvider)
        ..invalidate(feedProvider);
      if (mounted) context.go('/friends');
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).friendsInviteInvalid;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.group_add_outlined, size: 48, color: AppColors.glacier),
              const SizedBox(height: AppSpacing.base),
              Text(l.friendsInviteTitle, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(l.friendsInviteAcceptBody, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.base),
                Text(_error!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: _busy ? null : _accept, child: Text(l.friendsAccept)),
            ]),
      ),
    );
  }
}
