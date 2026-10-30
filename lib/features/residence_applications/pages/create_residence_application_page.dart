import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../residence_applications_store.dart';

/// Create form for a new application. Pops `true` when submitted.
class CreateResidenceApplicationPage extends CompositionWidget {
  static const String path = '/residence-applications/create';

  const CreateResidenceApplicationPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = ResidenceApplicationsStore(
      inject(pocketBaseKey),
      inject(authStoreKey),
    );
    final contextRef = useContext();

    final type = ref('andrahand');
    final residences = ref<List<ResidencesRecord>>([]);
    final residenceId = ref<String?>(null);
    final loadingResidences = ref(true);
    final periodFrom = ref<DateTime?>(null);
    final periodTo = ref<DateTime?>(null);
    final accessDate = ref<DateTime?>(null);
    final files = ref<List<PlatformFile>>([]);
    final saving = ref(false);
    final error = ref<String?>(null);

    final (tenantNameController, tenantName, _) = useTextEditingController();
    final (tenantEmailController, _, _) = useTextEditingController();
    final (tenantPhoneController, _, _) = useTextEditingController();
    final (reasonController, _, _) = useTextEditingController();
    final (buyerNamesController, buyerNames, _) = useTextEditingController();
    final (priceController, _, _) = useTextEditingController();
    final (descriptionController, description, _) =
        useTextEditingController();

    onMounted(() async {
      residences.value = await store.ownResidences();
      if (residences.value.isNotEmpty) {
        residenceId.value = residences.value.first.id;
      }
      loadingResidences.value = false;
    });

    // Same requirements as the server (utils/residence_application_utils.js).
    final valid = computed(() {
      if (residenceId.value == null) return false;
      switch (type.value) {
        case 'andrahand':
          final from = periodFrom.value;
          final to = periodTo.value;
          return from != null &&
              to != null &&
              !to.isBefore(from) &&
              tenantName.value.trim().isNotEmpty;
        case 'överlåtelse':
          return buyerNames.value.trim().isNotEmpty && accessDate.value != null;
        case 'medlemskap':
          return buyerNames.value.trim().isNotEmpty;
        case 'ombyggnad':
          return description.value.trim().isNotEmpty;
      }
      return false;
    });

    String fmt(DateTime? d) =>
        d == null ? '' : DateFormat('yyyy-MM-dd').format(d);
    String pbDate(DateTime? d) => d == null ? '' : '${fmt(d)} 00:00:00.000Z';

    Future<void> pickDate(Ref<DateTime?> target, {DateTime? first}) async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: ctx,
        initialDate: target.value ?? first ?? now,
        firstDate: first ?? DateTime(now.year - 1),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) target.value = picked;
    }

    Future<void> pickFiles() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      final ok = result.files
          .where((f) => f.bytes != null && f.size <= kMaxUploadBytes)
          .toList();
      files.value = [...files.value, ...ok];
      if (ok.length < result.files.length) {
        error.value =
            'Vissa filer var för stora (max ${byteToMegabyte(kMaxUploadBytes)} MB per fil).';
      }
    }

    Future<void> submit() async {
      if (!valid.value) return;
      saving.value = true;
      error.value = null;
      final body = <String, dynamic>{
        'type': type.value,
        'residence': residenceId.value,
        'description': descriptionController.text.trim(),
      };
      switch (type.value) {
        case 'andrahand':
          body.addAll({
            'period_from': pbDate(periodFrom.value),
            'period_to': pbDate(periodTo.value),
            'tenant_name': tenantNameController.text.trim(),
            'tenant_email': tenantEmailController.text.trim(),
            'tenant_phone': tenantPhoneController.text.trim(),
            'reason': reasonController.text.trim(),
          });
        case 'överlåtelse':
          body.addAll({
            'buyer_names': buyerNamesController.text.trim(),
            'access_date': pbDate(accessDate.value),
            'price':
                num.tryParse(
                  priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0,
          });
        case 'medlemskap':
          body['buyer_names'] = buyerNamesController.text.trim();
      }
      final multipart = [
        for (final f in files.value)
          http.MultipartFile.fromBytes('attachments', f.bytes!, filename: f.name),
      ];
      final failure = await store.create(body, multipart);
      saving.value = false;

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      if (failure != null) {
        error.value = failure;
        return;
      }
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Ansökan skickad till styrelsen'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(ctx).pop(true);
    }

    Widget dateField(String label, Ref<DateTime?> target, {DateTime? first}) {
      return InkWell(
        onTap: () => pickDate(target, first: first),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(target.value == null ? 'Välj datum' : fmt(target.value)),
        ),
      );
    }

    const gap = SizedBox(height: 16);

    return (context) {
      if (loadingResidences.value) {
        return const GradientScaffold(
          title: 'Ny ansökan',
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (residences.value.isEmpty) {
        return const GradientScaffold(
          title: 'Ny ansökan',
          body: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Du är inte kopplad till någon bostad ännu. Be styrelsen koppla '
                'dig till din bostad, så kan du ansöka.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      final t = type.value;
      return GradientScaffold(
        title: 'Ny ansökan',
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: t,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Typ av ansökan',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final at in applicationTypes)
                    DropdownMenuItem(value: at.value, child: Text(at.title)),
                ],
                onChanged: (v) {
                  if (v != null) type.value = v;
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                  applicationTypeMeta(t).description,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              gap,
              if (residences.value.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: residenceId.value,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Bostad',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final r in residences.value)
                      DropdownMenuItem(
                        value: r.id,
                        child: Text(r.streetAddress),
                      ),
                  ],
                  onChanged: (v) => residenceId.value = v,
                ),
                gap,
              ],
              if (t == 'andrahand') ...[
                dateField('Från', periodFrom),
                gap,
                dateField('Till och med', periodTo, first: periodFrom.value),
                gap,
                TextField(
                  controller: tenantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Andrahandshyresgästens namn',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
                TextField(
                  controller: tenantEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Hyresgästens e-post',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
                TextField(
                  controller: tenantPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Hyresgästens telefon',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Skäl till uthyrningen',
                    helperText:
                        'T.ex. arbete eller studier på annan ort, provbo med partner',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
              ],
              if (t == 'överlåtelse' || t == 'medlemskap') ...[
                TextField(
                  controller: buyerNamesController,
                  decoration: InputDecoration(
                    labelText: t == 'överlåtelse'
                        ? 'Köparens namn (alla köpare)'
                        : 'Namn på den/de som söker medlemskap',
                    border: const OutlineInputBorder(),
                  ),
                ),
                gap,
              ],
              if (t == 'överlåtelse') ...[
                dateField('Tillträdesdatum', accessDate),
                gap,
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pris (kr, valfritt)',
                    border: OutlineInputBorder(),
                  ),
                ),
                gap,
              ],
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: t == 'ombyggnad'
                      ? 'Beskriv förändringen'
                      : 'Övrig information (valfri)',
                  helperText: t == 'ombyggnad'
                      ? 'Vad ska göras, av vem och när? Bifoga gärna ritning.'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              gap,
              OutlinedButton.icon(
                onPressed: pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Bifoga filer'),
              ),
              for (final f in files.value)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(f.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Ta bort',
                    onPressed: () => files.value = files.value
                        .where((x) => x != f)
                        .toList(),
                  ),
                ),
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error.value!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: valid.value && !saving.value ? submit : null,
                child: saving.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Skicka in'),
              ),
            ],
          ),
        ),
      );
    };
  }
}
