import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'api_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'nirbhay_jwt_token';
  static const String _userKey = 'nirbhay_user_data';

  UserModel? _cachedUser;
  String? _cachedToken;

  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final token = data['token'];
        final userJson = data['user'];
        final user = UserModel.fromJson(userJson);

        await _saveSession(token, user);
        return {'success': true, 'user': user, 'message': data['message']};
      } else {
        String errorMsg = data['message'] ?? 'Registration failed. Please try again.';
        if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          errorMsg = (data['errors'] as List).join('\n');
        }
        return {'success': false, 'message': errorMsg};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Check that your phone and PC are on the same Wi-Fi network.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server (${e.runtimeType}).',
      };
    }
  }

  /// Sign in an existing user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final userJson = data['user'];
        final user = UserModel.fromJson(userJson);

        await _saveSession(token, user);
        return {'success': true, 'user': user, 'message': data['message']};
      } else {
        String errorMsg = data['message'] ?? 'Invalid login credentials.';
        if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          errorMsg = (data['errors'] as List).join('\n');
        }
        return {'success': false, 'message': errorMsg};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Check that your phone and PC are on the same Wi-Fi network.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server (${e.runtimeType}).',
      };
    }
  }

  /// Fetch user profile from backend using saved JWT token
  Future<UserModel?> getProfile() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);
        await _updateCachedUser(user);
        return user;
      } else {
        // Token expired or invalid
        await logout();
        return null;
      }
    } catch (e) {
      // Return cached user if offline (includes timeout)
      return _cachedUser ?? await _loadUserFromStorage();
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
    String? phone,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated. Please log in.'};
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users/me');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (fullName != null) 'fullName': fullName,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final updatedUser = UserModel.fromJson(data['user']);
        await _updateCachedUser(updatedUser);
        return {'success': true, 'user': updatedUser, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update profile.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error while updating profile.'};
    }
  }

  /// Check if user has an active session
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final user = await getProfile();
    return user != null;
  }

  /// Get active saved JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (e) {
      _cachedToken = null;
    }
    return _cachedToken;
  }

  /// Get currently cached user
  Future<UserModel?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    return await _loadUserFromStorage();
  }

  /// Logout user and remove stored session
  Future<void> logout() async {
    _cachedToken = null;
    _cachedUser = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (e) {
      // Storage delete error fallback
    }
  }

  // --- Private Helpers ---

  Future<void> _saveSession(String token, UserModel user) async {
    _cachedToken = token;
    _cachedUser = user;
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (e) {
      // Fallback in memory
    }
  }

  Future<void> _updateCachedUser(UserModel user) async {
    _cachedUser = user;
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (e) {
      // Storage write fallback
    }
  }

  Future<UserModel?> _loadUserFromStorage() async {
    try {
      final userStr = await _storage.read(key: _userKey);
      if (userStr != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(userStr);
        _cachedUser = UserModel.fromJson(jsonMap);
        return _cachedUser;
      }
    } catch (e) {
      _cachedUser = null;
    }
    return null;
  }
}
