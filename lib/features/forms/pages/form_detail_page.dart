import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class FormDetailPage extends CompositionWidget {
  static const String path = '/forms/detail';

  final String formResponseId;

  const FormDetailPage({super.key, required this.formResponseId});

  @override
  Widget Function(BuildContext) setup() {
    final formsStore = inject(formsStoreKey);
    final contextRef = useContext();
    final answers = ref<Map<String, dynamic>>({});
    final saving = ref<bool>(false);
    // Becomes true after a failed save attempt so required fields show errors.
    final showErrors = ref<bool>(false);

    onMounted(() async {
      await formsStore.getUserFormResponses();
      final response = formsStore.userFormResponses.value
          .where((r) => r.id == formResponseId)
          .firstOrNull;
      if (response?.answers != null) {
        answers.value = Map<String, dynamic>.from(response!.answers!);
      }
    });

    // --- Helpers -------------------------------------------------------------

    void setAnswer(String key, dynamic value) {
      final updated = Map<String, dynamic>.from(answers.value);
      updated[key] = value;
      answers.value = updated;
    }

    void setCheckboxOption(String key, String optionId, bool checked) {
      final updated = Map<String, dynamic>.from(answers.value);
      final group = Map<String, dynamic>.from(
        (updated[key] as Map?)?.cast<String, dynamic>() ?? {},
      );
      group[optionId] = checked;
      updated[key] = group;
      answers.value = updated;
    }

    bool isItemAnswered(Map<String, dynamic> item) {
      final component = item['component'] as String?;
      final value = answers.value[item['id']];
      switch (component) {
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

    String two(int n) => n.toString().padLeft(2, '0');

    // --- UI builders ---------------------------------------------------------

    Widget buildField(
      Map<String, dynamic> item,
      int index,
      BuildContext context,
    ) {
      final component = item['component'] as String?;
      final id = item['id'] as String? ?? 'q_$index';
      final label = item['text'] as String? ?? 'Fråga ${index + 1}';
      final required = item['required'] == true;
      final options =
          (item['schema'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final showError = showErrors.value && required && !isItemAnswered(item);

      final labelWidget = Text.rich(
        TextSpan(
          text: label,
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ]
              : null,
        ),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );

      Widget withError(Widget child) {
        if (!showError) return child;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Obligatoriskt fält',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ),
          ],
        );
      }

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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: 8),
              TextFormField(
                initialValue: answers.value[id]?.toString() ?? '',
                decoration: InputDecoration(
                  hintText: 'Skriv ditt svar...',
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Obligatoriskt fält' : null,
                ),
                maxLines: component == 'forms-textarea' ? 4 : 1,
                onChanged: (value) => setAnswer(id, value),
              ),
            ],
          );

        case 'forms-date':
          {
            final value = answers.value[id] as String?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                withError(
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      value == null || value.isEmpty ? 'Välj datum' : value,
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () async {
                      final initial = DateTime.tryParse(value ?? '') ??
                          DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        locale: const Locale('sv', 'SE'),
                      );
                      if (picked != null) {
                        setAnswer(
                          id,
                          '${picked.year}-${two(picked.month)}-${two(picked.day)}',
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }

        case 'forms-time':
          {
            final value = answers.value[id] as String?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                withError(
                  OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_outlined),
                    label: Text(
                      value == null || value.isEmpty ? 'Välj tid' : value,
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () async {
                      final parts = (value ?? '').split(':');
                      final initial = TimeOfDay(
                        hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 12,
                        minute:
                            int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
                      );
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initial,
                      );
                      if (picked != null) {
                        setAnswer(id, '${two(picked.hour)}:${two(picked.minute)}');
                      }
                    },
                  ),
                ),
              ],
            );
          }

        case 'forms-radio':
          {
            final selected = answers.value[id] as String?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) => setAnswer(id, v),
                  child: Column(
                    children: options
                        .map(
                          (opt) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(opt['text'] as String? ?? ''),
                            value: opt['id'] as String? ?? '',
                            activeColor: AppTheme.primaryColor,
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (showError)
                  const Padding(
                    padding: EdgeInsets.only(top: 2, left: 4),
                    child: Text(
                      'Obligatoriskt fält',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
              ],
            );
          }

        case 'forms-checkbox':
          {
            final group =
                (answers.value[id] as Map?)?.cast<String, dynamic>() ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                ...options.map(
                  (opt) {
                    final optId = opt['id'] as String? ?? '';
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(opt['text'] as String? ?? ''),
                      value: group[optId] == true,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (v) =>
                          setCheckboxOption(id, optId, v ?? false),
                    );
                  },
                ),
                if (showError)
                  const Padding(
                    padding: EdgeInsets.only(top: 2, left: 4),
                    child: Text(
                      'Välj minst ett alternativ',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
              ],
            );
          }

        default:
          // Unknown component: fall back to a plain text field so nothing is lost.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: 8),
              TextFormField(
                initialValue: answers.value[id]?.toString() ?? '',
                decoration: const InputDecoration(
                  hintText: 'Skriv ditt svar...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => setAnswer(id, value),
              ),
            ],
          );
      }
    }

    return (context) {
      final responses = formsStore.userFormResponses.value;
      final loading = formsStore.loading.value;
      final response = responses.where((r) => r.id == formResponseId).firstOrNull;

      if (loading && response == null) {
        return const GradientScaffold(
          title: 'Formulär',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (response == null) {
        return const GradientScaffold(
          title: 'Formulär',
          body: Center(child: Text('Formulär hittades inte.')),
        );
      }

      // Extract form data from expand
      final expandForm = response.expand?['form'];
      String formName = 'Formulär';
      List<dynamic> questions = [];
      if (expandForm is Map<String, dynamic>) {
        formName = expandForm['name'] as String? ?? 'Formulär';
        questions = expandForm['form_questions'] as List<dynamic>? ?? [];
      } else if (expandForm is List && expandForm.isNotEmpty) {
        final formData = expandForm.first as Map<String, dynamic>;
        formName = formData['name'] as String? ?? 'Formulär';
        questions = formData['form_questions'] as List<dynamic>? ?? [];
      }

      Future<void> save() async {
        final missing = questions
            .whereType<Map<String, dynamic>>()
            .where((q) => q['required'] == true && !isItemAnswered(q))
            .toList();
        if (missing.isNotEmpty) {
          showErrors.value = true;
          final ctx = contextRef.value;
          if (ctx != null && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Fyll i alla obligatoriska fält.')),
            );
          }
          return;
        }

        saving.value = true;
        final success = await formsStore.updateFormResponse(
          id: formResponseId,
          answers: answers.value,
        );
        saving.value = false;
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(success ? 'Svar sparade.' : 'Kunde inte spara svar.'),
            ),
          );
        }
      }

      return GradientScaffold(
        title: formName,
        actions: [
          if (saving.value)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            HeaderIconButton(
              icon: Icons.save,
              tooltip: 'Spara',
              onPressed: save,
            ),
        ],
        body: questions.isEmpty
            ? const Center(child: Text('Inga frågor.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  if (question is! Map<String, dynamic>) {
                    return Text(question.toString());
                  }
                  return buildField(question, index, context);
                },
              ),
      );
    };
  }
}
