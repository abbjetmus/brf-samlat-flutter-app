import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_description.dart';
import '../signatures_store.dart';

/// Read a protocol and sign it with a one-time code sent to the signer's email.
/// Opened from "Att signera", a push notification or a universal link
/// (`/app/signatures/<id>`).
class SignaturePage extends CompositionWidget {
  static const String path = '/signatures';

  final String signatureId;

  const SignaturePage({super.key, required this.signatureId});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final signaturesStore = inject(signaturesStoreKey);
    final contextRef = useContext();
    final mediaQuery = useMediaQuery();

    final loading = ref(true);
    final data = ref<SignatureView?>(null);
    final confirmed = ref(false);
    final codeSentTo = ref('');
    final requesting = ref(false);
    final signing = ref(false);
    final (codeController, code, _) = useTextEditingController();

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> load() async {
      try {
        data.value = await signaturesStore.view(props.value.signatureId);
      } catch (e) {
        data.value = null;
      }
    }

    onMounted(() async {
      await load();
      loading.value = false;
    });

    Future<void> requestCode() async {
      final view = data.value;
      if (view == null || requesting.value) return;
      requesting.value = true;
      try {
        codeSentTo.value = await signaturesStore.requestCode(view.signature.id);
        code.value = '';
        snack('Koden har skickats');
      } catch (e) {
        snack(signatureErrorMessage(e, 'Kunde inte skicka koden'));
      } finally {
        requesting.value = false;
      }
    }

    Future<void> sign() async {
      final view = data.value;
      if (view == null || signing.value || code.value.length != 6) return;
      signing.value = true;
      try {
        await signaturesStore.sign(view.signature.id, code.value);
        snack('Protokollet är signerat');
        await load();
      } catch (e) {
        code.value = '';
        snack(signatureErrorMessage(e, 'Kunde inte signera'));
      } finally {
        signing.value = false;
      }
    }

    return (context) {
      if (loading.value) {
        return const GradientScaffold(
          title: 'Signera',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final view = data.value;
      if (view == null) {
        return const GradientScaffold(
          title: 'Signera',
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Signeringen kunde inte hittas. Den kan ha återkallats.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      final meeting = view.meeting;
      final signature = view.signature;

      return GradientScaffold(
        title: signature.documentTitle,
        subtitle: view.associationName.isEmpty ? null : view.associationName,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32 + mediaQuery.value.padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (view.isSigner)
                _SignBox(
                  signature: signature,
                  confirmed: confirmed.value,
                  onConfirmed: (v) => confirmed.value = v,
                  codeSentTo: codeSentTo.value,
                  codeController: codeController,
                  codeLength: code.value.length,
                  requesting: requesting.value,
                  signing: signing.value,
                  onRequestCode: requestCode,
                  onSign: sign,
                ),
              const SizedBox(height: 16),
              _SignersCard(signatures: view.signatures),
              const SizedBox(height: 16),
              Text(
                '${meeting.streetAddress}, ${meeting.zipCode} ${meeting.locality}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (meeting.meetingAgenda?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _ProtocolSection(
                  title: 'Dagordning',
                  items: meeting.meetingAgenda!,
                ),
              ],
              const SizedBox(height: 16),
              _ProtocolSection(
                title: 'Mötesprotokoll',
                items: meeting.meetingProtocol ?? const [],
              ),
              const SizedBox(height: 24),
              SelectableText(
                'Protokoll-ID: ${meeting.meetingProtocolId.isEmpty ? '–' : meeting.meetingProtocolId}\n'
                'SHA-256: ${view.currentDocumentHash}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    };
  }
}

String formatSignedAt(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  return AppDateUtils.formatDateTime(date.toLocal().toIso8601String());
}

class _SignBox extends StatelessWidget {
  const _SignBox({
    required this.signature,
    required this.confirmed,
    required this.onConfirmed,
    required this.codeSentTo,
    required this.codeController,
    required this.codeLength,
    required this.requesting,
    required this.signing,
    required this.onRequestCode,
    required this.onSign,
  });

  final Signature signature;
  final bool confirmed;
  final ValueChanged<bool> onConfirmed;
  final String codeSentTo;
  final TextEditingController codeController;
  final int codeLength;
  final bool requesting;
  final bool signing;
  final VoidCallback onRequestCode;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (signature.isSigned) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified, color: AppTheme.primaryColor, size: 32),
          title: const Text(
            'Du har signerat protokollet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(formatSignedAt(signature.signedAt)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signature.role.isEmpty
                  ? 'Signera'
                  : 'Signera som ${signature.role}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Läs igenom protokollet nedan. Signera sedan med en engångskod som skickas till din e-post.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (codeSentTo.isEmpty) ...[
              CheckboxListTile(
                value: confirmed,
                onChanged: (v) => onConfirmed(v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Jag har läst protokollet och intygar att det stämmer',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: confirmed && !requesting ? onRequestCode : null,
                  icon: requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Skicka kod till min e-post'),
                ),
              ),
            ] else ...[
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Vi har skickat en 6-siffrig kod till ',
                    ),
                    TextSpan(
                      text: codeSentTo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '. Den gäller i 10 minuter.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                autofocus: true,
                enabled: !signing,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  letterSpacing: 10,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSign(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: codeLength == 6 && !signing ? onSign : null,
                      child: signing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Signera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: requesting ? null : onRequestCode,
                    child: const Text('Skicka ny kod'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignersCard extends StatelessWidget {
  const _SignersCard({required this.signatures});

  final List<Signature> signatures;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signerare',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final s in signatures)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      s.isSigned ? Icons.check_circle : Icons.schedule,
                      size: 18,
                      color: s.isSigned ? AppTheme.primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          s.displayName,
                          if (s.role.isNotEmpty) s.role,
                          if (s.isSigned) formatSignedAt(s.signedAt),
                        ].join(' · '),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProtocolSection extends StatelessWidget {
  const _ProtocolSection({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${item is Map ? (item['question'] ?? '') : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final answer = item is Map
                        ? ((item['answer'] as String?) ?? '').trim()
                        : '$item';
                    return answer.isEmpty
                        ? const Text('—')
                        : RichDescription(html: answer, fontSize: 15);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
