// Help & support chat (FR-054): instant AI answers, hand-off to the Tekto team on request.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_api.dart';

final supportMessagesProvider =
    StreamProvider.autoDispose<List<SupportMessage>>((ref) => ref.watch(supportApiProvider).watch());

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _ctrl = TextEditingController();
  final _sent = <SupportMessage>[];
  bool _sending = false;
  bool _waiting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send({bool human = false}) async {
    final l = AppLocalizations.of(context);
    final text = human && _ctrl.text.trim().isEmpty ? l.supportHumanMessage : _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = await ref.read(supportApiProvider).send(text, wantHuman: human);
      _ctrl.clear();
      setState(() {
        _sent.addAll(r.messages);
        _waiting = r.waitingForAgent;
      });
      ref.invalidate(supportMessagesProvider);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.supportError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final live = ref.watch(supportMessagesProvider).value ?? const [];
    final ids = {for (final m in live) m.id};
    final messages = [...live, ..._sent.where((m) => !ids.contains(m.id))]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Scaffold(
      appBar: AppBar(title: Text(l.supportTitle)),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                _Bubble(sender: 'ai', body: l.supportIntro, label: l.supportAi),
                for (final m in messages)
                  _Bubble(
                    key: ValueKey(m.id),
                    sender: m.sender,
                    body: m.body,
                    label: switch (m.sender) {
                      'agent' => l.supportAgent,
                      'ai' => l.supportAi,
                      _ => null,
                    },
                  ),
                if (_waiting)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(l.supportWaiting,
                        style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
          if (!_waiting)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                child: ActionChip(
                  key: const ValueKey('support-human'),
                  avatar: const Icon(Icons.support_agent_outlined, size: 18),
                  label: Text(l.supportHuman),
                  onPressed: _sending ? null : () => _send(human: true),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('support-input'),
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(hintText: l.supportHint, counterText: ''),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                key: const ValueKey('support-send'),
                tooltip: l.supportSend,
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.sender, required this.body, this.label});
  final String sender;
  final String body;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final mine = sender == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.glacier : (sender == 'agent' ? const Color(0xFF1E2A3A) : AppColors.deep),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null)
            Text(label!.toUpperCase(),
                style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: sender == 'agent' ? AppColors.mint : AppColors.glacier)),
          Text(body, style: TextStyle(color: mine ? AppColors.ink : null, height: 1.4)),
        ]),
      ),
    );
  }
}
