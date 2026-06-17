import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class FoldersPage extends CompositionWidget {
  static const String path = '/folders';

  const FoldersPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final foldersStore = inject(foldersStoreKey);
    final authStore = inject(authStoreKey);
    final folderHistory = ref<List<String>>([]);

    onMounted(() async {
      final success = await foldersStore.getRootFolder();
      if (success) {
        final rootId = foldersStore.rootFolder.value?.id;
        if (rootId != null) {
          await foldersStore.getChildren(rootId);
        }
      }
    });

    Future<void> navigateToFolder(String folderId) async {
      final currentId = foldersStore.currentFolder.value?.id;
      if (currentId != null) {
        folderHistory.value = [...folderHistory.value, currentId];
      }
      await foldersStore.getFolder(folderId);
      await foldersStore.getChildren(folderId);
    }

    Future<void> navigateBack() async {
      final history = folderHistory.value;
      if (history.isEmpty) return;

      final parentId = history.last;
      folderHistory.value = history.sublist(0, history.length - 1);
      await foldersStore.getFolder(parentId);
      await foldersStore.getChildren(parentId);
    }

    Future<void> showCreateFolderDialog(BuildContext context) async {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ny mapp'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mappnamn',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Skapa'),
            ),
          ],
        ),
      );
      controller.dispose();

      if (name != null && name.isNotEmpty) {
        final parentId = foldersStore.currentFolder.value?.id;
        if (parentId != null) {
          await foldersStore.createFolder(name: name, parentId: parentId);
        }
      }
    }

    return (context) {
      final children = foldersStore.children.value;
      final loading = foldersStore.loading.value;
      final currentFolder = foldersStore.currentFolder.value;
      final rootFolder = foldersStore.rootFolder.value;
      final isAtRoot = currentFolder?.id == rootFolder?.id;
      final canCreate = authStore.hasPermission('folders_and_files', CrudOperation.create);
      final canDelete = authStore.hasPermission('folders_and_files', CrudOperation.delete);

      return GradientScaffold(
        title: isAtRoot ? 'Dokument & Filer' : (currentFolder?.name ?? 'Dokument & Filer'),
        showBack: isAtRoot ? null : false,
        actions: [
          if (!isAtRoot)
            HeaderIconButton(
              icon: Icons.arrow_back,
              onPressed: navigateBack,
            ),
        ],
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => showCreateFolderDialog(context),
                child: const Icon(Icons.create_new_folder_outlined),
              )
            : null,
        body: loading && children.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : children.isEmpty
                ? const Center(child: Text('Inga filer eller mappar.'))
                : RefreshIndicator(
                    onRefresh: () async {
                      final id = currentFolder?.id;
                      if (id != null) {
                        await foldersStore.getChildren(id);
                      }
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = children[index];
                        final isFolder = item.files.isEmpty;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: Icon(
                              isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                              color: isFolder ? AppTheme.primaryColor : Colors.grey[600],
                            ),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: isFolder
                                ? () => navigateToFolder(item.id)
                                : null,
                            onLongPress: canDelete
                                ? () async {
                                    final confirmed = await showConfirmDialog(
                                      context,
                                      title: 'Radera mapp',
                                      message: 'Är du säker på att du vill radera "${item.name}"?',
                                      okLabel: 'Radera',
                                      okColor: Colors.red,
                                    );
                                    if (confirmed) {
                                      await foldersStore.deleteFolder(item.id);
                                    }
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
