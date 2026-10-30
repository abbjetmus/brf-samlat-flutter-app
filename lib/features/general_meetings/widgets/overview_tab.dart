import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/help_tip.dart';
import '../general_meetings_models.dart';
import 'general_meeting_status_chip.dart';

/// Datum, plats, digitalt deltagande och viktiga tider för stämman. Styrelsen
/// ([canManage]) ser också nästa steg: skicka kallelse, starta stämman, digital
/// röstning och avsluta stämman.
class OverviewTab extends CompositionWidget {
  const OverviewTab({
    super.key,
    required this.meeting,
    required this.itemCount,
    required this.onRefresh,
    this.canManage = false,
    this.onEdit,
  });

  final GeneralMeeting meeting;
  final int itemCount;
  final Future<void> Function() onRefresh;
  final bool canManage;
  final VoidCallback? onEdit;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();
    final busy = ref(false);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> publish() async {
      final meeting = props.value.meeting;
      busy.value = true;
      NoticeCheck check;
      try {
        check = await store.noticeCheck(meeting.id);
      } catch (e) {
        busy.value = false;
        snack(
          generalMeetingErrorMessage(e, 'Kunde inte kontrollera kallelsetiden'),
        );
        return;
      }
      busy.value = false;
      if (check.blocking) {
        snack(check.message);
        return;
      }
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (_) => _PublishDialog(check: check),
      );
      if (confirmed != true) return;
      busy.value = true;
      try {
        final (emailed, failed) = await store.publish(
          meeting.id,
          confirmOutsidePeriod: !check.ok,
        );
        snack(
          'Kallelsen är skickad till $emailed medlemmar'
          '${failed > 0 ? ' ($failed mejl kunde inte skickas)' : ''}',
        );
        await props.value.onRefresh();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte skicka kallelsen'));
      } finally {
        busy.value = false;
      }
    }

    Future<void> setStatus(String status) async {
      if (status == GeneralMeetingStatus.closed) {
        final ctx = contextRef.value;
        if (ctx == null || !ctx.mounted) return;
        final ok = await showConfirmDialog(
          ctx,
          title: 'Avsluta stämman',
          message:
              'Alla öppna omröstningar stängs och digital röstning stängs av. '
              'Därefter kan protokollet justeras.',
          okLabel: 'Avsluta',
        );
        if (!ok) return;
      }
      busy.value = true;
      try {
        await store.updateMeeting(props.value.meeting.id, {'status': status});
        snack(
          status == GeneralMeetingStatus.ongoing
              ? 'Stämman har startat'
              : 'Stämman är avslutad',
        );
        await props.value.onRefresh();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte ändra status'));
      } finally {
        busy.value = false;
      }
    }

    Future<void> setVotingOpen(bool value) async {
      busy.value = true;
      try {
        await store.updateMeeting(props.value.meeting.id, {
          'voting_open': value,
        });
        await props.value.onRefresh();
      } catch (e) {
        snack(
          generalMeetingErrorMessage(e, 'Kunde inte ändra digital röstning'),
        );
      } finally {
        busy.value = false;
      }
    }

    return (context) {
      final m = props.value.meeting;
      final canManage = props.value.canManage;
      final deadline = formatMeetingDate(m.motionDeadline);

      return RefreshIndicator(
        onRefresh: props.value.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (canManage)
              const HelpTip(
                id: 'general-meeting-overview',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Stämman går igenom fyra steg: Utkast → Kallad → Pågår → '
                    'Avslutad. Kallelsen skickas till alla medlemmar med e-post '
                    'och notis. Starta stämman när den börjar för att kunna '
                    'öppna omröstningar, och avsluta den när den är klar så att '
                    'protokollet kan justeras.',
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: canManage
                  ? _Steps(status: m.status)
                  : GeneralMeetingStatusChip(meeting: m),
            ),
            const SizedBox(height: 12),
            if (canManage) ...[
              _NextStepCard(
                meeting: m,
                busy: busy.value,
                onPublish: publish,
                onEdit: props.value.onEdit,
                onStart: () => setStatus(GeneralMeetingStatus.ongoing),
                onEnd: () => setStatus(GeneralMeetingStatus.closed),
                onVotingOpen: setVotingOpen,
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.event,
                    title: 'Tid',
                    value: formatMeetingDateTime(m.startAt),
                  ),
                  _InfoTile(
                    icon: Icons.place_outlined,
                    title: 'Plats',
                    value: m.location.isEmpty ? 'Meddelas senare' : m.location,
                  ),
                  if (m.digital)
                    _InfoTile(
                      icon: Icons.videocam_outlined,
                      title: 'Digitalt deltagande',
                      value: m.digitalInfo.isEmpty
                          ? 'Ja — rösta i appen när omröstningen öppnas.'
                          : m.digitalInfo,
                    ),
                  if (deadline.isNotEmpty || (canManage && m.motionsOpen))
                    _InfoTile(
                      icon: Icons.edit_note,
                      title:
                          'Sista dag för motioner'
                          '${canManage && !m.motionsOpen ? ' · tar inte emot motioner' : ''}',
                      value: deadline.isEmpty
                          ? 'Ingen sista dag angiven'
                          : deadline,
                    ),
                  if (m.noticeSentAt.isNotEmpty)
                    _InfoTile(
                      icon: Icons.mail_outline,
                      title: 'Kallelse skickad',
                      value: formatMeetingDate(m.noticeSentAt),
                    ),
                  _InfoTile(
                    icon: Icons.how_to_vote_outlined,
                    title: 'Rösträtt',
                    value: m.voteMode == 'per_member'
                        ? 'En röst per medlem'
                        : 'En röst per bostad',
                  ),
                ],
              ),
            ),
            if (m.description.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(m.description.trim()),
            ],
            if (!canManage) ...[
              if (m.status == GeneralMeetingStatus.draft) ...[
                const SizedBox(height: 16),
                const _Hint(
                  icon: Icons.info_outline,
                  text:
                      'Styrelsen tar emot motioner inför stämman. Kallelse och '
                      'dagordning kommer senare.',
                ),
              ] else if (props.value.itemCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Dagordningen har ${props.value.itemCount} punkter.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 16),
              const _Hint(
                icon: Icons.groups_outlined,
                text:
                    'Kan du inte delta kan du ge en fullmakt till någon annan '
                    'under Fullmakt.',
              ),
            ],
            if (m.digital) ...[
              const SizedBox(height: 12),
              const _Hint(icon: Icons.gavel_outlined, text: legalNote),
            ],
          ],
        ),
      );
    };
  }
}

/// Utkast → Kallad → Pågår → Avslutad, med de passerade stegen ifyllda.
class _Steps extends StatelessWidget {
  const _Steps({required this.status});

  final String status;

  static const _steps = [
    GeneralMeetingStatus.draft,
    GeneralMeetingStatus.called,
    GeneralMeetingStatus.ongoing,
    GeneralMeetingStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = _steps.indexOf(status);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, step) in _steps.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: i <= index ? scheme.primary : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.primary),
            ),
            child: Text(
              meetingStatusLabels[step] ?? step,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: i <= index ? scheme.onPrimary : scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.meeting,
    required this.busy,
    required this.onPublish,
    required this.onEdit,
    required this.onStart,
    required this.onEnd,
    required this.onVotingOpen,
  });

  final GeneralMeeting meeting;
  final bool busy;
  final VoidCallback onPublish;
  final VoidCallback? onEdit;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<bool> onVotingOpen;

  @override
  Widget build(BuildContext context) {
    final caption = TextStyle(color: Colors.grey[600], fontSize: 13);
    final List<Widget> children;
    switch (meeting.status) {
      case GeneralMeetingStatus.draft:
        children = [
          Text(
            'Kontrollera dagordningen och skicka kallelsen. Då skapas '
            'röstlängden från bostäderna och stämman läggs in i kalendern.',
            style: caption,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onPublish,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Skicka kallelse'),
          ),
          if (onEdit != null)
            TextButton.icon(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Redigera uppgifter'),
            ),
        ];
      case GeneralMeetingStatus.called:
        children = [
          Text(
            'Starta stämman när den börjar. Därefter kan du öppna omröstningar '
            'på beslutspunkterna.',
            style: caption,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Starta stämman'),
          ),
        ];
      case GeneralMeetingStatus.ongoing:
        children = [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Digital röstning'),
            value: meeting.votingOpen,
            onChanged: busy ? null : onVotingOpen,
          ),
          Text(
            meeting.votingOpen
                ? 'Medlemmarna kan rösta i appen och på webben när du öppnar en '
                      'omröstning.'
                : 'Av: rösterna räknas i lokalen och förs in för hand under '
                      'Omröstning.',
            style: caption,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onEnd,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Avsluta stämman'),
          ),
        ];
      default:
        children = [
          Text(
            'Stämman är avslutad. Skriv besluten under Protokoll och skicka '
            'protokollet för justering.',
            style: caption,
          ),
        ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nästa steg',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Bekräftelse innan kallelsen skickas. Utanför stadgarnas kallelsetid måste
/// styrelsen bocka i att den har kontrollerat stadgarna.
class _PublishDialog extends CompositionWidget {
  const _PublishDialog({required this.check});

  final NoticeCheck check;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final confirmOutside = ref(false);

    return (context) {
      final check = props.value.check;
      return AlertDialog(
        title: const Text('Skicka kallelse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!check.ok) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(check.message)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Alla medlemmar får e-post och en notis med tid, plats, '
              'dagordning och en länk till stämman. Röstläget låses och '
              'stämman läggs in i kalendern.',
            ),
            if (!check.ok)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmOutside.value,
                onChanged: (v) => confirmOutside.value = v ?? false,
                title: const Text(
                  'Jag har kontrollerat stadgarna och vill skicka ändå',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: check.ok || confirmOutside.value
                ? () => Navigator.of(context).pop(true)
                : null,
            child: const Text('Skicka'),
          ),
        ],
      );
    };
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      ],
    );
  }
}
