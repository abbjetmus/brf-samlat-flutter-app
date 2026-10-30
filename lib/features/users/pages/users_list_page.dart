import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
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

      final roleTypes = authStore.userRoleTypes.value;
      final invite = await showDialog<_Invite>(
        context: context,
        builder: (_) => _InviteUserDialog(roleTypes: roleTypes),
      );
      if (invite == null) return;

      final failure = await usersStore.sendInvitation(
        name: invite.name,
        email: invite.email,
        phone: invite.phone.isEmpty ? null : invite.phone,
        userRoleType: invite.roleTypeId,
      );

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(failure ?? 'Inbjudan skickad.'),
          backgroundColor: failure != null ? Colors.red : null,
        ),
      );
    }

    Future<void> resendInvitation(String id) async {
      final failure = await usersStore.resendInvitation(id);
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(failure ?? 'Inbjudan skickad igen.'),
          backgroundColor: failure != null ? Colors.red : null,
        ),
      );
    }

    // The account is anonymised, not deleted (see UsersStore.deleteUser), so
    // the text says what actually happens to the person and to the history.
    Future<void> removeUser(UsersRecord user) async {
      final context = contextRef.value;
      if (context == null || !context.mounted) return;

      final confirmed = await showConfirmDialog(
        context,
        title: 'Ta bort användare?',
        message:
            '${user.name} tas bort och kan inte längre logga in. Namn, e-post, '
            'telefon och profilbild raderas, liksom notiser, inställningar och '
            'formulärsvar, och personen tas bort från sin bostad.\n\n'
            'Föreningens historik behålls — inlägg, felanmälningar och '
            'protokoll står kvar men visar "Borttagen användare" som '
            'avsändare. Åtgärden kan inte ångras.',
        okLabel: 'Ta bort',
        okColor: Colors.red,
      );
      if (!confirmed) return;

      final failure = await usersStore.deleteUser(user.id);

      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(failure ?? 'Användaren har tagits bort.'),
          backgroundColor: failure != null ? Colors.red : null,
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
      final currentUserId = authStore.currentUser.value?.id;

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
              if (isAdmin)
                const HelpTip(
                  id: 'invitations',
                  text:
                      'Tryck på + för att bjuda in en medlem. Den inbjudna får '
                      'ett mejl med en länk och väljer själv sitt lösenord. Har '
                      'länken gått ut kan du skicka om inbjudan under '
                      'Inbjudningar.',
                ),
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
                                  // Your own account is removed from Mitt
                                  // konto, which also signs you out.
                                  trailing: isAdmin && user.id != currentUserId
                                      ? EntityActionMenu(
                                          actions: [
                                            EntityAction.delete(
                                              () => removeUser(user),
                                              label: 'Ta bort',
                                            ),
                                          ],
                                        )
                                      : null,
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

typedef _Invite = ({String name, String email, String phone, String roleTypeId});

/// `useTextEditingController` owns and auto-disposes the controllers, so they
/// are torn down only after the dialog route is fully removed. Disposing them
/// manually right after `showDialog` returns crashes while the close animation
/// is still running ("A TextEditingController was used after being disposed.").
class _InviteUserDialog extends CompositionWidget {
  const _InviteUserDialog({required this.roleTypes});

  final List<UserRoleTypesRecord> roleTypes;

  @override
  Widget Function(BuildContext) setup() {
    final (nameController, name, _) = useTextEditingController();
    final (emailController, email, _) = useTextEditingController();
    final (phoneController, _, _) = useTextEditingController();

    // Default to the "user" role when present (its displayName, e.g.
    // "Användare", comes from the user_role_types collection).
    final selectedRoleTypeId = ref<String?>(
      roleTypes.where((r) => r.name == 'user').map((r) => r.id).firstOrNull ??
          roleTypes.firstOrNull?.id,
    );
    final canSubmit = computed(
      () => name.value.trim().isNotEmpty && email.value.trim().isNotEmpty,
    );

    return (context) => AlertDialog(
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
                    helperText: 'Medlemmen får ett mejl och väljer själv sitt lösenord.',
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
                    initialValue: selectedRoleTypeId.value,
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
                              r.displayName.isNotEmpty ? r.displayName : r.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => selectedRoleTypeId.value = v,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: canSubmit.value
                  ? () => Navigator.of(context).pop<_Invite>((
                        name: name.value.trim(),
                        email: email.value.trim(),
                        phone: phoneController.text.trim(),
                        roleTypeId: selectedRoleTypeId.value ?? '',
                      ))
                  : null,
              child: const Text('Bjud in'),
            ),
          ],
        );
  }
}
