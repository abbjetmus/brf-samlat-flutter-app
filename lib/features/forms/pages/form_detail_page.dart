import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../widgets/form_field_checkbox.dart';
import '../widgets/form_field_date.dart';
import '../widgets/form_field_radio.dart';
import '../widgets/form_field_text.dart';
import '../widgets/form_field_time.dart';

class FormDetailPage extends CompositionWidget {
  static const String path = '/forms/detail';

  final String formResponseId;

  const FormDetailPage({super.key, required this.formResponseId});

  @override
  Widget Function(BuildContext) setup() {
    final formsStore = inject(formsStoreKey);
    final contextRef = useContext();

    // Plain answer collector. Each field owns its own display state (zmartrest
    // native-form pattern) and reports here via onChanged, so we mutate this
    // map in place and never need to rebuild the page for a selection to show.
    final answers = <String, dynamic>{};

    final loading = ref<bool>(true);
    final notFound = ref<bool>(false);
    final saving = ref<bool>(false);
    // Flips true after a failed save attempt; passed to fields so required
    // ones surface their error, and cleared again as the user fills them in.
    final validate = ref<bool>(false);
    final formName = ref<String>('Formulär');
    final questions = ref<List<Map<String, dynamic>>>([]);

    onMounted(() async {
      await formsStore.getUserFormResponses();
      final response = formsStore.userFormResponses.value
          .where((r) => r.id == formResponseId)
          .firstOrNull;

      if (response == null) {
        notFound.value = true;
        loading.value = false;
        return;
      }

      if (response.answers != null) {
        answers.addAll(Map<String, dynamic>.from(response.answers!));
      }

      // The expanded form may arrive as a Map or a single-item List.
      final expandForm = response.expand?['form'];
      Map<String, dynamic>? formData;
      if (expandForm is Map<String, dynamic>) {
        formData = expandForm;
      } else if (expandForm is List && expandForm.isNotEmpty) {
        formData = expandForm.first as Map<String, dynamic>;
      }
      if (formData != null) {
        formName.value = formData['name'] as String? ?? 'Formulär';
        questions.value =
            (formData['form_questions'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
      }

      loading.value = false;
    });

    // --- Helpers -------------------------------------------------------------

    bool isAnswered(Map<String, dynamic> question) {
      final value = answers[question['id']];
      switch (question['component'] as String?) {
        case 'forms-radio':
          return value != null && value.toString().isNotEmpty;
        case 'forms-checkbox':
          return value is Map && value.values.any((v) => v == true);
        case 'forms-input':
        case 'forms-textarea':
        case 'forms-date':
        case 'forms-time':
          return value is String && value.trim().isNotEmpty;
        default:
          return true; // static (title/label) components are always "ok"
      }
    }

    List<({String id, String text})> optionsOf(Map<String, dynamic> question) {
      return (question['schema'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (o) => (
              id: o['id'] as String? ?? '',
              text: o['text'] as String? ?? '',
            ),
          )
          .toList();
    }

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    Future<void> save() async {
      final missing = questions.value
          .where((q) => q['required'] == true && !isAnswered(q))
          .toList();
      if (missing.isNotEmpty) {
        validate.value = true;
        snack('Fyll i alla obligatoriska fält.');
        return;
      }

      saving.value = true;
      final success = await formsStore.updateFormResponse(
        id: formResponseId,
        answers: answers,
      );
      saving.value = false;
      snack(success ? 'Svar sparade.' : 'Kunde inte spara svar.');
    }

    // --- Field builder -------------------------------------------------------

    Widget buildField(Map<String, dynamic> question, int index) {
      final component = question['component'] as String?;
      final id = question['id'] as String? ?? 'q_$index';
      final label = question['text'] as String? ?? 'Fråga ${index + 1}';
      final required = question['required'] == true;
      final shouldValidate = validate.value;

      switch (component) {
        case 'forms-title':
          return Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          );

        case 'forms-label':
          return Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          );

        case 'forms-input':
        case 'forms-textarea':
          return FormFieldText(
            title: label,
            required: required,
            multiline: component == 'forms-textarea',
            initialValue: answers[id] as String?,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );

        case 'forms-radio':
          return FormFieldRadio(
            title: label,
            required: required,
            options: optionsOf(question),
            initialValue: answers[id] as String?,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );

        case 'forms-checkbox':
          final raw = answers[id];
          return FormFieldCheckbox(
            title: label,
            required: required,
            options: optionsOf(question),
            initialValue: raw is Map
                ? raw.map((k, v) => MapEntry(k.toString(), v == true))
                : null,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );

        case 'forms-date':
          return FormFieldDate(
            title: label,
            required: required,
            initialValue: answers[id] as String?,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );

        case 'forms-time':
          return FormFieldTime(
            title: label,
            required: required,
            initialValue: answers[id] as String?,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );

        default:
          // Unknown component: fall back to a plain text field so nothing is lost.
          return FormFieldText(
            title: label,
            required: required,
            multiline: true,
            initialValue: answers[id] as String?,
            validate: shouldValidate,
            onChanged: (value) => answers[id] = value,
          );
      }
    }

    return (context) {
      if (loading.value) {
        return const GradientScaffold(
          title: 'Formulär',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (notFound.value) {
        return const GradientScaffold(
          title: 'Formulär',
          body: Center(child: Text('Formulär hittades inte.')),
        );
      }

      final items = questions.value;

      // Build fields eagerly so each field widget mounts once with its seeded
      // initialValue. Reading validate.value here subscribes the page to it, so
      // a failed save re-renders and pushes the error flag down to the fields.
      final fields = <Widget>[];
      for (var index = 0; index < items.length; index++) {
        if (index > 0) fields.add(const SizedBox(height: 16));
        fields.add(buildField(items[index], index));
      }

      // "Svara" button at the bottom of the form.
      fields.add(const SizedBox(height: 24));
      fields.add(
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: saving.value ? null : save,
            child: saving.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Svara'),
          ),
        ),
      );

      return GradientScaffold(
        title: formName.value,
        body: items.isEmpty
            ? const Center(child: Text('Inga frågor.'))
            : ListView(padding: const EdgeInsets.all(16), children: fields),
      );
    };
  }
}
