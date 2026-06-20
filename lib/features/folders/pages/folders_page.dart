import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
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
      final name = await showDialog<String>(
        context: context,
        builder: (context) => const _NewFolderDialog(),
      );

      if (name != null && name.isNotEmpty) {
        final parentId = foldersStore.currentFolder.value?.id;
        if (parentId != null) {
          await foldersStore.createFolder(name: name, parentId: parentId);
        }
      }
    }

    Future<void> pickAndUploadFiles(BuildContext context) async {
      final folderId = foldersStore.currentFolder.value?.id;
      if (folderId == null) return;

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final files = <http.MultipartFile>[];
      final tooLarge = <String>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        // Reject files over the server's per-file limit up front, so the user
        // gets a clear message instead of a failed upload round-trip.
        if (f.size > kMaxUploadBytes) {
          tooLarge.add('${f.name} (${byteToMegabyte(f.size)} MB)');
          continue;
        }
        // The `files+` field name appends to the existing files rather than
        // replacing them (PocketBase modifier), matching the web admin.
        files.add(http.MultipartFile.fromBytes('files+', bytes, filename: f.name));
      }

      if (!context.mounted) return;

      final maxMb = byteToMegabyte(kMaxUploadBytes);
      if (tooLarge.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(tooLarge.length == 1
                ? '${tooLarge.first} är för stor. Max tillåten storlek är $maxMb MB per fil.'
                : 'Dessa filer är för stora (max $maxMb MB per fil):\n${tooLarge.join('\n')}'),
          ),
        );
      }

      if (files.isEmpty) return;

      final success = await foldersStore.uploadFiles(files, folderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${files.length} fil(er) uppladdade'
              : 'Kunde inte ladda upp filer'),
        ),
      );
    }

    Future<void> downloadFile(String fileName) async {
      final folder = foldersStore.currentFolder.value;
      if (folder == null) return;
      final url = getImageUrl(Collections.foldersAndFiles, folder.id, fileName);
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return (context) {
      final children = foldersStore.children.value;
      final loading = foldersStore.loading.value;
      final currentFolder = foldersStore.currentFolder.value;
      final rootFolder = foldersStore.rootFolder.value;
      final isAtRoot = currentFolder?.id == rootFolder?.id;
      final files = currentFolder?.files ?? const <String>[];
      final canCreate = authStore.hasPermission('folders_and_files', CrudOperation.create);
      final canDelete = authStore.hasPermission('folders_and_files', CrudOperation.delete);

      final isEmpty = children.isEmpty && files.isEmpty;

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
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'upload',
                    onPressed: () => pickAndUploadFiles(context),
                    child: const Icon(Icons.upload_file_outlined),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'newFolder',
                    onPressed: () => showCreateFolderDialog(context),
                    child: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              )
            : null,
        body: loading && isEmpty
            ? const Center(child: CircularProgressIndicator())
            : isEmpty
                ? const Center(child: Text('Inga filer eller mappar.'))
                : RefreshIndicator(
                    onRefresh: () async {
                      final id = currentFolder?.id;
                      if (id != null) {
                        await foldersStore.getFolder(id);
                        await foldersStore.getChildren(id);
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                      children: [
                        if (children.isNotEmpty) ...[
                          const _SectionLabel('Mappar'),
                          for (final folder in children)
                            _FolderTile(
                              folder: folder,
                              canDelete: canDelete,
                              onTap: () => navigateToFolder(folder.id),
                              onDelete: () async {
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Radera mapp',
                                  message:
                                      'Är du säker på att du vill radera mappen "${folder.name}" och allt innehåll?',
                                  okLabel: 'Radera',
                                  okColor: Colors.red,
                                );
                                if (confirmed) {
                                  await foldersStore.deleteFolder(folder.id);
                                }
                              },
                            ),
                        ],
                        if (files.isNotEmpty) ...[
                          const _SectionLabel('Filer'),
                          for (final fileName in files)
                            _FileTile(
                              fileName: fileName,
                              canDelete: canDelete,
                              onDownload: () => downloadFile(fileName),
                              onDelete: () async {
                                final info = parseFilename(fileName);
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Radera fil',
                                  message:
                                      'Är du säker på att du vill radera filen "${info.name}"?',
                                  okLabel: 'Radera',
                                  okColor: Colors.red,
                                );
                                if (confirmed && currentFolder != null) {
                                  await foldersStore.removeFile(currentFolder.id, fileName);
                                }
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
      );
    };
  }
}

/// `useTextEditingController` owns and auto-disposes the controller, so it is
/// torn down only after the dialog route is fully removed. Disposing a
/// controller manually right after `showDialog` returns crashes while the
/// close animation is still running ("A TextEditingController was used after
/// being disposed.").
class _NewFolderDialog extends CompositionWidget {
  const _NewFolderDialog();

  @override
  Widget Function(BuildContext) setup() {
    final (controller, _, _) = useTextEditingController();

    void submit(BuildContext context) =>
        Navigator.of(context).pop(controller.text.trim());

    return (context) => AlertDialog(
          title: const Text('Ny mapp'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mappnamn',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => submit(context),
              child: const Text('Skapa'),
            ),
          ],
        );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final FoldersAndFilesRecord folder;
  final bool canDelete;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _FolderTile({
    required this.folder,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.folder_outlined, color: AppTheme.primaryColor),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: canDelete
            ? EntityActionMenu(
                actions: [EntityAction.delete(() => onDelete())],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final String fileName;
  final bool canDelete;
  final VoidCallback onDownload;
  final Future<void> Function() onDelete;

  const _FileTile({
    required this.fileName,
    required this.canDelete,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info = parseFilename(fileName);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(info.icon, color: Colors.grey[600]),
        title: Text(
          info.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download_outlined, color: AppTheme.primaryColor),
              onPressed: onDownload,
            ),
            if (canDelete)
              EntityActionMenu(
                actions: [EntityAction.delete(() => onDelete())],
              ),
          ],
        ),
        onTap: onDownload,
      ),
    );
  }
}
