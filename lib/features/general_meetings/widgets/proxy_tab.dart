import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'proxy_sheet.dart';

/// Fullmakter: de jag har lämnat (eller som gäller min bostad) och de där jag
/// är ombud. Egna fullmakter kan återkallas.
class ProxyTab extends CompositionWidget {
  const ProxyTab({super.key, required this.meeting});

  final GeneralMeeting meeting;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final proxies = ref<List<Proxy>>([]);
    final residences = ref<List<ResidencesRecord>>([]);

    final myId = store.currentUserId;
    final asHolder = computed(
      () => proxies.value.where((p) => p.proxyUser == myId).toList(),
    );
    final given = computed(
      () => proxies.value.where((p) => p.proxyUser != myId).toList(),
    );

    Future<void> load() async {
      final results = await Future.wait([
        store.getProxies(props.value.meeting.id),
        store.myResidences(),
      ]);
      proxies.value = results[0] as List<Proxy>;
      residences.value = results[1] as List<ResidencesRecord>;
      loading.value = false;
    }

    onMounted(load);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> register() async {
      final users = await store.possibleProxyHolders();
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => ProxySheet(
          residences: residences.value,
          users: users,
          perMember: props.value.meeting.voteMode == 'per_member',
          onSave: (input) async {
            try {
              await store.createProxy(
                meetingId: props.value.meeting.id,
                residenceId: input.residenceId,
                proxyUserId: input.proxyUserId,
                proxyName: input.proxyName,
                document: input.document,
              );
              return null;
            } catch (e) {
              return generalMeetingErrorMessage(
                e,
                'Kunde inte registrera fullmakten',
              );
            }
          },
        ),
      );
      if (saved == true) {
        snack('Fullmakten är registrerad och väntar på styrelsens godkännande');
        await load();
      }
    }

    Future<void> revoke(Proxy proxy) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Återkalla fullmakt',
        message:
            'Vill du återkalla fullmakten till ${proxy.proxyName}? Du kan sedan '
            'rösta själv eller registrera en ny.',
        okLabel: 'Återkalla',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteProxy(proxy.id);
        snack('Fullmakten är återkallad');
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte återkalla fullmakten'));
      }
    }

    Future<void> openDocument(Proxy proxy) async {
      try {
        final uri = await store.proxyDocumentUrl(proxy);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        snack('Kunde inte öppna dokumentet');
      }
    }

    return (context) {
      final m = props.value.meeting;
      final canRegister =
          m.canRegisterProxies && residences.value.isNotEmpty && !loading.value;

      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              m.canRegisterProxies
                  ? 'Kan du inte delta kan någon annan rösta för dig med en '
                        'fullmakt.'
                  : m.status == GeneralMeetingStatus.closed
                  ? 'Stämman är avslutad.'
                  : 'Fullmakter kan registreras när stämman är kallad.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (canRegister) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: register,
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Registrera fullmakt'),
              ),
            ] else if (m.canRegisterProxies &&
                !loading.value &&
                residences.value.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Du är inte kopplad till någon bostad och kan därför inte '
                'lämna fullmakt. Kontakta styrelsen.',
              ),
            ],
            const SizedBox(height: 16),
            if (loading.value)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (given.value.isNotEmpty) ...[
                const _SectionTitle('Fullmakter för din bostad'),
                for (final p in given.value)
                  _ProxyCard(
                    proxy: p,
                    title: 'Ombud: ${p.proxyName}',
                    onOpenDocument: () => openDocument(p),
                    actions: [
                      if (p.grantedBy == myId &&
                          m.status != GeneralMeetingStatus.closed)
                        EntityAction.delete(
                          () => revoke(p),
                          label: 'Återkalla',
                        ),
                    ],
                  ),
              ],
              if (asHolder.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionTitle('Du är ombud för'),
                for (final p in asHolder.value)
                  _ProxyCard(
                    proxy: p,
                    title: [
                      if (p.grantedByName.isNotEmpty) p.grantedByName,
                      if (p.residenceLabel.isNotEmpty) p.residenceLabel,
                    ].join(' · '),
                    onOpenDocument: () => openDocument(p),
                    actions: const [],
                  ),
              ],
              if (given.value.isEmpty && asHolder.value.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Inga fullmakter registrerade.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      );
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );
}

class _ProxyCard extends StatelessWidget {
  const _ProxyCard({
    required this.proxy,
    required this.title,
    required this.onOpenDocument,
    required this.actions,
  });

  final Proxy proxy;
  final String title;
  final VoidCallback onOpenDocument;
  final List<EntityAction> actions;

  @override
  Widget build(BuildContext context) {
    final tone = switch (proxy.status) {
      'godkänd' => StatusTone.success,
      'avslagen' => StatusTone.danger,
      _ => StatusTone.warning,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (proxy.residenceLabel.isNotEmpty &&
                      !title.contains(proxy.residenceLabel))
                    Text(
                      proxy.residenceLabel,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  StatusChip(label: proxy.statusLabel, tone: tone),
                  if (proxy.reviewNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(proxy.reviewNote),
                  ],
                  if (proxy.document.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: onOpenDocument,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Visa fullmakt'),
                    ),
                ],
              ),
            ),
            EntityActionMenu(actions: actions),
          ],
        ),
      ),
    );
  }
}
