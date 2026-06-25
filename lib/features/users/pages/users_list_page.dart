import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';

class UsersListPage extends CompositionWidget {
  static const String path = '/users';

  const UsersListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');
    final contextRef = useContext();

    onMounted(() {
      usersStore.getUsers();
      usersStore.getInvitations();
    });

    Future<void> showInviteDialog() async {
      final context = contextRef.value;
      if (context == null) return;

      final nameController = TextEditingController();
      final emailController = TextEditingController();
      final phoneController = TextEditingController();

      final roleTypes = authStore.userRoleTypes.value;

      // Default to the "user" role when present (its displayName, e.g.
      // "Användare", comes from the user_role_types collection).
      String? selectedRoleTypeId = roleTypes
          .where((r) => r.name == 'user')
          .map((r) => r.id)
          .firstOrNull;

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Bjud in användare'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Namn',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-post',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (valfritt)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  if (roleTypes.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoleTypeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Roll',
                        border: OutlineInputBorder(),
                      ),
                      items: roleTypes
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                r.displayName.isNotEmpty
                                    ? r.displayName
                                    : r.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedRoleTypeId = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Bjud in'),
              ),
            ],
          ),
        ),
      );

      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();

      if (result != true || name.isEmpty || email.isEmpty) return;

      final roleTypeId =
          selectedRoleTypeId ?? (roleTypes.isNotEmpty ? roleTypes.first.id : '');

      final success = await usersStore.sendInvitation(
        name: name,
        email: email,
        phone: phone.isEmpty ? null : phone,
        userRoleType: roleTypeId,
      );

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(success ? 'Inbjudan skickad.' : 'Kunde inte skicka inbjudan.'),
        ),
      );
    }

    Future<void> resendInvitation(String id) async {
      final success = await usersStore.resendInvitation(id);
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Inbjudan skickad igen.' : 'Kunde inte skicka inbjudan.',
          ),
        ),
      );
    }

    return (context) {
      final users = usersStore.users.value;
      final invitations = usersStore.invitations.value;
      final loading = usersStore.loading.value;
      final listLoading = usersStore.listLoading.value;
      final loadingMore = usersStore.loadingMore.value;
      final hasMore = usersStore.hasMore.value;
      final userRoleTypes = authStore.userRoleTypes.value;
      final isAdmin = authStore.isAdmin.value;

      String getRoleTypeName(String roleTypeId) {
        final roleType = userRoleTypes
            .where((r) => r.id == roleTypeId)
            .firstOrNull;
        return roleType?.name ?? '';
      }

      final query = searchQuery.value.trim().toLowerCase();
      final filteredUsers = query.isEmpty
          ? users
          : users
                .where(
                  (u) =>
                      u.name.toLowerCase().contains(query) ||
                      (u.email ?? '').toLowerCase().contains(query),
                )
                .toList();
      final filteredInvitations = query.isEmpty
          ? invitations
          : invitations
                .where(
                  (inv) =>
                      inv.name.toLowerCase().contains(query) ||
                      inv.email.toLowerCase().contains(query),
                )
                .toList();

      return DefaultTabController(
        length: 2,
        child: GradientScaffold(
          title: 'Användare',
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: showInviteDialog,
                  child: const Icon(Icons.person_add_outlined),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchField(
                  hintText: 'Sök användare...',
                  onChanged: (v) => searchQuery.value = v,
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Användare'),
                  Tab(text: 'Inbjudningar'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Users tab
                    listLoading && users.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : users.isEmpty
                        ? const Center(child: Text('Inga användare.'))
                        : filteredUsers.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredUsers.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: usersStore.fetchNextUsers,
                            onRefresh: usersStore.getUsers,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final roleTypeName = getRoleTypeName(
                                user.userRoleType,
                              );
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (user.email != null &&
                                          user.email!.isNotEmpty)
                                        Text(
                                          user.email!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (roleTypeName.isNotEmpty)
                                        Text(
                                          roleTypeName,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                    // Invitations tab
                    loading && invitations.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : invitations.isEmpty
                        ? const Center(child: Text('Inga inbjudningar.'))
                        : filteredInvitations.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : RefreshIndicator(
                            onRefresh: () => usersStore.getInvitations(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredInvitations.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final invitation = filteredInvitations[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    leading: const Icon(Icons.mail_outline),
                                    title: Text(
                                      invitation.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          invitation.email,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          invitation.invitationStatus,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: isAdmin
                                        ? EntityActionMenu(
                                            actions: [
                                              if (invitation.invitationStatus !=
                                                  'Aktiverad')
                                                EntityAction(
                                                  icon: Icons.send_outlined,
                                                  label: 'Skicka igen',
                                                  onSelected: () =>
                                                      resendInvitation(
                                                        invitation.id,
                                                      ),
                                                ),
                                              EntityAction.delete(() async {
                                                await usersStore.deleteInvitation(
                                                  invitation.id,
                                                );
                                              }),
                                            ],
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
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
