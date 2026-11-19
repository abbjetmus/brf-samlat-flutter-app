import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/help_tip.dart';
import '../general_meetings_models.dart';
import 'protocol_signatures_section.dart';

/// Protokollet. Medlemmar ser det när justerarna har signerat. Styrelsen
/// ([canManage]) skriver besluten per punkt och övriga anteckningar så länge
/// inget är signerat, och skickar protokollet för justering när stämman är
/// avslutad.
class ProtocolTab extends CompositionWidget {
  const ProtocolTab({
    super.key,
    required this.meeting,
    this.canManage = false,
    this.onLockedChanged,
  });

  final GeneralMeeting meeting;
  final bool canManage;
  final ValueChanged<bool>? onLockedChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final theme = useTheme();
    final contextRef = useContext();

    final loading = ref(true);
    // Auto-spara: 'idle' | 'pending' | 'saving' | 'saved' | 'error'.
    final saveStatus = ref('idle');
    final lastSavedAt = ref<DateTime?>(null);
    Timer? debounce;
    var changeCounter = 0;
    var savedCounter = 0;
    var errorCount = 0;
    Future<bool>? inFlight;
    final protocol = ref<GeneralMeetingProtocol?>(null);
    // Medlem: protokollet är inte justerat än (servern svarar 404).
    final notReady = ref(false);
    final error = ref<String?>(null);
    final signedLock = ref(false);
    // Ökas när protokollet hämtas om, så att fälten fylls i på nytt.
    final version = ref(0);
    final notes = ref('');
    final decisions = ref<Map<String, String>>({});

    final editable = computed(
      () =>
          props.value.canManage &&
          !(protocol.value?.locked ?? false) &&
          !signedLock.value,
    );

    void apply(GeneralMeetingProtocol p) {
      protocol.value = p;
      notes.value = p.notes;
      decisions.value = {for (final i in p.items) i.id: i.decision};
      version.value++;
      // Det som just lästs in räknas som sparat.
      debounce?.cancel();
      savedCounter = changeCounter;
      errorCount = 0;
    }

    Future<void> load() async {
      error.value = null;
      notReady.value = false;
      // Styrelsen skriver protokollet först när stämman är kallad.
      if (props.value.canManage &&
          props.value.meeting.status == GeneralMeetingStatus.draft) {
        protocol.value = null;
        loading.value = false;
        return;
      }
      try {
        apply(await store.getProtocol(props.value.meeting.id));
      } catch (e) {
        protocol.value = null;
        if (e is ClientException && e.statusCode == 404) {
          notReady.value = true;
        } else {
          error.value = generalMeetingErrorMessage(
            e,
            'Kunde inte hämta protokollet',
          );
        }
      } finally {
        loading.value = false;
      }
    }

    onMounted(load);

    watch(() => props.value.meeting.status, (_, _) => load());

    // --- Auto-spara -----------------------------------------------------------
    // Sparar 1,5 s efter senaste ändringen och när sidan stängs. Fälten byggs
    // inte om efter en sparning (version ökas inte), så markören står kvar.
    bool isDirty() => changeCounter != savedCounter;

    Future<bool> flush() async {
      debounce?.cancel();
      if (inFlight != null) await inFlight;
      if (!editable.value || protocol.value == null || !isDirty()) {
        return !isDirty();
      }
      final counter = changeCounter;
      saveStatus.value = 'saving';
      final future = () async {
        try {
          final saved = await store.saveProtocol(
            props.value.meeting.id,
            notes: notes.value,
            decisions: decisions.value,
          );
          protocol.value = saved;
          savedCounter = counter;
          errorCount = 0;
          lastSavedAt.value = DateTime.now();
          saveStatus.value = 'saved';
          return true;
        } catch (e) {
          errorCount++;
          saveStatus.value = 'error';
          // Nytt försök: 5 s, 10 s, 20 s … högst en minut.
          final wait = (5 * (1 << (errorCount - 1))).clamp(5, 60);
          debounce = Timer(Duration(seconds: wait), () => flush());
          return false;
        } finally {
          inFlight = null;
        }
      }();
      inFlight = future;
      final ok = await future;
      if (ok && isDirty()) {
        debounce = Timer(const Duration(milliseconds: 1500), () => flush());
      }
      return ok;
    }

    void changed() {
      changeCounter++;
      if (saveStatus.value != 'saving') saveStatus.value = 'pending';
      if (errorCount > 0) return; // ett nytt försök väntar redan
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 1500), () => flush());
    }

    // Lämnar man sidan med osparat sparas det ändå (utan att vänta på svaret).
    // Widgeten finns inte kvar efteråt, så bara skicka (rör inga refs).
    onUnmounted(() {
      debounce?.cancel();
      if (isDirty() && editable.value && protocol.value != null) {
        unawaited(
          store
              .saveProtocol(
                props.value.meeting.id,
                notes: notes.value,
                decisions: decisions.value,
              )
              .then(
                (_) {},
                onError: (Object e) {
                  debugPrint('Protokollet kunde inte sparas vid stängning: $e');
                },
              ),
        );
      }
    });

    Future<bool> saveBeforeSigning() async {
      if (!editable.value) return true;
      final ok = await flush();
      if (!ok) {
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Protokollet kunde inte sparas. Försök igen innan du skickar '
                'det för justering.',
              ),
            ),
          );
        }
      }
      return ok;
    }

    void onLocked(bool value) {
      final changed = value != signedLock.value;
      signedLock.value = value;
      props.value.onLockedChanged?.call(value);
      // Hämta om så att hash och låsning stämmer med det som signerats.
      if (changed && value) load();
    }

    return (context) {
      final p = protocol.value;
      final meeting = props.value.meeting;
      final canManage = props.value.canManage;
      final canEdit = editable.value;
      final heading = theme.value.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      );

      final Widget emptyState = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(
              error.value != null
                  ? Icons.error_outline
                  : Icons.description_outlined,
              size: 48,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 12),
            Text(
              error.value ??
                  (canManage
                      ? 'Protokollet skrivs när stämman har kallats.'
                      : meeting.status == GeneralMeetingStatus.closed
                      ? 'Protokollet justeras just nu. Det publiceras här '
                            'när justerarna har signerat.'
                      : 'Protokollet publiceras här efter stämman, när det '
                            'är justerat.'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (canManage)
              const HelpTip(
                id: 'general-meeting-protocol-board',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Skriv stämmans beslut under varje punkt. Allt sparas '
                    'automatiskt medan du skriver. Röstresultaten kommer från '
                    'Omröstning. När stämman '
                    'är avslutad skickar du protokollet för justering. Efter '
                    'den första signaturen är protokollet låst, och när alla '
                    'har signerat kan alla medlemmar läsa det.',
              ),
            if (loading.value)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (p == null || notReady.value || (!canManage && !p.complete))
              emptyState
            else ...[
              if (canManage) ...[
                if (meeting.status == GeneralMeetingStatus.closed)
                  ProtocolSignaturesSection(
                    meetingId: meeting.id,
                    onLockedChanged: onLocked,
                    beforeSend: saveBeforeSigning,
                  )
                else
                  Text(
                    'Protokollet kan skickas för justering när stämman är '
                    'avslutad.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                const SizedBox(height: 16),
              ],
              Text('Protokoll', style: theme.value.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                [
                  meeting.title,
                  formatMeetingDate(meeting.startAt),
                  if (p.location.isNotEmpty) p.location,
                ].join(' · '),
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              for (final (i, item) in p.items.indexed) ...[
                Text('§ ${i + 1}  ${item.title}', style: heading),
                if (item.results != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Röstresultat: ${resultLine(item.results!.total)}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 6),
                if (canEdit)
                  _TextArea(
                    key: ValueKey('${item.id}-${version.value}'),
                    initial: item.decision,
                    hint: 'Stämmans beslut',
                    onChanged: (v) {
                      decisions.value = {...decisions.value, item.id: v};
                      changed();
                    },
                  )
                else
                  Text(
                    item.decision.trim().isEmpty ? '—' : item.decision.trim(),
                  ),
                const SizedBox(height: 16),
              ],
              if (canEdit || p.notes.trim().isNotEmpty) ...[
                Text('Övriga anteckningar', style: heading),
                const SizedBox(height: 6),
                if (canEdit)
                  _TextArea(
                    key: ValueKey('notes-${version.value}'),
                    initial: p.notes,
                    hint: 'T.ex. närvaro, tider, övrigt',
                    onChanged: (v) {
                      notes.value = v;
                      changed();
                    },
                  )
                else
                  Text(p.notes.trim()),
                const SizedBox(height: 16),
              ],
              if (canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: _AutoSaveStatus(
                    status: saveStatus.value,
                    lastSavedAt: lastSavedAt.value,
                    onRetry: () => flush(),
                  ),
                ),
              if (!canManage && p.signatures.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text('Justerat av', style: heading),
                const SizedBox(height: 8),
                for (final s in p.signatures)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          s.isSigned ? Icons.verified : Icons.schedule,
                          size: 18,
                          color: s.isSigned
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              s.name,
                              if (s.role.isNotEmpty) s.role,
                              if (s.isSigned) formatMeetingDate(s.signedAt),
                            ].join(' · '),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (p.locked || p.complete) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'SHA-256: ${p.documentHash}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ],
        ),
      );
    };
  }
}

/// Flerradigt fält som äger sin egen controller (antalet punkter varierar).
class _TextArea extends CompositionWidget {
  const _TextArea({
    super.key,
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (controller, _, _) = useTextEditingController(
      text: props.value.initial,
    );

    return (context) => TextField(
      controller: controller,
      minLines: 2,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      onChanged: props.value.onChanged,
      decoration: InputDecoration(
        hintText: props.value.hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

/// Status för auto-spara under protokollet.
class _AutoSaveStatus extends StatelessWidget {
  const _AutoSaveStatus({
    required this.status,
    required this.lastSavedAt,
    required this.onRetry,
  });

  final String status;
  final DateTime? lastSavedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Colors.grey[600], fontSize: 13);
    String two(int n) => n.toString().padLeft(2, '0');
    switch (status) {
      case 'saving':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text('Sparar…', style: muted),
          ],
        );
      case 'pending':
        return Text('Osparade ändringar', style: muted);
      case 'error':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 16, color: Colors.red),
            const SizedBox(width: 6),
            const Text(
              'Kunde inte spara',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
            TextButton(onPressed: onRetry, child: const Text('Försök igen')),
          ],
        );
      case 'saved':
        final t = lastSavedAt;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_done_outlined,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              t == null ? 'Sparat' : 'Sparat ${two(t.hour)}:${two(t.minute)}',
              style: muted,
            ),
          ],
        );
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text('Sparas automatiskt', style: muted),
          ],
        );
    }
  }
}
