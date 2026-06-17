import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import 'package:http/http.dart' as http;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class PostsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  PostsStore(this._pb, this._authStore);

  final _postsList = ref<List<PostsViewRecord>>([]);
  final _currentPost = ref<PostsRecord?>(null);
  final _comments = ref<List<PostCommentsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<PostsViewRecord>> get postsList => _postsList;
  Ref<PostsRecord?> get currentPost => _currentPost;
  Ref<List<PostCommentsRecord>> get comments => _comments;
  Ref<bool> get loading => _loading;

  Future<bool> getAllPosts() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb.collection(Collections.postsView).getList(
        page: 1,
        perPage: 100,
        filter: 'association="$assocId"',
        sort: '-created',
      );
      _postsList.value = records.items
          .map((r) => PostsViewRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error fetching posts: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getPost(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.posts).getOne(id);
      _currentPost.value = PostsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error fetching post: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getComments(String postId) async {
    try {
      final records = await _pb.collection(Collections.postComments).getList(
        page: 1,
        perPage: 100,
        filter: 'post="$postId"',
        sort: '-created',
        expand: 'user',
      );
      _comments.value = records.items
          .map((r) => PostCommentsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error fetching comments: $e');
      return false;
    }
  }

  Future<bool> createPost({
    required String title,
    required String description,
    bool commentsAllowed = true,
    bool pinAsGeneralInfo = false,
    bool addToCalendar = false,
    String? startAt,
    String? endAt,
    List<File>? attachments,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';

      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'association': assocId,
        'user': userId,
        'comments_allowed': commentsAllowed,
        'pin_as_general_info': pinAsGeneralInfo,
        'add_to_calendar': addToCalendar,
      };

      if (startAt != null) body['start_at'] = startAt;
      if (endAt != null) body['end_at'] = endAt;

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

      await _pb.collection(Collections.posts).create(
        body: body,
        files: files,
      );

      await getAllPosts();
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error creating post: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updatePost({
    required String id,
    required String title,
    required String description,
    bool? commentsAllowed,
    bool? pinAsGeneralInfo,
    bool? addToCalendar,
    String? startAt,
    String? endAt,
  }) async {
    _loading.value = true;
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
      };

      if (commentsAllowed != null) body['comments_allowed'] = commentsAllowed;
      if (pinAsGeneralInfo != null) body['pin_as_general_info'] = pinAsGeneralInfo;
      if (addToCalendar != null) body['add_to_calendar'] = addToCalendar;
      if (startAt != null) body['start_at'] = startAt;
      if (endAt != null) body['end_at'] = endAt;

      await _pb.collection(Collections.posts).update(id, body: body);
      await getAllPosts();
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error updating post: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deletePost(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.posts).delete(id);
      await getAllPosts();
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error deleting post: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> addComment(String postId, String comment) async {
    try {
      final userId = _authStore.currentUser.value?.id ?? '';
      await _pb.collection(Collections.postComments).create(body: {
        'comment': comment,
        'post': postId,
        'user': userId,
      });
      await getComments(postId);
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error adding comment: $e');
      return false;
    }
  }

  Future<bool> updateComment(String commentId, String comment, String postId) async {
    try {
      await _pb.collection(Collections.postComments).update(
        commentId,
        body: {'comment': comment},
      );
      await getComments(postId);
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error updating comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(String commentId, String postId) async {
    try {
      await _pb.collection(Collections.postComments).delete(commentId);
      await getComments(postId);
      return true;
    } catch (e) {
      debugPrint('PostsStore: Error deleting comment: $e');
      return false;
    }
  }
}
