import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/pb_error.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/status_chip.dart';
import '../contractors_store.dart';

/// "Skickat till leverantör" on an issue: each forward with the contractor's
/// latest status and the link's validity, plus "Återkalla länken". Renders
/// nothing until the issue has been forwarded. Bump [reloadToken] to reload
/// (e.g. after a new forward). Mirrors the web's IssueForwardsCard.
class IssueForwardsCard extends CompositionWidget {
  final ContractorsStore store;
  final String issueId;
  final bool isResolved;

  /// May revoke links (contractors + update on the issue).
  final bool canManage;

  /// May mark the issue as resolved; shows the prompt when the contractor
  /// reported the job as done.
  final bool canResolve;
  final Future<void> Function() onResolve;
  final int reloadToken;

  const IssueForwardsCard({
    super.key,
    required this.store,
    required this.issueId,
    required this.isResolved,
    required this.canManage,
    required this.canResolve,
    required this.onResolve,
    this.reloadToken = 0,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final contextRef = useContext();
    final forwards = ref<List<IssueForwardsRecord>>([]);
    final error = ref<String?>(null);
    final resolving = ref(false);

    Future<void> load() async {
      try {
        forwards.value = await props.value.store.forwards(props.value.issueId);
        error.value = null;
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta utskicken.');
      }
    }

    watch(
      () => (props.value.issueId, props.value.reloadToken),
      (_, _) => load(),
      immediate: true,
    );

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> revoke(IssueForwardsRecord f) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Återkalla länken',
        message:
            '${f.contractorName.isEmpty ? 'Leverantören' : f.contractorName} '
            'kommer inte längre att kunna se ärendet eller lämna status via länken.',
        okLabel: 'Återkalla',
        okColor: Colors.red,
      );
      if (!ok) return;
      final message = await props.value.store.revoke(f.id);
      snack(message ?? 'Länken är återkallad');
      if (message == null) await load();
    }

    Future<void> resolve() async {
      resolving.value = true;
      await props.value.onResolve();
      resolving.value = false;
    }

    return (context) {
      final list = forwards.value;
      final p = props.value;
      final scheme = theme.value.colorScheme;
      if (list.isEmpty && error.value == null) return const SizedBox.shrink();

      final done = p.isResolved
          ? null
          : list.where((f) => f.lastStatus == 'atgardad').firstOrNull;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Skickat till leverantör',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (error.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error.value!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                if (done != null && p.canResolve)
                  Container(
                    margin: const EdgeInsets.only(top: 8, right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${done.contractorName} har markerat ärendet som '
                          'åtgärdat. Stämmer det kan du markera ärendet som löst.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: resolving.value ? null : resolve,
                          child: const Text('Markera som löst'),
                        ),
                      ],
                    ),
                  ),
                for (final f in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.engineering_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    title: Text(
                      f.contractorName.isEmpty ? 'Leverantör' : f.contractorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            'Skickat ${AppDateUtils.formatDate(f.sentAt)}',
                            if (f.includeAddress || f.includeAttachments)
                              'med ${[if (f.includeAddress) 'adress', if (f.includeAttachments) 'bilagor'].join(' och ')}',
                          ].join(' · '),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusChip(
                              label: f.lastStatus.isEmpty
                                  ? 'Inget svar än'
                                  : '${forwardStatusLabels[f.lastStatus] ?? f.lastStatus}'
                                        '${f.lastStatus == 'planerad' && f.plannedDate != null ? ' ${AppDateUtils.formatDate(f.plannedDate)}' : ''}',
                              tone: switch (f.lastStatus) {
                                'mottagen' => StatusTone.info,
                                'planerad' => StatusTone.warning,
                                'atgardad' => StatusTone.success,
                                _ => StatusTone.neutral,
                              },
                            ),
                            if (f.revoked)
                              const StatusChip(
                                label: 'Länken återkallad',
                                tone: StatusTone.danger,
                              )
                            else if (f.isExpired)
                              const StatusChip(label: 'Länken har gått ut')
                            else
                              StatusChip(
                                label:
                                    'Gäller till ${AppDateUtils.formatDate(f.expiresAt)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: p.canManage && !f.revoked && !f.isExpired
                        ? EntityActionMenu(
                            actions: [
                              EntityAction(
                                icon: Icons.link_off,
                                label: 'Återkalla länken',
                                destructive: true,
                                onSelected: () => revoke(f),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      );
    };
  }
}
