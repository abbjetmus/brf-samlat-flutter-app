import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';

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

    onMounted(() async {
      await formsStore.getUserFormResponses();
      final response = formsStore.userFormResponses.value
          .where((r) => r.id == formResponseId)
          .firstOrNull;
      if (response?.answers != null) {
        answers.value = Map<String, dynamic>.from(response!.answers!);
      }
    });

    return (context) {
      final responses = formsStore.userFormResponses.value;
      final loading = formsStore.loading.value;
      final response = responses.where((r) => r.id == formResponseId).firstOrNull;

      if (loading && response == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Formulär')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      if (response == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Formulär')),
          body: const Center(child: Text('Formulär hittades inte.')),
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

      return Scaffold(
        appBar: AppBar(
          title: Text(formName),
          actions: [
            if (saving.value)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Spara',
                onPressed: () async {
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
                },
              ),
          ],
        ),
        body: questions.isEmpty
            ? const Center(child: Text('Inga frågor.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  String questionText = '';
                  String questionKey = 'q_$index';
                  if (question is Map<String, dynamic>) {
                    questionText = question['question'] as String? ??
                        question['title'] as String? ??
                        question['label'] as String? ??
                        'Fråga ${index + 1}';
                    questionKey = question['id'] as String? ?? 'q_$index';
                  } else if (question is String) {
                    questionText = question;
                  }

                  final currentAnswer = answers.value[questionKey]?.toString() ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questionText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: currentAnswer,
                        decoration: const InputDecoration(
                          hintText: 'Skriv ditt svar...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          final updated = Map<String, dynamic>.from(answers.value);
                          updated[questionKey] = value;
                          answers.value = updated;
                        },
                      ),
                    ],
                  );
                },
              ),
      );
    };
  }
}
