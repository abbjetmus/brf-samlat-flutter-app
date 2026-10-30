import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/pb_error.dart';
import '../contractors_store.dart';

/// "Skicka till leverantör" (POST /api/issues/{id}/forward). After sending it
/// shows the contractor's personal status link, which is only returned once,
/// with a copy button. Pops `true` once something was sent.
class ForwardIssueSheet extends CompositionWidget {
  final ContractorsStore store;
  final String issueId;
  final bool isResidenceIssue;
  final int attachmentCount;

  const ForwardIssueSheet({
    super.key,
    required this.store,
    required this.issueId,
    required this.isResidenceIssue,
    required this.attachmentCount,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();

    final contractors = ref<List<ContractorsRecord>>([]);
    final loadingContractors = ref(true);
    final contractorId = ref<String?>(null);
    final (messageController, message, _) = useTextEditingController();
    // A residence issue is private: the address is only sent if chosen.
    final includeAddress = ref<bool>(!props.value.isResidenceIssue);
    final includeAttachments = ref(false);
    final sending = ref(false);
    final error = ref<String?>(null);
    final result = ref<ForwardResult?>(null);

    onMounted(() async {
      try {
        contractors.value = await props.value.store.all();
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta leverantörerna.');
      } finally {
        loadingContractors.value = false;
      }
    });

    Future<void> send() async {
      final id = contractorId.value;
      if (id == null) return;
      sending.value = true;
      error.value = null;
      final res = await props.value.store.forward(
        props.value.issueId,
        contractorId: id,
        message: message.value.trim(),
        includeAddress: includeAddress.value,
        includeAttachments:
            includeAttachments.value && props.value.attachmentCount > 0,
      );
      sending.value = false;
      if (res.error != null) {
        error.value = res.error;
        return;
      }
      result.value = res.result;
    }

    Future<void> copyLink() async {
      final link = result.value?.link ?? '';
      await Clipboard.setData(ClipboardData(text: link));
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Länken kopierad')));
      }
    }

    void close() {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop(result.value != null);
      }
    }

    return (context) {
      final sent = result.value;
      final p = props.value;
      final caption = TextStyle(fontSize: 12, color: Colors.grey[600]);

      if (sent != null) {
        final ok = sent.emailSent;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Skicka till leverantör',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (ok ? Colors.green : Colors.orange).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ok
                    ? 'Ärendet har skickats till ${sent.forward.contractorName} '
                          '(${sent.forward.contractorEmail}).'
                    : 'Länken skapades, men mejlet kunde inte skickas. Kopiera '
                          'länken nedan och skicka den till leverantören på annat '
                          'sätt, eller försök igen senare.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Leverantörens personliga statuslänk. Den visas bara nu och gäller '
              'till ${AppDateUtils.formatDate(sent.forward.expiresAt)}.',
              style: caption,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      sent.link,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Kopiera länken',
                    onPressed: copyLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: close, child: const Text('Klar')),
          ],
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Skicka till leverantör',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (loadingContractors.value)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (contractors.value.isEmpty && error.value == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Föreningen har inga leverantörer än. Lägg till en leverantör '
                'under Leverantörer först.',
              ),
            )
          else if (contractors.value.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: contractorId.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Leverantör',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in contractors.value)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.name} · ${contractorTradeMeta(c.trade).title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => contractorId.value = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Meddelande (valfritt)',
                hintText:
                    'T.ex. när ni kan komma, vem ni ska kontakta på plats eller '
                    'hur ni kommer in.',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: includeAddress.value,
              onChanged: (v) => includeAddress.value = v,
              title: Text(
                p.isResidenceIssue
                    ? 'Ta med bostadens adress och besked om huvudnyckel'
                    : 'Ta med föreningens adress',
              ),
            ),
            if (p.isResidenceIssue)
              Text(
                'Felanmälan gäller en bostad och är privat. Ta bara med adressen '
                'om leverantören behöver den. De boendes namn och kommentarer '
                'skickas aldrig.',
                style: caption,
              ),
            if (p.attachmentCount > 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: includeAttachments.value,
                onChanged: (v) => includeAttachments.value = v,
                title: Text(
                  'Ta med bilagor som länkar (${p.attachmentCount})',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Leverantören får ett mejl med rubrik och beskrivning och en '
              'personlig länk, giltig i 90 dagar, där hen kan meddela mottagen, '
              'planerad eller åtgärdad. Uppdateringarna blir kommentarer på '
              'ärendet.',
              style: caption,
            ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: contractorId.value != null && !sending.value
                ? send
                : null,
            icon: sending.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Skicka'),
          ),
        ],
      );
    };
  }
}
