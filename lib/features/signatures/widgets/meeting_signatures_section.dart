import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../pages/signature_page.dart' show formatSignedAt;
import '../signatures_store.dart';

const _roleOptions = [
  'Ordförande',
  'Sekreterare',
  'Justerare',
  'Mötesordförande',
];

/// "E-signering" block on the board meeting page: status per signer, and for
/// those with `board_meetings` update, sending / changing / cancelling the
/// signing request. Mirrors the web `MeetingSignaturesCard`.
class MeetingSignaturesSection extends CompositionWidget {
  final String meetingId;

  const MeetingSignaturesSection({super.key, required this.meetingId});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final signaturesStore = inject(signaturesStoreKey);
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    final data = ref<MeetingSignatures?>(null);
    final busy = ref(false);

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> load() async {
      data.value = await signaturesStore.getForMeeting(props.value.meetingId);
    }

    onMounted(load);

    Future<void> openSendSheet() async {
      final users = await usersStore.getAllAssociationUsers();
      final roleTypes = authStore.associationRoleTypes.value;
      final current = data.value?.signatures ?? const <Signature>[];

      // Förifyll: befintliga signerare, annars ordförande + sekreterare.
      List<SignerInput> initial;
      if (current.isNotEmpty) {
        initial = [for (final s in current) SignerInput(s.user, s.role)];
      } else {
        String? holder(String roleName) {
          final roleId = roleTypes
              .where((r) => r.name == roleName)
              .firstOrNull
              ?.id;
          if (roleId == null) return null;
          return users
              .where((u) => u.associationRoleTypes.contains(roleId))
              .firstOrNull
              ?.id;
        }

        final chair = holder('chairman');
        final secretary = holder('secretary');
        initial = [
          if (chair != null) SignerInput(chair, 'Ordförande'),
          if (secretary != null && secretary != chair)
            SignerInput(secretary, 'Sekreterare'),
        ];
        if (initial.isEmpty) initial = [const SignerInput('', 'Ordförande')];
      }

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final signers = await showAppBottomSheet<List<SignerInput>>(
        context: ctx,
        builder: (_) => _SendForSigningSheet(users: users, initial: initial),
      );
      if (signers == null) return;

      busy.value = true;
      try {
        final created = await signaturesStore.createRequest(
          props.value.meetingId,
          signers,
        );
        data.value = MeetingSignatures(
          data.value?.currentDocumentHash ?? '',
          created,
        );
        snack('Protokollet har skickats för signering');
      } catch (e) {
        snack(signatureErrorMessage(e, 'Kunde inte skicka för signering'));
      } finally {
        busy.value = false;
      }
    }

    Future<void> cancel() async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Återkalla signering',
        message: 'Vill du återkalla signeringsförfrågan?',
        okLabel: 'Återkalla',
        okColor: Colors.red,
      );
      if (!ok) return;
      busy.value = true;
      try {
        await signaturesStore.cancelRequest(props.value.meetingId);
        data.value = MeetingSignatures(
          data.value?.currentDocumentHash ?? '',
          const [],
        );
        snack('Signeringen har återkallats');
      } catch (e) {
        snack(signatureErrorMessage(e, 'Kunde inte återkalla'));
      } finally {
        busy.value = false;
      }
    }

    return (context) {
      final canManage = authStore.hasPermission(
        'board_meetings',
        CrudOperation.update,
      );
      final current = data.value;
      final signatures = current?.signatures ?? const <Signature>[];
      final locked = current?.isLocked ?? false;
      final signedCount = signatures.where((s) => s.isSigned).length;
      final allSigned =
          signatures.isNotEmpty && signedCount == signatures.length;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.draw_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'E-signering',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (signatures.isNotEmpty)
                  _Chip(
                    label: allSigned
                        ? 'Färdigsignerat'
                        : '$signedCount/${signatures.length} signerade',
                    color: allSigned ? AppTheme.primaryColor : Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              signatures.isEmpty
                  ? 'Låt ordförande och justerare signera protokollet med en engångskod via e-post.'
                  : locked
                  ? 'Protokollet är låst eftersom det har signerats.'
                  : 'Protokollet kan ändras tills någon har signerat.',
              style: TextStyle(color: Colors.grey[600]),
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
                      : 'Väntar på signatur',
                ),
              ),
            if (canManage && !locked) ...[
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
                          ? 'Skicka för signering'
                          : 'Ändra signerare',
                    ),
                  ),
                  if (signatures.isNotEmpty)
                    TextButton(
                      onPressed: busy.value ? null : cancel,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Återkalla'),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SendForSigningSheet extends CompositionWidget {
  final List<UsersRecord> users;
  final List<SignerInput> initial;

  const _SendForSigningSheet({required this.users, required this.initial});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    // Ett stabilt id per rad så att fälten behåller rätt värde när en rad tas bort.
    var nextKey = 0;
    final rows = ref<List<(int, SignerInput)>>([
      for (final s in props.value.initial) (nextKey++, s),
    ]);

    final canSend = computed(() {
      final ids = rows.value.map((r) => r.$2.userId).toList();
      return ids.isNotEmpty &&
          ids.every((id) => id.isNotEmpty) &&
          ids.toSet().length == ids.length;
    });

    void update(int index, SignerInput value) {
      rows.value = [
        for (final (i, r) in rows.value.indexed) i == index ? (r.$1, value) : r,
      ];
    }

    return (context) {
      final users = props.value.users;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skicka för signering',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Varje person får ett mejl och en notis. De signerar med en engångskod '
              'som skickas till deras e-post. Protokollet låses när den första har signerat.',
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
                              child: Text(
                                u.name.isNotEmpty ? u.name : (u.email ?? u.id),
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
                            DropdownMenuItem(value: r, child: Text(r)),
                        ],
                        onChanged: (v) =>
                            update(i, SignerInput(row.userId, v ?? '')),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
        ),
      );
    };
  }
}
