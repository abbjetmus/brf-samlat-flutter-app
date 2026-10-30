import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';

/// Röstlängden (bara styrelsen): närvaro och rösträtt per bostad eller medlem,
/// och att läsa in bostäderna igen. Mirrors the web `VotersTab.vue`.
class VotersTab extends CompositionWidget {
  const VotersTab({super.key, required this.meeting});

  final GeneralMeeting meeting;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final generating = ref(false);
    final busy = ref('');
    final search = ref('');
    final error = ref<String?>(null);
    final voters = ref<List<GeneralMeetingVoter>>([]);

    final closed = computed(
      () => props.value.meeting.status == GeneralMeetingStatus.closed,
    );
    final withVote = computed(() => voters.value.where((v) => v.hasVote).length);
    final present = computed(
      () => voters.value.where((v) => v.hasVote && v.present).length,
    );
    final filtered = computed(() {
      final q = search.value.trim().toLowerCase();
      if (q.isEmpty) return voters.value;
      return voters.value
          .where((v) => v.label.toLowerCase().contains(q))
          .toList();
    });

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> load() async {
      if (props.value.meeting.status == GeneralMeetingStatus.draft) {
        loading.value = false;
        return;
      }
      try {
        voters.value = await store.getVoters(props.value.meeting.id);
        error.value = null;
      } catch (e) {
        error.value = generalMeetingErrorMessage(
          e,
          'Kunde inte hämta röstlängden',
        );
      } finally {
        loading.value = false;
      }
    }

    onMounted(load);

    watch(() => props.value.meeting.status, (status, old) {
      if (old == GeneralMeetingStatus.draft && status != old) load();
    });

    Future<void> update(
      GeneralMeetingVoter voter,
      Map<String, dynamic> patch,
    ) async {
      busy.value = voter.id;
      try {
        final saved = await store.updateVoter(voter.id, patch);
        voters.value = [
          for (final v in voters.value) v.id == saved.id ? saved : v,
        ];
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte uppdatera röstlängden'));
      } finally {
        busy.value = '';
      }
    }

    Future<void> generate() async {
      generating.value = true;
      try {
        final (added, removed) = await store.regenerateVoters(
          props.value.meeting.id,
        );
        snack(
          'Röstlängden är uppdaterad: $added tillagda, $removed borttagna',
        );
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte uppdatera röstlängden'));
      } finally {
        generating.value = false;
      }
    }

    return (context) {
      final meeting = props.value.meeting;
      final perMember = meeting.voteMode == 'per_member';

      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            HelpTip(
              id: 'general-meeting-voters',
              padding: const EdgeInsets.only(bottom: 12),
              text:
                  'Röstlängden skapas från bostäderna och deras boende när '
                  'kallelsen skickas — '
                  '${perMember ? 'en rad per medlem' : 'en rad per bostad, oavsett hur många som bor där'}. '
                  'Markera vilka som är närvarande i lokalen; den som röstar '
                  'digitalt markeras automatiskt. Stäng av Rösträtt för den som '
                  'enligt stadgarna inte får rösta. Har bostäderna ändrats '
                  'trycker du på Uppdatera röstlängden.',
            ),
            if (meeting.status == GeneralMeetingStatus.draft)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  children: [
                    Icon(Icons.how_to_reg_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Röstlängden skapas med kallelsen. När du skickar '
                      'kallelsen läses föreningens bostäder och boende in här.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    label: '${voters.value.length} i röstlängden',
                    icon: Icons.format_list_bulleted,
                  ),
                  StatusChip(
                    label: '${withVote.value} med rösträtt',
                    icon: Icons.how_to_vote_outlined,
                    tone: StatusTone.info,
                  ),
                  StatusChip(
                    label: '${present.value} närvarande',
                    icon: Icons.how_to_reg_outlined,
                    tone: StatusTone.success,
                  ),
                ],
              ),
              if (!closed.value) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: generating.value ? null : generate,
                    icon: generating.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Uppdatera röstlängden'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SearchField(
                hintText: 'Sök bostad eller namn',
                onChanged: (v) => search.value = v,
              ),
              const SizedBox(height: 8),
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
              else if (filtered.value.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Inga rader.', textAlign: TextAlign.center),
                )
              else
                for (final v in filtered.value)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: v.hasVote ? null : Colors.grey,
                            ),
                          ),
                          if (v.note.isNotEmpty)
                            Text(
                              v.note,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          Row(
                            children: [
                              Checkbox(
                                value: v.present,
                                onChanged: closed.value || busy.value == v.id
                                    ? null
                                    : (x) => update(v, {'present': x ?? false}),
                              ),
                              const Text('Närvarande'),
                              const Spacer(),
                              const Text('Rösträtt'),
                              Switch(
                                value: v.hasVote,
                                onChanged: closed.value || busy.value == v.id
                                    ? null
                                    : (x) => update(v, {'has_vote': x}),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      );
    };
  }
}
