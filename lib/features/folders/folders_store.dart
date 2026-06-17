import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class FoldersStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  FoldersStore(this._pb, this._authStore);

  final _rootFolder = ref<FoldersAndFilesRecord?>(null);
  final _currentFolder = ref<FoldersAndFilesRecord?>(null);
  final _children = ref<List<FoldersAndFilesRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<FoldersAndFilesRecord?> get rootFolder => _rootFolder;
  Ref<FoldersAndFilesRecord?> get currentFolder => _currentFolder;
  Ref<List<FoldersAndFilesRecord>> get children => _children;
  Ref<bool> get loading => _loading;

  Future<bool> getRootFolder() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final record = await _pb.collection(Collections.foldersAndFiles).getFirstListItem(
        'name="root" && association="$assocId"',
      );
      _rootFolder.value = FoldersAndFilesRecord.fromJson(record.toJson());
      _currentFolder.value = _rootFolder.value;
      return true;
    } catch (e) {
      debugPrint('FoldersStore: Error fetching root folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getFolder(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.foldersAndFiles).getOne(id);
      _currentFolder.value = FoldersAndFilesRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('FoldersStore: Error fetching folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getChildren(String parentId) async {
    _loading.value = true;
    try {
      final records = await _pb.collection(Collections.foldersAndFiles).getList(
        page: 1,
        perPage: 100,
        filter: 'parent_folder="$parentId"',
        sort: 'name',
      );
      _children.value = records.items
          .map((r) => FoldersAndFilesRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('FoldersStore: Error fetching children: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> createFolder({
    required String name,
    required String parentId,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final parentPath = _currentFolder.value?.path ?? '';
      final newPath = parentPath.isEmpty ? name : '$parentPath/$name';

      await _pb.collection(Collections.foldersAndFiles).create(body: {
        'name': name,
        'association': assocId,
        'parent_folder': parentId,
        'path': newPath,
      });

      await getChildren(parentId);
      return true;
    } catch (e) {
      debugPrint('FoldersStore: Error creating folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteFolder(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.foldersAndFiles).delete(id);
      final parentId = _currentFolder.value?.id;
      if (parentId != null) {
        await getChildren(parentId);
      }
      return true;
    } catch (e) {
      debugPrint('FoldersStore: Error deleting folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
