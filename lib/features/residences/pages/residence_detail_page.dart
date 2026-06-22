import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../issues/pages/issue_detail_page.dart';
import '../../issues/pages/create_issue_page.dart';
import 'create_residence_page.dart';

class ResidenceDetailPage extends CompositionWidget {
  static const String path = '/residences/detail';

  final String residenceId;

  const ResidenceDetailPage({super.key, required this.residenceId});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();
    final associationUsers = ref<List<UsersRecord>>([]);

    onMounted(() async {
      residencesStore.getResidence(residenceId);
      residencesStore.getResidenceIssues(residenceId);
      associationUsers.value = await usersStore.getAllAssociationUsers();
    });

    return (context) {
      final residence = residencesStore.currentResidence.value;
      final issues = residencesStore.residenceIssues.value;
      final loading = residencesStore.loading.value;
      final canUpdate = authStore.hasPermission(
        'residences',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'residences',
        CrudOperation.delete,
      );
      // Residence issues are scoped to the residence's own tenants: only the
      // assigned residents (and admins) may even see the "Ärenden" tab. Creating
      // is admin-only by default (residence_issues create — members are read-only).
      final currentUserId = authStore.currentUser.value?.id;
      final canCreateIssue = authStore.hasPermission(
        'residence_issues',
        CrudOperation.create,
      );

      if (loading && residence == null) {
        return const GradientScaffold(
          title: 'Bostad',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (residence == null) {
        return const GradientScaffold(
          title: 'Bostad',
          body: Center(child: Text('Bostad hittades inte.')),
        );
      }

      // The "Ärenden" tab is residence-scoped: only the residence's assigned
      // tenants (with residence_issues read) and admins may see it. Driven by the
      // permission so granting residents more rights later just works.
      final isResident =
          currentUserId != null && residence.users.contains(currentUserId);
      final canSeeIssues =
          authStore.isAdmin.value ||
          (isResident &&
              authStore.hasPermission(
                'residence_issues',
                CrudOperation.read,
              ));

      return DefaultTabController(
        length: canSeeIssues ? 2 : 1,
        child: GradientScaffold(
          title: residence.streetAddress,
          actions: [
            if (canUpdate || canDelete)
              EntityActionMenu.header(
                actions: [
                  if (canUpdate)
                    EntityAction.update(() {
                      context.push(
                        '${CreateResidencePage.editPath}/${residence.id}',
                      );
                    }),
                  if (canDelete)
                    EntityAction.delete(() async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Radera bostad',
                        message:
                            'Är du säker på att du vill radera denna bostad?',
                        okLabel: 'Radera',
                        okColor: Colors.red,
                      );
                      if (confirmed) {
                        await residencesStore.deleteResidence(residence.id);
                        final ctx = contextRef.value;
                        if (ctx != null && ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      }
                    }),
                ],
              ),
          ],
          body: Column(
            children: [
              TabBar(
                tabs: [
                  const Tab(text: 'Information'),
                  if (canSeeIssues) const Tab(text: 'Ärenden'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Info tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            residence.streetAddress,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          _infoRow(
                            Icons.location_on,
                            '${residence.streetAddress}, ${residence.zipCode} ${residence.locality}',
                          ),
                          _infoRow(Icons.home, residence.residenceType),
                          if (residence.moveInDate != null &&
                              residence.moveInDate!.isNotEmpty)
                            _infoRow(
                              Icons.calendar_today,
                              'Inflyttningsdatum: ${residence.moveInDate}',
                            ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Boende',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (residence.users.isEmpty)
                            Text(
                              'Inga boende tilldelade.',
                              style: TextStyle(color: Colors.grey[600]),
                            )
                          else
                            ...residence.users.map((userId) {
                              final user = associationUsers.value
                                  .where((u) => u.id == userId)
                                  .firstOrNull;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  user?.name.isNotEmpty == true
                                      ? user!.name
                                      : (user?.email ?? 'Okänd användare'),
                                ),
                                subtitle: user?.email != null
                                    ? Text(user!.email!)
                                    : null,
                              );
                            }),
                        ],
                      ),
                    ),

                    // Issues tab (only present when the user may see it)
                    if (canSeeIssues)
                      Column(
                        children: [
                          if (canCreateIssue)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await context.push(
                                    '${CreateIssuePage.path}'
                                    '?residenceId=${residence.id}',
                                  );
                                  await residencesStore.getResidenceIssues(
                                    residenceId,
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Skapa ny'),
                              ),
                            ),
                          ),
                        Expanded(
                          child: issues.isEmpty
                              ? const Center(
                                  child: Text('Inga ärenden för denna bostad.'),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: issues.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, index) {
                                    final issue = issues[index];
                                    return Card(
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        onTap: () => context.push(
                                          '${IssueDetailPage.path}/${issue.id}',
                                        ),
                                        leading: Icon(
                                          issue.isResolved
                                              ? Icons.check_circle
                                              : Icons.error_outline,
                                          color: issue.isResolved
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        title: Text(
                                          issue.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          issue.isResolved ? 'Löst' : 'Olöst',
                                          style: TextStyle(
                                            color: issue.isResolved
                                                ? Colors.green
                                                : Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}

Widget _infoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
