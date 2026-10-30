import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';
import 'proxy_sheet.dart';

/// Fullmakter: de jag har lämnat (eller som gäller min bostad) och de där jag
/// är ombud. Egna fullmakter kan återkallas. Styrelsen ([canManage]) ser alla
/// fullmakter och godkänner eller avslår dem.
class ProxyTab extends CompositionWidget {
  const ProxyTab({super.key, required this.meeting, this.canManage = false});

  final GeneralMeeting meeting;
  final bool canManage;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final loading = ref(true);
    final busy = ref('');
    final proxies = ref<List<Proxy>>([]);
    final residences = ref<List<ResidencesRecord>>([]);

    final myId = store.currentUserId;
    bool isMineOrMyResidence(Proxy p) =>
        p.grantedBy == myId || residences.value.any((r) => r.id == p.residence);
    final asHolder = computed(
      () => proxies.value
          .where((p) => p.proxyUser == myId && p.grantedBy != myId)
          .toList(),
    );
    final given = computed(
      () => proxies.value
          .where((p) => p.proxyUser != myId && isMineOrMyResidence(p))
          .toList(),
    );
    // Styrelsen: övriga fullmakter i föreningen.
    final others = computed(
      () => proxies.value
          .where((p) => p.proxyUser != myId && !isMineOrMyResidence(p))
          .toList(),
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

    Future<void> review(Proxy proxy, String status, {String note = ''}) async {
      busy.value = proxy.id;
      try {
        await store.reviewProxy(proxy.id, status, note: note);
        if (status == 'godkänd') snack('Fullmakten är godkänd');
        if (status == 'avslagen') snack('Fullmakten är avslagen');
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte uppdatera fullmakten'));
      } finally {
        busy.value = '';
      }
    }

    Future<void> reject(Proxy proxy) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final note = await showAppBottomSheet<String>(
        context: ctx,
        builder: (_) => const _RejectSheet(),
      );
      if (note == null) return;
      await review(proxy, 'avslagen', note: note);
    }

    Future<void> remove(Proxy proxy) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Ta bort fullmakt',
        message:
            'Fullmakten tas bort och ombudet kan inte längre rösta för '
            'bostaden.',
        okLabel: 'Ta bort',
        okColor: Colors.red,
      );
      if (!ok) return;
      try {
        await store.deleteProxy(proxy.id);
        snack('Fullmakten är borttagen');
        await load();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte ta bort fullmakten'));
      }
    }

    List<EntityAction> boardActions(Proxy p) {
      final closed = props.value.meeting.status == GeneralMeetingStatus.closed;
      if (!props.value.canManage || closed) {
        return [
          if (store.canDelete && p.grantedBy != myId)
            EntityAction.delete(() => remove(p), label: 'Ta bort'),
        ];
      }
      return [
        if (p.status == 'väntar') ...[
          EntityAction(
            icon: Icons.check_circle_outline,
            label: 'Godkänn',
            onSelected: () => review(p, 'godkänd'),
          ),
          EntityAction(
            icon: Icons.block,
            label: 'Avslå',
            onSelected: () => reject(p),
            destructive: true,
          ),
        ] else
          EntityAction(
            icon: Icons.undo,
            label: 'Ångra beslut',
            onSelected: () => review(p, 'väntar'),
          ),
        if (store.canDelete && p.grantedBy != myId)
          EntityAction.delete(() => remove(p), label: 'Ta bort'),
      ];
    }

    Future<void> openDocument(Proxy proxy) async {
      try {
        final uri = await store.proxyDocumentUrl(proxy);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte öppna fullmakten'));
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
            if (props.value.canManage)
              const HelpTip(
                id: 'general-meeting-proxies-board',
                padding: EdgeInsets.only(bottom: 12),
                text:
                    'Medlemmar registrerar vem som ska rösta för dem och kan '
                    'ladda upp den undertecknade fullmakten. Kontrollera '
                    'fullmakten och godkänn den — först då kan ombudet rösta '
                    'för bostaden. Hur många fullmakter ett ombud får ha '
                    'ställer du in under Inställningar på stämmolistan.',
              )
            else
              HelpTip(
                id: 'general-meeting-proxies',
                padding: const EdgeInsets.only(bottom: 12),
                text:
                    'Kan du inte delta kan du ge någon annan fullmakt att rösta '
                    'för ${m.voteMode == 'per_member' ? 'dig' : 'din bostad'}. '
                    'Välj en person i föreningen (då kan hen rösta i appen) '
                    'eller skriv namnet på någon annan, och ladda gärna upp den '
                    'undertecknade fullmakten. Fullmakten gäller när styrelsen '
                    'har godkänt den.',
              ),
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
                    busy: busy.value == p.id,
                    actions: [
                      ...boardActions(p),
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
                    busy: busy.value == p.id,
                    actions: boardActions(p),
                  ),
              ],
              if (others.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionTitle('Alla fullmakter'),
                for (final p in others.value)
                  _ProxyCard(
                    proxy: p,
                    title: [
                      p.grantedByName.isEmpty ? 'Medlem' : p.grantedByName,
                      p.proxyName,
                    ].join(' → '),
                    subtitle: p.proxyUser.isEmpty
                        ? 'Ombudet röstar i lokalen'
                        : '',
                    onOpenDocument: () => openDocument(p),
                    busy: busy.value == p.id,
                    actions: boardActions(p),
                  ),
              ],
              if (proxies.value.isEmpty)
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
    this.subtitle = '',
    this.busy = false,
  });

  final Proxy proxy;
  final String title;
  final String subtitle;
  final VoidCallback onOpenDocument;
  final List<EntityAction> actions;
  final bool busy;

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
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
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
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              EntityActionMenu(actions: actions),
          ],
        ),
      ),
    );
  }
}

/// Anledning till att fullmakten avslås. Stänger med anteckningen.
class _RejectSheet extends CompositionWidget {
  const _RejectSheet();

  @override
  Widget Function(BuildContext) setup() {
    final (controller, note, _) = useTextEditingController();

    return (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Avslå fullmakt',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Anledning (visas för medlemmen)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(note.value.trim()),
          child: const Text('Avslå'),
        ),
      ],
    );
  }
}
