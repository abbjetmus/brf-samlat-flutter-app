import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../signatures/pages/signature_page.dart' show formatSignedAt;
import '../../signatures/signatures_store.dart';
import '../general_meetings_models.dart';

const _roleOptions = [
  'Stämmoordförande',
  'Sekreterare',
  'Justerare',
  'Rösträknare',
];

/// Justering av stämmans protokoll (styrelsen, när stämman är avslutad):
/// status per justerare och att skicka, ändra eller återkalla förfrågan.
/// Samma motor som styrelsemötena (kind "general"). Mirrors the web
/// `MeetingSignaturesCard` with kind 'general'.
class ProtocolSignaturesSection extends CompositionWidget {
  const ProtocolSignaturesSection({
    super.key,
    required this.meetingId,
    required this.onLockedChanged,
  });

  final String meetingId;

  /// Anropas när protokollet blir låst (minst en signatur) eller upplåst.
  final ValueChanged<bool> onLockedChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(generalMeetingsStoreKey);
    final contextRef = useContext();

    final data = ref<MeetingSignatures?>(null);
    final error = ref<String?>(null);
    final busy = ref(false);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    void setData(MeetingSignatures value) {
      final wasLocked = data.value?.isLocked ?? false;
      data.value = value;
      if (value.isLocked != wasLocked) {
        props.value.onLockedChanged(value.isLocked);
      }
    }

    Future<void> load() async {
      try {
        setData(await store.getSignatures(props.value.meetingId));
        error.value = null;
      } catch (e) {
        error.value = generalMeetingErrorMessage(
          e,
          'Kunde inte hämta justeringen',
        );
      }
    }

    onMounted(load);

    Future<void> openSendSheet() async {
      List<UsersRecord> users;
      try {
        users = await store.associationUsers();
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte hämta användarna'));
        return;
      }
      final current = data.value?.signatures ?? const <Signature>[];
      // Stämmans justerare väljs på stämman — ingen förifyllning.
      final initial = current.isNotEmpty
          ? [for (final s in current) SignerInput(s.user, s.role)]
          : [const SignerInput('', 'Stämmoordförande')];

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final signers = await showAppBottomSheet<List<SignerInput>>(
        context: ctx,
        builder: (_) => _SendSheet(
          users: users,
          initial: initial,
          replacing: current.isNotEmpty,
        ),
      );
      if (signers == null) return;

      busy.value = true;
      try {
        final created = await store.requestSignatures(
          props.value.meetingId,
          signers,
        );
        setData(
          MeetingSignatures(data.value?.currentDocumentHash ?? '', created),
        );
        snack('Protokollet har skickats för justering');
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte skicka för justering'));
      } finally {
        busy.value = false;
      }
    }

    Future<void> cancel() async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Återkalla justering',
        message: 'Vill du återkalla förfrågan om justering?',
        okLabel: 'Återkalla',
        okColor: Colors.red,
      );
      if (!ok) return;
      busy.value = true;
      try {
        await store.cancelSignatures(props.value.meetingId);
        setData(MeetingSignatures(data.value?.currentDocumentHash ?? '', []));
        snack('Justeringen har återkallats');
      } catch (e) {
        snack(generalMeetingErrorMessage(e, 'Kunde inte återkalla'));
      } finally {
        busy.value = false;
      }
    }

    return (context) {
      final current = data.value;
      final signatures = current?.signatures ?? const <Signature>[];
      final locked = current?.isLocked ?? false;
      final signedCount = signatures.where((s) => s.isSigned).length;
      final allSigned =
          signatures.isNotEmpty && signedCount == signatures.length;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.draw_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Justering',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (signatures.isNotEmpty)
                    Text(
                      allSigned
                          ? 'Färdigjusterat'
                          : '$signedCount/${signatures.length} signerade',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: allSigned ? AppTheme.primaryColor : Colors.orange,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                error.value ??
                    (signatures.isEmpty
                        ? 'Låt stämmoordföranden och justeringspersonerna '
                              'justera protokollet med en engångskod via e-post.'
                        : locked
                        ? 'Protokollet är låst eftersom det har signerats.'
                        : 'Protokollet kan fortfarande ändras tills någon har '
                              'signerat.'),
                style: TextStyle(
                  color: error.value != null ? Colors.red : Colors.grey[600],
                ),
              ),
              for (final s in signatures)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    s.isSigned ? Icons.verified : Icons.schedule,
                    color: s.isSigned ? AppTheme.primaryColor : Colors.grey,
                  ),
                  title: Text(
                    s.role.isEmpty
                        ? s.displayName
                        : '${s.displayName} · ${s.role}',
                  ),
                  subtitle: Text(
                    s.isSigned
                        ? 'Signerad ${formatSignedAt(s.signedAt)}'
                              '${s.documentHash.isNotEmpty && current != null && s.documentHash != current.currentDocumentHash ? ' · innehållet skiljer sig från det signerade' : ''}'
                        : 'Väntar på signatur',
                  ),
                ),
              if (!locked && error.value == null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: busy.value ? null : openSendSheet,
                      icon: Icon(
                        signatures.isEmpty
                            ? Icons.send_outlined
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        signatures.isEmpty
                            ? 'Skicka för justering'
                            : 'Ändra justerare',
                      ),
                    ),
                    if (signatures.isNotEmpty)
                      TextButton(
                        onPressed: busy.value ? null : cancel,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Återkalla'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    };
  }
}

class _SendSheet extends CompositionWidget {
  const _SendSheet({
    required this.users,
    required this.initial,
    required this.replacing,
  });

  final List<UsersRecord> users;
  final List<SignerInput> initial;
  final bool replacing;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    // Ett stabilt id per rad så att fälten behåller rätt värde när en rad tas bort.
    var nextKey = 0;
    final rows = ref<List<(int, SignerInput)>>([
      for (final s in props.value.initial) (nextKey++, s),
    ]);

    // Engångskoden mejlas, så den som saknar e-post kan inte justera.
    bool hasEmail(String userId) => props.value.users.any(
      (u) => u.id == userId && (u.email ?? '').isNotEmpty,
    );

    final canSend = computed(() {
      final ids = rows.value.map((r) => r.$2.userId).toList();
      return ids.isNotEmpty &&
          ids.every(hasEmail) &&
          ids.toSet().length == ids.length;
    });

    void update(int index, SignerInput value) {
      rows.value = [
        for (final (i, r) in rows.value.indexed) i == index ? (r.$1, value) : r,
      ];
    }

    return (context) {
      final users = props.value.users;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skicka för justering',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Varje person får ett mejl och en notis med en länk. De läser '
            'protokollet och signerar med en engångskod som skickas till deras '
            'e-post, så personer utan e-postadress går inte att välja. '
            'Protokollet låses när den första har signerat.'
            '${props.value.replacing ? ' Den tidigare förfrågan ersätts.' : ''}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          for (final (i, (rowKey, row)) in rows.value.indexed)
            Padding(
              key: ValueKey(rowKey),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: row.userId.isEmpty ? null : row.userId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Person',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final u in users)
                          DropdownMenuItem(
                            value: u.id,
                            enabled: (u.email ?? '').isNotEmpty,
                            child: Text(
                              (u.email ?? '').isEmpty
                                  ? '${u.name} (saknar e-post)'
                                  : (u.name.isNotEmpty ? u.name : u.email!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          update(i, SignerInput(v ?? '', row.role)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _roleOptions.contains(row.role)
                          ? row.role
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Roll',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final r in _roleOptions)
                          DropdownMenuItem(
                            value: r,
                            child: Text(r, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) =>
                          update(i, SignerInput(row.userId, v ?? '')),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Ta bort',
                    onPressed: rows.value.length == 1
                        ? null
                        : () => rows.value = [
                            for (final (j, r) in rows.value.indexed)
                              if (j != i) r,
                          ],
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => rows.value = [
              ...rows.value,
              (nextKey++, const SignerInput('', 'Justerare')),
            ],
            icon: const Icon(Icons.add),
            label: const Text('Lägg till person'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSend.value
                  ? () => Navigator.of(
                      context,
                    ).pop([for (final r in rows.value) r.$2])
                  : null,
              child: const Text('Skicka'),
            ),
          ),
        ],
      );
    };
  }
}
