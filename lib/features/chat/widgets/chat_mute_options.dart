import 'package:flutter/material.dart';
import '../../../core/models/pocketbase_models.dart';
import '../chat_store.dart';

/// "Stäng av notiser" durations; null = until further notice.
const List<(String, Duration?)> chatMuteDurations = [
  ('1 timme', Duration(hours: 1)),
  ('8 timmar', Duration(hours: 8)),
  ('1 vecka', Duration(days: 7)),
  ('Tills vidare', null),
];

const List<String> _shortMonths = [
  'jan',
  'feb',
  'mar',
  'apr',
  'maj',
  'jun',
  'jul',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
];

/// "till 18 nov 14:30" / "tills vidare" (local time; the year is added when
/// it isn't the current one).
String chatMuteUntilText(ChatMutesRecord mute, {DateTime? now}) {
  final until = mute.until;
  if (until == null) return 'tills vidare';
  final t = until.toLocal();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final year = t.year != (now ?? DateTime.now()).year ? ' ${t.year}' : '';
  return 'till ${t.day} ${_shortMonths[t.month - 1]}$year $hh:$mm';
}

/// "Avstängt till 18 nov 14:30" / "Avstängt tills vidare".
String chatMuteHint(ChatMutesRecord mute, {DateTime? now}) =>
    'Avstängt ${chatMuteUntilText(mute, now: now)}';

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Picks a duration and mutes [roomId]. [context] must outlive the sheet
/// (the page, not a sheet that is being closed).
Future<void> showChatMuteDurationSheet(
  BuildContext context,
  ChatStore chatStore,
  String roomId,
) async {
  final picked = await showModalBottomSheet<(String, Duration?)>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Stäng av notiser',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Du får inga pushnotiser från den här chatten under tiden. '
              'Olästa meddelanden visas som vanligt.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          for (final option in chatMuteDurations)
            ListTile(
              leading: Icon(
                option.$2 == null
                    ? Icons.notifications_off_outlined
                    : Icons.schedule_outlined,
              ),
              title: Text(option.$1),
              onTap: () => Navigator.pop(ctx, option),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  final ok = await chatStore.muteRoom(roomId, picked.$2);
  if (!context.mounted) return;
  final mute = chatStore.activeMute(roomId);
  _snack(
    context,
    ok
        ? 'Notiserna är avstängda'
              '${mute == null ? '' : ' ${chatMuteUntilText(mute)}'}'
        : (chatStore.lastError ?? 'Kunde inte stänga av notiserna.'),
  );
}

/// The mute entry for a room's options sheet: "Stäng av notiser" (opens the
/// duration picker) or, when muted, "Slå på notiser" with when it ends.
/// [hostContext] is the page's context, used after the sheet has closed.
class ChatMuteTile extends StatelessWidget {
  final BuildContext hostContext;
  final ChatStore chatStore;
  final String roomId;

  const ChatMuteTile({
    super.key,
    required this.hostContext,
    required this.chatStore,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final mute = chatStore.activeMute(roomId);
    if (mute == null) {
      return ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: const Text('Stäng av notiser'),
        onTap: () {
          Navigator.pop(context);
          showChatMuteDurationSheet(hostContext, chatStore, roomId);
        },
      );
    }
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Slå på notiser'),
      subtitle: Text(chatMuteHint(mute)),
      onTap: () async {
        Navigator.pop(context);
        final ok = await chatStore.unmuteRoom(roomId);
        if (!hostContext.mounted) return;
        _snack(
          hostContext,
          ok
              ? 'Notiserna är påslagna'
              : (chatStore.lastError ?? 'Kunde inte slå på notiserna.'),
        );
      },
    );
  }
}
