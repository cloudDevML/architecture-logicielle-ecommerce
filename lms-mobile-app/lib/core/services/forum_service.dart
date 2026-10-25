import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'auth_service.dart';

class ForumService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getAllThreads() async {
    final response = await http.get(
      Uri.parse(ApiConstants.forumThreads),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load forum threads');
    }
  }

  Future<List<dynamic>> getThreadsByModule(int moduleId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.moduleForum}/$moduleId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load forum threads for module');
    }
  }

  Future<Map<String, dynamic>> getThreadDetail(int threadId, {String? username}) async {
    String url = '${ApiConstants.forumThread}/$threadId';
    if (username != null) {
      url += '?username=$username';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load thread details');
    }
  }

  Future<Map<String, dynamic>> createThread(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forumThread),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create thread');
    }
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forumPost),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to create post');
    }
  }

  Future<void> upvoteThread(int threadId, String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.forumThread}/$threadId/upvote/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upvote thread');
    }
  }

  Future<void> removeUpvoteThread(int threadId, String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.forumThread}/$threadId/upvote/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove upvote');
    }
  }

  Future<void> upvotePost(int postId, String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.forumPost}/$postId/upvote/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upvote post');
    }
  }

  Future<void> removeUpvotePost(int postId, String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.forumPost}/$postId/upvote/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove upvote from post');
    }
  }

  Future<void> markAsSolution(int threadId, int postId) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.forumThread}/$threadId/solution/$postId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark as solution');
    }
  }
}
