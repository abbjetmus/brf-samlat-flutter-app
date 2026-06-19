import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_text_editor.dart';

class CreatePostPage extends CompositionWidget {
  static const String path = '/posts/create';
  static const String editPath = '/posts/edit';

  /// When non-null the page edits the existing post instead of creating one.
  final String? postId;

  const CreatePostPage({super.key, this.postId});

  @override
  Widget Function(BuildContext) setup() {
    final postsStore = inject(postsStoreKey);
    final isEdit = postId != null;
    final existing = (isEdit && postsStore.currentPost.value?.id == postId)
        ? postsStore.currentPost.value
        : null;

    final (titleController, _, __) = useTextEditingController();
    final commentsAllowed = ref(existing?.commentsAllowed ?? true);
    final pinAsGeneralInfo = ref(existing?.pinAsGeneralInfo ?? false);
    final addToCalendar = ref(existing?.addToCalendar ?? false);
    final loading = ref(false);
    final contextRef = useContext();

    // Description is rich text (HTML). Hold the current HTML and only mount the
    // editor once the initial content is known (it can load late on deep-links).
    var descriptionHtml = existing?.description ?? '';
    final descriptionReady = ref(!isEdit || existing != null);

    if (existing != null) {
      titleController.text = existing.title;
    }

    onMounted(() async {
      // Cover deep-links / stale state where the post isn't loaded yet.
      if (isEdit && existing == null) {
        await postsStore.getPost(postId!);
        final post = postsStore.currentPost.value;
        if (post != null && post.id == postId) {
          titleController.text = post.title;
          descriptionHtml = post.description;
          commentsAllowed.value = post.commentsAllowed;
          pinAsGeneralInfo.value = post.pinAsGeneralInfo;
          addToCalendar.value = post.addToCalendar;
        }
        descriptionReady.value = true;
      }
    });

    Future<void> savePost() async {
      if (titleController.text.trim().isEmpty) return;
      if (htmlIsEmpty(descriptionHtml)) return;

      loading.value = true;
      final success = isEdit
          ? await postsStore.updatePost(
              id: postId!,
              title: titleController.text.trim(),
              description: descriptionHtml,
              commentsAllowed: commentsAllowed.value,
              pinAsGeneralInfo: pinAsGeneralInfo.value,
              addToCalendar: addToCalendar.value,
            )
          : await postsStore.createPost(
              title: titleController.text.trim(),
              description: descriptionHtml,
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
              content: Text(isEdit ? 'Nyhet uppdaterad!' : 'Nyhet skapad!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera nyhet.'
                    : 'Kunde inte skapa nyhet.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera nyhet' : 'Skapa nyhet',
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
            Text(
              'Beskrivning',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            if (descriptionReady.value)
              RichTextEditor(
                initialHtml: descriptionHtml,
                onChanged: (html) => descriptionHtml = html,
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
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
              onPressed: loading.value ? null : savePost,
              child: loading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa nyhet'),
            ),
          ],
        ),
      ),
    );
  }
}
