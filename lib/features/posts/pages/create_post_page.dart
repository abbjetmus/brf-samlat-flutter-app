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
    final sendPushNotification = ref(existing?.sendPushNotification ?? false);
    final addToCalendar = ref(existing?.addToCalendar ?? false);
    final loading = ref(false);
    final contextRef = useContext();

    // Calendar start/end, shown only when "Lägg till i kalender" is on.
    // Stored as UTC ISO strings; held here as local DateTimes for the pickers.
    DateTime? parseStored(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      return DateTime.tryParse(iso)?.toLocal();
    }

    final startDate = ref<DateTime?>(parseStored(existing?.startAt));
    final endDate = ref<DateTime?>(parseStored(existing?.endAt));

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
          sendPushNotification.value = post.sendPushNotification ?? false;
          addToCalendar.value = post.addToCalendar;
          startDate.value = parseStored(post.startAt);
          endDate.value = parseStored(post.endAt);
        }
        descriptionReady.value = true;
      }
    });

    Future<void> pickDateTime(BuildContext context, Ref<DateTime?> target) async {
      final date = await showDatePicker(
        context: context,
        initialDate: target.value ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        locale: const Locale('sv', 'SE'),
      );
      if (date == null) return;

      if (!context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(target.value ?? DateTime.now()),
      );
      if (time == null) return;

      target.value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    String formatPickedDateTime(DateTime? dt) {
      if (dt == null) return 'Välj datum & tid';
      final d =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final t =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d $t';
    }

    void showError(String message) {
      final context = contextRef.value;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }

    Future<void> savePost() async {
      if (titleController.text.trim().isEmpty) return;
      if (htmlIsEmpty(descriptionHtml)) return;

      // When adding to the calendar, both times are required and the end must
      // be after the start.
      if (addToCalendar.value) {
        if (startDate.value == null || endDate.value == null) {
          showError('Ange start- och sluttid för kalendern.');
          return;
        }
        if (!endDate.value!.isAfter(startDate.value!)) {
          showError('Sluttid måste vara efter starttid.');
          return;
        }
      }

      final startIso = addToCalendar.value
          ? startDate.value!.toUtc().toIso8601String()
          : null;
      final endIso = addToCalendar.value
          ? endDate.value!.toUtc().toIso8601String()
          : null;

      loading.value = true;
      final success = isEdit
          ? await postsStore.updatePost(
              id: postId!,
              title: titleController.text.trim(),
              description: descriptionHtml,
              commentsAllowed: commentsAllowed.value,
              sendPushNotification: sendPushNotification.value,
              addToCalendar: addToCalendar.value,
              startAt: startIso,
              endAt: endIso,
            )
          : await postsStore.createPost(
              title: titleController.text.trim(),
              description: descriptionHtml,
              commentsAllowed: commentsAllowed.value,
              sendPushNotification: sendPushNotification.value,
              addToCalendar: addToCalendar.value,
              startAt: startIso,
              endAt: endIso,
            );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Inlägg uppdaterat!' : 'Inlägg skapat!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Kunde inte uppdatera inlägg.'
                    : 'Kunde inte skapa inlägg.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    return (context) => GradientScaffold(
      title: isEdit ? 'Redigera inlägg' : 'Skapa inlägg',
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
              title: const Text('Skicka push-notifikation till medlemmar'),
              value: sendPushNotification.value,
              onChanged: (v) => sendPushNotification.value = v,
            ),
            SwitchListTile(
              title: const Text('Lägg till i kalender'),
              value: addToCalendar.value,
              onChanged: (v) => addToCalendar.value = v,
            ),
            if (addToCalendar.value) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ange start- och sluttid för kalendern',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Starttid',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => pickDateTime(context, startDate),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(formatPickedDateTime(startDate.value)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sluttid',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => pickDateTime(context, endDate),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(formatPickedDateTime(endDate.value)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  : Text(isEdit ? 'Spara ändringar' : 'Skapa inlägg'),
            ),
          ],
        ),
      ),
    );
  }
}
