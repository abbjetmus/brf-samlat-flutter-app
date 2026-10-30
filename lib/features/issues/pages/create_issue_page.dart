import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_text_editor.dart';

class CreateIssuePage extends CompositionWidget {
  static const String path = '/issues/create';
  static const String editPath = '/issues/edit';

  /// When non-null the page edits the existing issue instead of creating one.
  final String? issueId;

  /// When non-null a newly created issue is tied to this residence (e.g.
  /// created from a residence's page). Otherwise the reporter chooses between
  /// their own residence and a shared issue.
  final String? residenceId;

  const CreateIssuePage({super.key, this.issueId, this.residenceId});

  @override
  Widget Function(BuildContext) setup() {
    final issuesStore = inject(issuesStoreKey);
    final authStore = inject(authStoreKey);
    final isEdit = issueId != null;
    final existing = (isEdit && issuesStore.currentIssue.value?.id == issueId)
        ? issuesStore.currentIssue.value
        : null;

    final (titleController, _, __) = useTextEditingController();
    final issueType = ref<String>(existing?.type ?? 'Felanmälan');
    final commentsAllowed = ref(existing?.commentsAllowed ?? true);
    final consentToMasterKey = ref(existing?.consentToMasterKey ?? false);
    final loading = ref(false);
    final contextRef = useContext();

    // From the issues list the issue either concerns the reporter's own
    // residence (only its residents and admins can see it) or is shared with
    // the whole association. Offer the choice only when both are allowed;
    // otherwise the one permitted kind is used.
    final ownResidenceId = authStore.residence.value?.id;
    final canCreateShared = authStore.hasPermission(
      'issues',
      CrudOperation.create,
    );
    final canCreateForOwnResidence =
        ownResidenceId != null &&
        authStore.hasPermission('residence_issues', CrudOperation.create);
    final choosesResidence = !isEdit && residenceId == null;
    final showResidenceChoice =
        choosesResidence && canCreateShared && canCreateForOwnResidence;
    final forOwnResidence = ref(choosesResidence && canCreateForOwnResidence);

    // Description is rich text (HTML). Hold the current HTML and only mount the
    // editor once the initial content is known (it can load late on deep-links).
    var descriptionHtml = existing?.description ?? '';
    final descriptionReady = ref(!isEdit || existing != null);

    if (existing != null) {
      titleController.text = existing.title;
    }

    onMounted(() async {
      // Cover deep-links / stale state where the issue isn't loaded yet.
      if (isEdit && existing == null) {
        await issuesStore.getIssue(issueId!);
        final issue = issuesStore.currentIssue.value;
        if (issue != null && issue.id == issueId) {
          titleController.text = issue.title;
          descriptionHtml = issue.description;
          issueType.value = issue.type ?? 'Felanmälan';
          commentsAllowed.value = issue.commentsAllowed;
          consentToMasterKey.value = issue.consentToMasterKey ?? false;
        }
        descriptionReady.value = true;
      }
    });

    Future<void> saveIssue() async {
      if (titleController.text.trim().isEmpty) return;
      if (htmlIsEmpty(descriptionHtml)) return;

      loading.value = true;
      final failure = isEdit
          ? await issuesStore.updateIssue(
              id: issueId!,
              title: titleController.text.trim(),
              description: descriptionHtml,
              type: issueType.value,
              commentsAllowed: commentsAllowed.value,
              consentToMasterKey: consentToMasterKey.value,
            )
          : await issuesStore.createIssue(
              title: titleController.text.trim(),
              description: descriptionHtml,
              type: issueType.value,
              commentsAllowed: commentsAllowed.value,
              consentToMasterKey: consentToMasterKey.value,
              residenceId:
                  residenceId ??
                  (forOwnResidence.value ? ownResidenceId : null),
            );
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        if (failure == null) {
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
            SnackBar(content: Text(failure), backgroundColor: Colors.red),
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
                  DropdownMenuItem(
                    value: 'Felanmälan',
                    child: Text('Felanmälan'),
                  ),
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
              if (showResidenceChoice)
                SwitchListTile(
                  title: const Text('Gäller min bostad'),
                  subtitle: Text(
                    forOwnResidence.value
                        ? 'Syns bara för bostadens boende och administratörer.'
                        : 'Syns för alla i föreningen.',
                  ),
                  value: forOwnResidence.value,
                  onChanged: (v) => forOwnResidence.value = v,
                ),
              SwitchListTile(
                title: const Text('Tillåt kommentarer'),
                value: commentsAllowed.value,
                onChanged: (v) => commentsAllowed.value = v,
              ),
              SwitchListTile(
                title: const Text('Samtycke till huvudnyckel'),
                subtitle: const Text(
                  'Ge tillgång med huvudnyckel till bostaden',
                ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
