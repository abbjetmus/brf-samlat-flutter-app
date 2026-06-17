import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CreateIssuePage extends CompositionWidget {
  static const String path = '/issues/create';

  const CreateIssuePage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final (titleController, _, __) = useTextEditingController();
    final (descriptionController, ___, ____) = useTextEditingController();
    final issueType = ref<String>('Felanmälan');
    final commentsAllowed = ref(true);
    final consentToMasterKey = ref(false);
    final loading = ref(false);
    final contextRef = useContext();

    Future<void> createIssue() async {
      if (titleController.text.trim().isEmpty) return;
      if (descriptionController.text.trim().isEmpty) return;

      loading.value = true;
      final success = await issuesStore.createIssue(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        type: issueType.value,
        commentsAllowed: commentsAllowed.value,
        consentToMasterKey: consentToMasterKey.value,
      );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        final noun = issueType.value.toLowerCase();
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${issueType.value} skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunde inte skapa $noun.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) {
      final noun = issueType.value.toLowerCase();
      return GradientScaffold(
        title: 'Skapa $noun',
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: issueType.value,
                decoration: const InputDecoration(
                  labelText: 'Typ',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Felanmälan', child: Text('Felanmälan')),
                  DropdownMenuItem(value: 'Ärende', child: Text('Ärende')),
                ],
                onChanged: (value) {
                  if (value != null) issueType.value = value;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beskrivning',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Tillåt kommentarer'),
              value: commentsAllowed.value,
              onChanged: (v) => commentsAllowed.value = v,
            ),
            SwitchListTile(
              title: const Text('Samtycke till huvudnyckel'),
              subtitle: const Text('Ge tillgång med huvudnyckel till bostaden'),
              value: consentToMasterKey.value,
              onChanged: (v) => consentToMasterKey.value = v,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading.value ? null : createIssue,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Skapa $noun'),
            ),
          ],
        ),
      ),
      );
    };
  }
}
