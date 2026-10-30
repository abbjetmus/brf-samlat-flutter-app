import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'general_meeting_status_chip.dart';

/// Rösta på stämmans beslutspunkter. En röst per röstenhet (bostad, eller
/// medlem om föreningen röstar per medlem) och punkt — servern kontrollerar.
/// Rösten kan ändras tills styrelsen stänger punkten; resultatet visas när den
/// är stängd. Styrelsen ([canManage]) öppnar och stänger omröstningarna, ser
/// siffrorna löpande och för in röster som räknats i lokalen. Uppdateras
/// automatiskt medan stämman pågår.
class VotingTab extends CompositionWidget {
  const VotingTab({
    super.key,
    required this.meeting,
    this.canManage = false,
    this.locked = false,
  });

  final GeneralMeeting meeting;
  final bool canManage;
  final bool locked;

  static const _refreshInterval = Duration(seconds: 5);

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final overview = ref<VotingOverview?>(null);
    final error = ref<String?>(null);
    // "<itemId>|<unitKey>" medan en röst skickas.
    final pending = ref<Set<String>>({});
    // Punkt-id medan styrelsen öppnar/stänger eller sparar röster i lokalen.
    final busy = ref('');
    Timer? timer;

    final ongoing = computed(
      () =>
          (overview.value?.status ?? props.value.meeting.status) ==
          GeneralMeetingStatus.ongoing,
    );

    final banner = computed(() {
      final o = overview.value;
      final status = o?.status ?? props.value.meeting.status;
      final manage = props.value.canManage;
      if (status == GeneralMeetingStatus.closed) {
        return 'Stämman är avslutad. Här ser du resultaten.';
      }
      if (status != GeneralMeetingStatus.ongoing) {
        return 'Omröstningarna sker när stämman pågår.';
      }
      if (o != null && !o.votingOpen) {
        return manage
            ? 'Digital röstning är avstängd. Slå på den under Översikt, eller '
                  'för in rösterna från lokalen.'
            : 'Digital röstning är inte öppen. Röstningen sker i lokalen.';
      }
      if (!manage && o != null && o.units.isEmpty) {
        return 'Du har ingen rösträtt på stämman. Kontakta styrelsen om det är '
            'fel.';
      }
      return 'Välj ditt svar när en omröstning öppnas. Du kan ändra dig tills '
          'den stängs.';
    });

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> load() async {
      try {
        overview.value = await store.getVoting(props.value.meeting.id);
        error.value = null;
      } catch (e) {
        error.value = generalMeetingErrorMessage(
          e,
          'Kunde inte hämta omröstningen',
        );
      } finally {
        loading.value = false;
      }
    }

    onMounted(() async {
      await load();
      timer = Timer.periodic(_refreshInterval, (_) {
        final anyOpen =
            overview.value?.items.any((i) => i.voteStatus == VoteStatus.open) ??
            false;
        if ((ongoing.value || anyOpen) &&
            pending.value.isEmpty &&
            busy.value.isEmpty) {
          load();
        }
      });
    });

    onUnmounted(() => timer?.cancel());

    watch(
      () => (props.value.meeting.status, props.value.meeting.votingOpen),
      (_, _) => load(),
    );

    Future<void> vote(VotingItem item, VotingUnit unit, String choice) async {
      final key = '${item.id}|${unit.unitKey}';
      pending.value = {...pending.value, key};
      try {
        await store.vote(item.id, choice, unit.unitKey);
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Rösten kunde inte sparas'));
        await load();
      } finally {
        pending.value = {...pending.value}..remove(key);
      }
    }

    Future<void> setVoteStatus(VotingItem item, String status) async {
      busy.value = item.id;
      try {
        await store.updateItem(item.id, {'vote_status': status});
        snack(
          status == VoteStatus.open
              ? 'Omröstningen är öppen'
              : 'Omröstningen är stängd',
        );
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte ändra omröstningen'));
      } finally {
        busy.value = '';
      }
    }

    Future<void> editManual(VotingItem item) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => _ManualCountsSheet(
          item: item,
          onSave: (ja, nej, avstar) async {
            try {
              await store.updateItem(item.id, {
                'manual_yes': ja,
                'manual_no': nej,
                'manual_abstain': avstar,
              });
              return null;
            } catch (e) {
              return generalMeetingErrorMessage(
                e,
                'Kunde inte spara rösterna',
              );
            }
          },
        ),
      );
      if (saved == true) {
        snack('Rösterna från lokalen är sparade');
        await load();
      }
    }

    return (context) {
      final o = overview.value;
      final manage = props.value.canManage;
      final perMember = (o?.voteMode ?? props.value.meeting.voteMode) ==
          'per_member';
      final openUnits = (o?.units ?? const <VotingUnit>[])
          .where((u) => !u.blocked)
          .toList();

      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (manage)
              const HelpTip(
                id: 'general-meeting-voting-board',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Starta stämman och slå på digital röstning under Översikt. '
                    'Öppna sedan omröstningen på en beslutspunkt — alla '
                    'medlemmar får en notis och kan rösta tills du stänger den. '
                    'Du ser siffrorna löpande; medlemmarna ser resultatet när '
                    'punkten är stängd. Röster som räknats i lokalen för du in '
                    'under Röster i lokalen.',
              )
            else
              HelpTip(
                id: 'general-meeting-voting',
                padding: const EdgeInsets.only(bottom: 12),
                text:
                    'När styrelsen öppnar en omröstning röstar du ja, nej eller '
                    'avstår. Du kan ändra din röst tills omröstningen stängs. '
                    '${perMember ? 'Varje medlem har en röst.' : 'Varje bostad har en röst — den som röstar sist för bostaden gäller.'}',
              ),
            if (loading.value)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error.value != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error.value!, textAlign: TextAlign.center),
              )
            else if (o != null) ...[
              Text(banner.value, style: TextStyle(color: Colors.grey[600])),
              if (manage) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: '${o.registerWithVote} med rösträtt',
                      icon: Icons.how_to_vote_outlined,
                    ),
                    StatusChip(
                      label: '${o.registerPresent} närvarande',
                      icon: Icons.how_to_reg_outlined,
                      tone: StatusTone.success,
                    ),
                  ],
                ),
              ],
              if (o.units.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Du röstar för',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        for (final u in o.units)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  u.blocked
                                      ? Icons.block
                                      : u.proxy.isNotEmpty
                                      ? Icons.assignment_ind_outlined
                                      : Icons.home_outlined,
                                  size: 18,
                                  color: u.blocked ? Colors.grey : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    u.blocked
                                        ? '${u.label} · ${u.blockedReason}'
                                        : u.label,
                                    style: TextStyle(
                                      color: u.blocked ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (o.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Dagordningen har inga beslutspunkter.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final item in o.items)
                _VotingItemCard(
                  item: item,
                  units: openUnits,
                  canVote: o.votingOpen && ongoing.value,
                  pending: pending.value,
                  onVote: vote,
                  manage: manage && !props.value.locked,
                  ongoing: ongoing.value,
                  busy: busy.value == item.id,
                  onOpen: () => setVoteStatus(item, VoteStatus.open),
                  onClose: () => setVoteStatus(item, VoteStatus.closed),
                  onManual: () => editManual(item),
                ),
            ],
          ],
        ),
      );
    };
  }
}

class _VotingItemCard extends StatelessWidget {
  const _VotingItemCard({
    required this.item,
    required this.units,
    required this.canVote,
    required this.pending,
    required this.onVote,
    required this.manage,
    required this.ongoing,
    required this.busy,
    required this.onOpen,
    required this.onClose,
    required this.onManual,
  });

  final VotingItem item;

  /// Röstenheter som inte är spärrade.
  final List<VotingUnit> units;
  final bool canVote;
  final Set<String> pending;
  final void Function(VotingItem, VotingUnit, String) onVote;

  /// Styrelsen och protokollet är inte justerat.
  final bool manage;
  final bool ongoing;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onManual;

  String _choiceLabel(String choice) =>
      voteChoices.where((c) => c.$1 == choice).firstOrNull?.$2 ?? choice;

  @override
  Widget build(BuildContext context) {
    final open = item.voteStatus == VoteStatus.open;
    final closed = item.voteStatus == VoteStatus.closed;
    final results = item.results;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                VoteStatusChip(voteStatus: item.voteStatus),
                const Spacer(),
                if (manage && item.voteStatus == VoteStatus.none)
                  FilledButton.tonalIcon(
                    onPressed: busy || !ongoing ? null : onOpen,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Öppna'),
                  )
                else if (manage && open)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: busy ? null : onClose,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stäng'),
                  ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description.trim(),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            if (open && canVote && units.isNotEmpty)
              for (final unit in units) ...[
                Text(
                  unit.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: [
                      for (final (value, label) in voteChoices)
                        ButtonSegment(value: value, label: Text(label)),
                    ],
                    selected: {
                      if ((item.myVotes[unit.unitKey] ?? '').isNotEmpty)
                        item.myVotes[unit.unitKey]!,
                    },
                    onSelectionChanged:
                        pending.contains('${item.id}|${unit.unitKey}')
                        ? null
                        : (s) {
                            if (s.isNotEmpty) onVote(item, unit, s.first);
                          },
                  ),
                ),
                const SizedBox(height: 12),
              ]
            else if (open && !manage)
              Text(
                'Omröstningen är öppen i lokalen.',
                style: TextStyle(color: Colors.grey[600]),
              )
            else if (!open && !closed && !manage)
              Text(
                'Omröstningen har inte öppnats.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            if (results != null && (closed || manage)) ...[
              Text(
                '${closed ? 'Resultat' : 'Löpande (syns bara för styrelsen)'} · '
                '${results.votesCast} röster',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 6),
              _ResultBar('Ja', results.total.ja, results.votesCast, Colors.green),
              _ResultBar('Nej', results.total.nej, results.votesCast, Colors.red),
              _ResultBar(
                'Avstår',
                results.total.avstar,
                results.votesCast,
                Colors.grey,
              ),
              if (results.manual.total > 0)
                Text(
                  'Varav i lokalen: ja ${results.manual.ja}, nej '
                  '${results.manual.nej}, avstår ${results.manual.avstar}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
            if (manage && item.voteStatus != VoteStatus.none)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : onManual,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Röster i lokalen'),
                ),
              ),
            if (!(open && canVote) && item.myVotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final unit in units)
                if ((item.myVotes[unit.unitKey] ?? '').isNotEmpty)
                  Text(
                    '${unit.label}: ${_choiceLabel(item.myVotes[unit.unitKey]!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar(this.label, this.count, this.total, this.color);

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 12,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Röster som räknats i lokalen. De läggs till de digitala.
class _ManualCountsSheet extends CompositionWidget {
  const _ManualCountsSheet({required this.item, required this.onSave});

  final VotingItem item;
  final Future<String?> Function(int ja, int nej, int avstar) onSave;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final manual = props.value.item.results?.manual;

    final (jaController, ja, _) = useTextEditingController(
      text: '${manual?.ja ?? 0}',
    );
    final (nejController, nej, _) = useTextEditingController(
      text: '${manual?.nej ?? 0}',
    );
    final (avstarController, avstar, _) = useTextEditingController(
      text: '${manual?.avstar ?? 0}',
    );
    final saving = ref(false);
    final error = ref<String?>(null);

    int parse(String v) {
      final n = int.tryParse(v.trim()) ?? 0;
      return n < 0 ? 0 : n;
    }

    Future<void> save() async {
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        parse(ja.value),
        parse(nej.value),
        parse(avstar.value),
      );
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
    }

    Widget field(TextEditingController controller, String label) => Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Röster i lokalen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          props.value.item.title,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            field(jaController, 'Ja'),
            const SizedBox(width: 8),
            field(nejController, 'Nej'),
            const SizedBox(width: 8),
            field(avstarController, 'Avstår'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Rösterna läggs till de digitala.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        if (error.value != null) ...[
          const SizedBox(height: 8),
          Text(error.value!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving.value ? null : save,
          child: saving.value
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Spara'),
        ),
      ],
    );
  }
}
