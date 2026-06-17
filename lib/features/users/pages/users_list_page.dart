import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/search_field.dart';

class UsersListPage extends CompositionWidget {
  static const String path = '/users';

  const UsersListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      usersStore.getUsers();
      usersStore.getInvitations();
    });

    return (context) {
      final users = usersStore.users.value;
      final invitations = usersStore.invitations.value;
      final loading = usersStore.loading.value;
      final userRoleTypes = authStore.userRoleTypes.value;

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
                    loading && users.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : users.isEmpty
                        ? const Center(child: Text('Inga användare.'))
                        : filteredUsers.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : RefreshIndicator(
                            onRefresh: () => usersStore.getUsers(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredUsers.length,
                              separatorBuilder: (_, __) =>
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
                              separatorBuilder: (_, __) =>
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
