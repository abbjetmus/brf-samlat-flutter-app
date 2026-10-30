import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/status_chip.dart';
import '../residence_applications_store.dart';
import '../widgets/application_decision_sheet.dart';

/// One application with its status and the board's decision. The applicant can
/// withdraw it while it is undecided; users with `residence_applications`
/// update decide on it ("Fatta beslut") and with delete may remove it. Push links land here
/// (`/residence-applications/detail/:id`).
class ResidenceApplicationDetailPage extends CompositionWidget {
  static const String path = '/residence-applications/detail';

  final String applicationId;

  const ResidenceApplicationDetailPage({
    super.key,
    required this.applicationId,
  });

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final store = ResidenceApplicationsStore(
      inject(pocketBaseKey),
      authStore,
    );
    final contextRef = useContext();
    final loading = ref(true);

    onMounted(() async {
      await store.load(applicationId);
      loading.value = false;
    });

    Future<void> withdraw() async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Återkalla ansökan',
        message: 'Vill du återkalla ansökan? Styrelsen slutar då behandla den.',
        okLabel: 'Återkalla',
        okColor: Colors.red,
      );
      if (!ok) return;
      final done = await store.withdraw(applicationId);
      final c = contextRef.value;
      if (c == null || !c.mounted) return;
      ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(
          content: Text(
            done ? 'Ansökan återkallad' : 'Kunde inte återkalla ansökan',
          ),
        ),
      );
    }

    void snack(String message) {
      final c = contextRef.value;
      if (c == null || !c.mounted) return;
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> decide(ResidenceApplicationsRecord a) async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => ApplicationDecisionSheet(
          application: a,
          onSave: ({required status, required note, periodTo}) => store.decide(
            a.id,
            status: status,
            note: note,
            periodTo: periodTo,
          ),
        ),
      );
      if (saved == true) snack('Beslutet sparat och den sökande meddelad');
    }

    Future<void> remove() async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera ansökan',
        message:
            'Vill du radera ansökan? Den försvinner också från bostadens historik.',
        okLabel: 'Radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      final message = await store.delete(applicationId);
      snack(message ?? 'Ansökan raderad');
      final c = contextRef.value;
      if (message == null && c != null && c.mounted) Navigator.of(c).pop();
    }

    final sek = NumberFormat.currency(
      locale: 'sv_SE',
      symbol: 'kr',
      decimalDigits: 0,
    );

    return (context) {
      final a = store.current.value;
      if (loading.value) {
        return const GradientScaffold(
          title: 'Ansökan',
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (a == null) {
        return const GradientScaffold(
          title: 'Ansökan',
          body: Center(child: Text('Ansökan finns inte.')),
        );
      }

      final type = applicationTypeMeta(a.type);
      final canWithdraw =
          a.isOpen && a.applicant == authStore.currentUser.value?.id;
      final canDecide =
          a.status != 'återkallad' &&
          authStore.hasPermission(
            'residence_applications',
            CrudOperation.update,
          );
      final canDelete = authStore.hasPermission(
        'residence_applications',
        CrudOperation.delete,
      );

      final rows = <(String, String)>[
        if (a.residenceAddress.isNotEmpty) ('Bostad', a.residenceAddress),
        if (a.applicantName.isNotEmpty && a.applicant != authStore.currentUser.value?.id)
          ('Sökande', a.applicantName),
        ('Inskickad', AppDateUtils.formatDate(a.created)),
        if (a.type == 'andrahand') ...[
          (
            'Period',
            '${AppDateUtils.formatDate(a.periodFrom)} – ${AppDateUtils.formatDate(a.periodTo)}',
          ),
          if (a.tenantName.isNotEmpty) ('Andrahandshyresgäst', a.tenantName),
          if (a.tenantEmail.isNotEmpty) ('E-post', a.tenantEmail),
          if (a.tenantPhone.isNotEmpty) ('Telefon', a.tenantPhone),
          if (a.reason.isNotEmpty) ('Skäl', a.reason),
        ],
        if (a.type == 'överlåtelse') ...[
          if (a.buyerNames.isNotEmpty) ('Köpare', a.buyerNames),
          if (a.accessDate != null)
            ('Tillträdesdatum', AppDateUtils.formatDate(a.accessDate)),
          if (a.price > 0) ('Pris', sek.format(a.price)),
        ],
        if (a.type == 'medlemskap' && a.buyerNames.isNotEmpty)
          ('Sökande till medlemskap', a.buyerNames),
        if (a.description.isNotEmpty)
          (
            a.type == 'ombyggnad'
                ? 'Beskrivning av förändringen'
                : 'Övrig information',
            a.description,
          ),
      ];

      return GradientScaffold(
        title: type.title,
        subtitle: a.residenceAddress.isEmpty ? null : a.residenceAddress,
        actions: [
          if (canWithdraw || canDecide || canDelete)
            EntityActionMenu.header(
              actions: [
                if (canDecide)
                  EntityAction(
                    icon: Icons.gavel_outlined,
                    label: 'Fatta beslut',
                    onSelected: () => decide(a),
                  ),
                if (canWithdraw)
                  EntityAction(
                    icon: Icons.undo,
                    label: 'Återkalla',
                    onSelected: withdraw,
                    destructive: true,
                  ),
                if (canDelete) EntityAction.delete(remove),
              ],
            ),
        ],
        body: RefreshIndicator(
          onRefresh: () => store.load(applicationId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: applicationStatusLabels[a.status] ?? a.status,
                  tone: applicationStatusTone(a.status),
                  icon: type.icon,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (label, value) in rows) ...[
                        Text(label, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              if (a.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Bilagor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final file in a.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(file),
                    onTap: () => launchUrl(
                      Uri.parse(getImageUrl(a.collectionId, a.id, file)),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Styrelsens beslut',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (a.decidedAt != null)
                        Text(
                          '${applicationStatusLabels[a.status] ?? a.status} '
                          '${AppDateUtils.formatDate(a.decidedAt)}'
                          '${a.decidedByName.isNotEmpty ? ' av ${a.decidedByName}' : ''}',
                        ),
                      if (a.decisionNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(a.decisionNote),
                        ),
                      if (a.decidedAt == null && a.decisionNote.isEmpty)
                        Text(
                          a.status == 'återkallad'
                              ? (a.applicant == authStore.currentUser.value?.id
                                    ? 'Du återkallade ansökan.'
                                    : 'Ansökan återkallades av den sökande.')
                              : canDecide
                              ? 'Styrelsen har inte fattat beslut ännu. Välj Fatta beslut i menyn.'
                              : 'Styrelsen har inte fattat beslut ännu. Du får besked via push och e-post.',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}
