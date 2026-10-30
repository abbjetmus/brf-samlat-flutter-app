import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../invoices/invoice_payment_status.dart';

typedef RegisterPaymentCallback =
    Future<String?> Function({
      required double amount,
      required String paymentDate,
      required String reference,
      required String note,
    });

String _amountText(double value) {
  if (value <= 0) return '';
  final whole = (value * 100).round() % 100 == 0;
  return whole
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceAll('.', ',');
}

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.'));

/// "Registrera betalning": amount prefilled with what is left to pay, date
/// defaulting to today. Saves through [onSave] and closes itself on success
/// (pops `true`); a failure is shown in the sheet.
class RegisterPaymentSheet extends CompositionWidget {
  final InvoicesRecord invoice;
  final RegisterPaymentCallback onSave;

  const RegisterPaymentSheet({
    super.key,
    required this.invoice,
    required this.onSave,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final invoice = props.value.invoice;
    final contextRef = useContext();

    final (amountController, amountText, _) = useTextEditingController(
      text: _amountText(invoice.outstanding),
    );
    final (referenceController, reference, _) = useTextEditingController(
      text: invoice.ocr,
    );
    final (noteController, note, _) = useTextEditingController();
    final paymentDate = ref<DateTime>(DateTime.now());
    final saving = ref(false);
    final error = ref<String?>(null);

    final amount = computed(() => _parseAmount(amountText.value));
    final remainingAfter = computed(() {
      final a = amount.value ?? 0;
      return ((invoice.outstanding - a) * 100).roundToDouble() / 100;
    });
    final canSave = computed(
      () => !saving.value && amount.value != null && amount.value != 0,
    );

    Future<void> pickDate() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: paymentDate.value,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) paymentDate.value = picked;
    }

    Future<void> save() async {
      final a = amount.value;
      if (a == null || a == 0) return;
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave(
        amount: a,
        paymentDate: DateFormat('yyyy-MM-dd').format(paymentDate.value),
        reference: reference.value.trim(),
        note: note.value.trim(),
      );
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
    }

    return (context) {
      final left = remainingAfter.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Registrera betalning',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${invoice.ocr.isNotEmpty ? 'OCR ${invoice.ocr}. ' : ''}'
            'Fakturerat ${formatKr(invoice.amount)}, redan betalt '
            '${formatKr(invoice.paidAmount)}. Beloppet är förifyllt med det som '
            'återstår. Ändra det för en delbetalning.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\- ]')),
            ],
            decoration: InputDecoration(
              labelText: 'Belopp',
              suffixText: 'kr',
              border: const OutlineInputBorder(),
              errorText: amountText.value.isNotEmpty && amount.value == null
                  ? 'Ange ett belopp'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Betalningsdatum',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              child: Text(DateFormat('yyyy-MM-dd').format(paymentDate.value)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: referenceController,
            decoration: const InputDecoration(
              labelText: 'Referens',
              helperText: 'T.ex. OCR-numret från kontoutdraget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Anteckning (valfritt)',
              border: OutlineInputBorder(),
            ),
          ),
          if (amount.value != null && left < 0) ...[
            const SizedBox(height: 8),
            Text(
              'Beloppet är ${formatKr(-left)} mer än det som återstår. '
              'Fakturan blir överbetald.',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ] else if (amount.value != null && left > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Delbetalning: ${formatKr(left)} återstår efteråt.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: 12),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave.value ? save : null,
            child: saving.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrera'),
          ),
        ],
      );
    };
  }
}
