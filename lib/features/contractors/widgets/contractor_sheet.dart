import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../contractors_store.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// "Ny leverantör" / "Redigera leverantör". Saves through [onSave] and pops
/// `true` on success; errors are shown in the sheet.
class ContractorSheet extends CompositionWidget {
  final ContractorsRecord? contractor;
  final Future<String?> Function(Map<String, dynamic> body) onSave;

  const ContractorSheet({super.key, this.contractor, required this.onSave});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final c = props.value.contractor;
    final contextRef = useContext();

    final (nameController, name, _) = useTextEditingController(
      text: c?.name ?? '',
    );
    final (contactController, contact, _) = useTextEditingController(
      text: c?.contactName ?? '',
    );
    final (emailController, email, _) = useTextEditingController(
      text: c?.email ?? '',
    );
    final (phoneController, phone, _) = useTextEditingController(
      text: c?.phone ?? '',
    );
    final (notesController, notes, _) = useTextEditingController(
      text: c?.notes ?? '',
    );
    final trade = ref<String>(c?.trade ?? 'rörmokare');
    final saving = ref(false);
    final error = ref<String?>(null);

    final emailValid = computed(() => _emailPattern.hasMatch(email.value.trim()));
    final canSave = computed(
      () => !saving.value && name.value.trim().isNotEmpty && emailValid.value,
    );

    Future<void> save() async {
      if (!canSave.value) return;
      saving.value = true;
      error.value = null;
      final message = await props.value.onSave({
        'name': name.value.trim(),
        'trade': trade.value,
        'contact_name': contact.value.trim(),
        'email': email.value.trim(),
        'phone': phone.value.trim(),
        'notes': notes.value.trim(),
      });
      saving.value = false;
      if (message != null) {
        error.value = message;
        return;
      }
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(true);
    }

    return (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            c == null ? 'Ny leverantör' : 'Redigera leverantör',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Företag',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: trade.value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Yrke',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in contractorTrades)
                DropdownMenuItem(value: t.value, child: Text(t.title)),
            ],
            onChanged: (v) => trade.value = v ?? trade.value,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contactController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Kontaktperson (valfri)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'E-post',
              border: const OutlineInputBorder(),
              errorText: email.value.isNotEmpty && !emailValid.value
                  ? 'Ange en giltig e-postadress'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon (valfri)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Anteckningar (valfri)',
              hintText: 'T.ex. avtal, jourtider, kundnummer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ärenden skickas till e-postadressen ovan. Anteckningarna syns bara '
            'för styrelsen.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
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
                : const Text('Spara'),
          ),
        ],
      );
    };
  }
}
