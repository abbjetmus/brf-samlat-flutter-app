import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class CreateIssuePage extends CompositionWidget {
  static const String path = '/issues/create';
  static const String editPath = '/issues/edit';

  /// When non-null the page edits the existing issue instead of creating one.
  final String? issueId;

  const CreateIssuePage({super.key, this.issueId});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final isEdit = issueId != null;
    final existing = (isEdit && issuesStore.currentIssue.value?.id == issueId)
        ? issuesStore.currentIssue.value
        : null;

    final (titleController, _, __) = useTextEditingController();
    final (descriptionController, ___, ____) = useTextEditingController();
    final issueType = ref<String>(existing?.type ?? 'Felanmälan');
    final commentsAllowed = ref(existing?.commentsAllowed ?? true);
    final consentToMasterKey = ref(existing?.consentToMasterKey ?? false);
    final loading = ref(false);
    final contextRef = useContext();

    if (existing != null) {
      titleController.text = existing.title;
      descriptionController.text = existing.description;
    }

    onMounted(() async {
      // Cover deep-links / stale state where the issue isn't loaded yet.
      if (isEdit && existing == null) {
        await issuesStore.getIssue(issueId!);
        final issue = issuesStore.currentIssue.value;
        if (issue != null && issue.id == issueId) {
          titleController.text = issue.title;
          descriptionController.text = issue.description;
          issueType.value = issue.type ?? 'Felanmälan';
          commentsAllowed.value = issue.commentsAllowed;
          consentToMasterKey.value = issue.consentToMasterKey ?? false;
        }
      }
    });

    Future<void> saveIssue() async {
      if (titleController.text.trim().isEmpty) return;
      if (descriptionController.text.trim().isEmpty) return;

      loading.value = true;
      final success = isEdit
          ? await issuesStore.updateIssue(
              id: issueId!,
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              type: issueType.value,
              commentsAllowed: commentsAllowed.value,
              consentToMasterKey: consentToMasterKey.value,
            )
          : await issuesStore.createIssue(
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
              content: Text(
                isEdit
                    ? '${issueType.value} uppdaterad!'
                    : '${issueType.value} skapad!',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera $noun.'
                    : 'Kunde inte skapa $noun.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) {
      final noun = issueType.value.toLowerCase();
      return GradientScaffold(
        title: isEdit ? 'Redigera $noun' : 'Skapa $noun',
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
              onPressed: loading.value ? null : saveIssue,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa $noun'),
            ),
          ],
        ),
      ),
      );
    };
  }
}
