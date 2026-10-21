import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/community_post_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _url(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse('${ApiConfig.baseUrl}/community$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return base.replace(queryParameters: queryParams);
    }
    return base;
  }

  /// Safe response parser that intercepts HTML 404/502/503 error pages
  /// and prevents FormatException on jsonDecode.
  Map<String, dynamic> _parseResponse(
    http.Response response, {
    String defaultErrorMessage = 'Request failed',
  }) {
    if (response.statusCode == 404) {
      return {
        'success': false,
        'message':
            'Community API is currently deploying on the server (404). Please wait a moment and pull down to refresh.',
      };
    }
    if (response.statusCode == 502 || response.statusCode == 503) {
      return {
        'success': false,
        'message':
            'Backend server is waking up (${response.statusCode}). Please wait 10 seconds and pull to refresh.',
      };
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': false, 'message': defaultErrorMessage};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Unexpected response from server (${response.statusCode}). Please ensure the latest backend is deployed.',
      };
    }
  }

  // ── Feed & Posts ───────────────────────────────────────────────────────────

  /// Fetch paginated community posts with category and sort filters.
  Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 15,
    String? category,
    String sort = 'latest',
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final headers = await _headers();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
      };

      if (category != null && category.isNotEmpty && category != 'ALL') {
        queryParams['category'] = category;
      }
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
        queryParams['radiusKm'] = radiusKm.toString();
      }

      final response = await http
          .get(_url('/posts', queryParams), headers: headers)
          .timeout(const Duration(seconds: 15));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to load community feed.');

      if (response.statusCode == 200 && data['success'] == true) {
        final List<CommunityPost> posts = (data['posts'] as List? ?? [])
            .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
            .toList();

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        return {
          'success': true,
          'posts': posts,
          'page': pagination['page'] ?? page,
          'totalPages': pagination['totalPages'] ?? 1,
          'total': pagination['total'] ?? posts.length,
          'hasMore': pagination['hasMore'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load community feed (${response.statusCode}).',
          'posts': <CommunityPost>[],
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Please pull down to refresh.', 'posts': <CommunityPost>[]};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'posts': <CommunityPost>[]};
    }
  }

  /// Fetch single post details with comments.
  Future<Map<String, dynamic>> getPostById(String id) async {
    try {
      final headers = await _headers();
      final response = await http
          .get(_url('/posts/$id'), headers: headers)
          .timeout(const Duration(seconds: 12));

      final data = _parseResponse(response, defaultErrorMessage: 'Post not found.');

      if (response.statusCode == 200 && data['success'] == true && data['post'] != null) {
        return {
          'success': true,
          'post': CommunityPost.fromJson(data['post'] as Map<String, dynamic>),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Post not found.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error loading post: $e'};
    }
  }

  /// Create a new community safety report.
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String description,
    required String category,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to report a safety concern.'};
      }

      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'category': category,
      };
      if (locationName != null && locationName.isNotEmpty) {
        body['location_name'] = locationName;
      }
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await http
          .post(_url('/posts'), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to publish report.');

      if (response.statusCode == 201 && data['success'] == true && data['post'] != null) {
        return {
          'success': true,
          'post': CommunityPost.fromJson(data['post'] as Map<String, dynamic>),
          'message': data['message'] ?? 'Report published successfully.',
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to publish report (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit report: $e'};
    }
  }

  /// Update an existing post (author only).
  Future<Map<String, dynamic>> updatePost({
    required String id,
    String? title,
    String? description,
    String? category,
  }) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to update this post.'};
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;

      final response = await http
          .patch(_url('/posts/$id'), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to update post.');

      if (response.statusCode == 200 && data['success'] == true && data['post'] != null) {
        return {
          'success': true,
          'post': CommunityPost.fromJson(data['post'] as Map<String, dynamic>),
          'message': data['message'] ?? 'Post updated successfully.',
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update post (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error updating post: $e'};
    }
  }

  /// Soft delete author's own post.
  Future<Map<String, dynamic>> deletePost(String id) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to delete this post.'};
      }

      final response = await http
          .delete(_url('/posts/$id'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to delete post.');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Post deleted.'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete post (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error deleting post: $e'};
    }
  }

  /// Toggle upvote on a post.
  Future<Map<String, dynamic>> toggleUpvote(String id) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to vote.'};
      }

      final response = await http
          .post(_url('/posts/$id/upvote'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to update vote.');

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'upvoted': data['upvoted'] as bool? ?? false,
          'upvotesCount': data['upvotesCount'] as int? ?? 0,
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update vote (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error updating vote: $e'};
    }
  }

  /// Fetch comments for a post.
  Future<Map<String, dynamic>> getComments(String postId, {int page = 1, int limit = 50}) async {
    try {
      final headers = await _headers();
      final response = await http
          .get(_url('/posts/$postId/comments', {'page': page.toString(), 'limit': limit.toString()}), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to load comments.');

      if (response.statusCode == 200 && data['success'] == true) {
        final List<CommunityComment> comments = (data['comments'] as List? ?? [])
            .map((c) => CommunityComment.fromJson(c as Map<String, dynamic>))
            .toList();

        return {'success': true, 'comments': comments};
      } else {
        return {'success': false, 'comments': <CommunityComment>[], 'message': data['message'] ?? 'Failed to load comments.'};
      }
    } catch (e) {
      return {'success': false, 'comments': <CommunityComment>[], 'message': 'Error: $e'};
    }
  }

  /// Add a comment to a post.
  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to comment.'};
      }

      final response = await http
          .post(
            _url('/posts/$postId/comments'),
            headers: headers,
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to add comment.');

      if (response.statusCode == 201 && data['success'] == true && data['comment'] != null) {
        return {
          'success': true,
          'comment': CommunityComment.fromJson(data['comment'] as Map<String, dynamic>),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to add comment (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error adding comment: $e'};
    }
  }

  /// Delete author's own comment.
  Future<Map<String, dynamic>> deleteComment(String postId, String commentId) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to delete this comment.'};
      }

      final response = await http
          .delete(_url('/posts/$postId/comments/$commentId'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to delete comment.');
      return {'success': response.statusCode == 200 && data['success'] == true, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error deleting comment: $e'};
    }
  }

  /// Report a post for inappropriate or dangerous content.
  Future<Map<String, dynamic>> reportPost(String postId, {required String reason, String? details}) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'message': 'Please log in to submit a report.'};
      }

      final body = <String, dynamic>{'reason': reason};
      if (details != null && details.isNotEmpty) body['details'] = details;

      final response = await http
          .post(
            _url('/posts/$postId/report'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to submit report.');

      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? 'Report submitted.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error submitting report: $e'};
    }
  }

  /// List authenticated user's own posts.
  Future<Map<String, dynamic>> getMyPosts({int page = 1, int limit = 20}) async {
    try {
      final headers = await _headers(requireAuth: true);
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'posts': <CommunityPost>[], 'message': 'Please log in.'};
      }

      final response = await http
          .get(_url('/my-posts', {'page': page.toString(), 'limit': limit.toString()}), headers: headers)
          .timeout(const Duration(seconds: 12));

      final data = _parseResponse(response, defaultErrorMessage: 'Failed to load your posts.');

      if (response.statusCode == 200 && data['success'] == true) {
        final List<CommunityPost> posts = (data['posts'] as List? ?? [])
            .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
            .toList();

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        return {
          'success': true,
          'posts': posts,
          'page': pagination['page'] ?? page,
          'totalPages': pagination['totalPages'] ?? 1,
          'total': pagination['total'] ?? posts.length,
          'hasMore': pagination['hasMore'] ?? false,
        };
      } else {
        return {'success': false, 'posts': <CommunityPost>[], 'message': data['message'] ?? 'Failed to load posts (${response.statusCode}).'};
      }
    } catch (e) {
      return {'success': false, 'posts': <CommunityPost>[], 'message': 'Error: $e'};
    }
  }
}
