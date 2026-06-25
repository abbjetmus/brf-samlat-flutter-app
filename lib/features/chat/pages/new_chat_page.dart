import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import 'chat_room_page.dart';

/// Pick one or more association members and start a DM (single user) or a named
/// group chat (multiple users or the group toggle).
class NewChatPage extends CompositionWidget {
  static const String path = '/chat/new';

  const NewChatPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final chatStore = inject(chatStoreKey);

    final selected = ref<Set<String>>({});
    final isGroup = ref<bool>(false);
    final groupName = ref<String>('');
    final query = ref<String>('');
    final creating = ref<bool>(false);

    // Full association list so every member is shown up front; the search box
    // only filters this list client-side.
    final allUsers = ref<List<UsersRecord>>([]);

    onMounted(() async {
      allUsers.value = await usersStore.getAllAssociationUsers();
    });

    Future<void> create(BuildContext context) async {
      final ids = selected.value.toList();
      if (ids.isEmpty) return;
      final group = isGroup.value || ids.length > 1;
      if (group && groupName.value.trim().isEmpty) return;
      creating.value = true;
      final roomId = await chatStore.createRoom(
        ids,
        name: group ? groupName.value.trim() : null,
        isGroup: group,
      );
      creating.value = false;
      if (roomId == null || !context.mounted) return;
      final title = group
          ? groupName.value.trim()
          : (allUsers.value
                  .where((u) => u.id == ids.first)
                  .firstOrNull
                  ?.name ??
              'Chatt');
      context.pushReplacement('${ChatRoomPage.path}/$roomId', extra: title);
    }

    return (context) {
      final meId = authStore.currentUser.value?.id;
      final q = query.value.toLowerCase();
      final users = allUsers.value
          .where((u) => u.id != meId)
          .where((u) =>
              q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              (u.email ?? '').toLowerCase().contains(q))
          .toList();
      final group = isGroup.value || selected.value.length > 1;
      final canCreate = selected.value.isNotEmpty &&
          (!group || groupName.value.trim().isNotEmpty) &&
          !creating.value;

      return GradientScaffold(
        title: 'Ny konversation',
        body: Column(
          children: [
            SwitchListTile(
              title: const Text('Gruppchatt'),
              value: isGroup.value,
              onChanged: (v) => isGroup.value = v,
            ),
            if (group)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Gruppnamn',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => groupName.value = v,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Sök användare',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => query.value = v,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final UsersRecord u = users[index];
                  final isSelected = selected.value.contains(u.id);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(u.name.isNotEmpty ? u.name : (u.email ?? '')),
                    subtitle: u.email != null ? Text(u.email!) : null,
                    onChanged: (_) {
                      final next = {...selected.value};
                      if (isSelected) {
                        next.remove(u.id);
                      } else {
                        next.add(u.id);
                      }
                      selected.value = next;
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: canCreate ? () => create(context) : null,
          backgroundColor: canCreate ? null : Colors.grey,
          icon: creating.value
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('Starta chatt'),
        ),
      );
    };
  }
}
