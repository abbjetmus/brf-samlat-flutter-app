import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import 'package:http/http.dart' as http;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class IssuesStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  IssuesStore(this._pb, this._authStore);

  final _issuesList = ref<List<IssuesViewRecord>>([]);
  final _currentIssue = ref<IssuesRecord?>(null);
  final _comments = ref<List<IssueCommentsRecord>>([]);
  final _loading = ref<bool>(false);
  final _showResolved = ref<bool>(false);

  Ref<List<IssuesViewRecord>> get issuesList => _issuesList;
  Ref<IssuesRecord?> get currentIssue => _currentIssue;
  Ref<List<IssueCommentsRecord>> get comments => _comments;
  Ref<bool> get loading => _loading;
  Ref<bool> get showResolved => _showResolved;

  Future<bool> getAllIssues() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      String filter = 'association="$assocId"';
      if (!_showResolved.value) {
        filter += ' && is_resolved=false';
      }

      final records = await _pb.collection(Collections.issuesView).getList(
        page: 1,
        perPage: 100,
        filter: filter,
        sort: '-created',
      );
      _issuesList.value = records.items
          .map((r) => IssuesViewRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error fetching issues: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  void toggleShowResolved() {
    _showResolved.value = !_showResolved.value;
    getAllIssues();
  }

  Future<bool> getIssue(String id) async {
    _loading.value = true;
    try {
      final record = await _pb
          .collection(Collections.issues)
          .getOne(id, expand: 'assigned_to,reported_by,residence');
      _currentIssue.value = IssuesRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error fetching issue: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getComments(String issueId) async {
    try {
      final records = await _pb.collection(Collections.issueComments).getList(
        page: 1,
        perPage: 100,
        filter: 'issue="$issueId"',
        sort: '-created',
        expand: 'user',
      );
      _comments.value = records.items
          .map((r) => IssueCommentsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error fetching comments: $e');
      return false;
    }
  }

  Future<bool> createIssue({
    required String title,
    required String description,
    String type = 'Felanmälan',
    String? assignedTo,
    bool commentsAllowed = true,
    bool consentToMasterKey = false,
    List<File>? attachments,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';
      final residenceId = _authStore.residence.value?.id;

      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'type': type,
        'association': assocId,
        'reported_by': userId,
        'comments_allowed': commentsAllowed,
        'consent_to_master_key': consentToMasterKey,
        'is_resolved': false,
      };

      if (assignedTo != null) body['assigned_to'] = assignedTo;
      if (residenceId != null) body['residence'] = residenceId;

      final files = <http.MultipartFile>[];
      if (attachments != null) {
        for (final file in attachments) {
          final bytes = await file.readAsBytes();
          files.add(http.MultipartFile.fromBytes(
            'attachments',
            bytes,
            filename: file.path.split('/').last,
          ));
        }
      }

      await _pb.collection(Collections.issues).create(
        body: body,
        files: files,
      );

      await getAllIssues();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error creating issue: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> resolveIssue(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.issues).update(id, body: {
        'is_resolved': true,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      });
      await getIssue(id);
      await getAllIssues();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error resolving issue: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> unresolveIssue(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.issues).update(id, body: {
        'is_resolved': false,
        'resolved_at': '',
      });
      await getIssue(id);
      await getAllIssues();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error unresolving issue: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteIssue(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.issues).delete(id);
      await getAllIssues();
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error deleting issue: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> addComment(String issueId, String comment) async {
    try {
      final userId = _authStore.currentUser.value?.id ?? '';
      await _pb.collection(Collections.issueComments).create(body: {
        'comment': comment,
        'issue': issueId,
        'user': userId,
      });
      await getComments(issueId);
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error adding comment: $e');
      return false;
    }
  }

  Future<bool> updateComment(String commentId, String comment, String issueId) async {
    try {
      await _pb.collection(Collections.issueComments).update(
        commentId,
        body: {'comment': comment},
      );
      await getComments(issueId);
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error updating comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(String commentId, String issueId) async {
    try {
      await _pb.collection(Collections.issueComments).delete(commentId);
      await getComments(issueId);
      return true;
    } catch (e) {
      debugPrint('IssuesStore: Error deleting comment: $e');
      return false;
    }
  }
}
