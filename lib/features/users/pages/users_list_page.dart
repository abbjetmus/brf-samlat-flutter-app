import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';

class UsersListPage extends CompositionWidget {
  static const String path = '/users';

  const UsersListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);

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
        final roleType = userRoleTypes.where((r) => r.id == roleTypeId).firstOrNull;
        return roleType?.name ?? '';
      }

      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Användare'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Användare'),
                Tab(text: 'Inbjudningar'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // Users tab
              loading && users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : users.isEmpty
                      ? const Center(child: Text('Inga användare.'))
                      : RefreshIndicator(
                          onRefresh: () => usersStore.getUsers(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final roleTypeName = getRoleTypeName(user.userRoleType);
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (user.email != null && user.email!.isNotEmpty)
                                        Text(
                                          user.email!,
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      if (roleTypeName.isNotEmpty)
                                        Text(
                                          roleTypeName,
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                      : RefreshIndicator(
                          onRefresh: () => usersStore.getInvitations(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: invitations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final invitation = invitations[index];
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invitation.email,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      Text(
                                        invitation.invitationStatus,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
      );
    };
  }
}
