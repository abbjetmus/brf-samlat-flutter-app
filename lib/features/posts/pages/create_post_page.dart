import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';

class CreatePostPage extends CompositionWidget {
  static const String path = '/posts/create';

  const CreatePostPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final postsStore = inject(postsStoreKey);
    final (titleController, _, __) = useTextEditingController();
    final (descriptionController, ___, ____) = useTextEditingController();
    final commentsAllowed = ref(true);
    final pinAsGeneralInfo = ref(false);
    final addToCalendar = ref(false);
    final loading = ref(false);
    final contextRef = useContext();

    Future<void> createPost() async {
      if (titleController.text.trim().isEmpty) return;
      if (descriptionController.text.trim().isEmpty) return;

      loading.value = true;
      final success = await postsStore.createPost(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        commentsAllowed: commentsAllowed.value,
        pinAsGeneralInfo: pinAsGeneralInfo.value,
        addToCalendar: addToCalendar.value,
      );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nyhet skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kunde inte skapa nyhet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Skapa nyhet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              title: const Text('Fäst som allmän information'),
              value: pinAsGeneralInfo.value,
              onChanged: (v) => pinAsGeneralInfo.value = v,
            ),
            SwitchListTile(
              title: const Text('Lägg till i kalender'),
              value: addToCalendar.value,
              onChanged: (v) => addToCalendar.value = v,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading.value ? null : createPost,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Skapa nyhet'),
            ),
          ],
        ),
      ),
    );
  }
}
