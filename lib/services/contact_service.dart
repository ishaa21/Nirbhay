import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/emergency_contact_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class EmergencyContactService {
  static final EmergencyContactService _instance = EmergencyContactService._internal();
  factory EmergencyContactService() => _instance;
  EmergencyContactService._internal();

  static const String _contactsCacheKey = 'nirbhay_cached_emergency_contacts';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<EmergencyContactModel>? _memoryCache;

  /// Fetch local cached emergency contacts without internet
  Future<List<EmergencyContactModel>> getLocalContacts() async {
    if (_memoryCache != null && _memoryCache!.isNotEmpty) {
      return List<EmergencyContactModel>.from(_memoryCache!);
    }
    try {
      final raw = await _storage.read(key: _contactsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _memoryCache = decoded
            .map((e) => EmergencyContactModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return List<EmergencyContactModel>.from(_memoryCache!);
      }
    } catch (e) {
      debugPrint('[ContactService] Error reading local contacts: $e');
    }
    return _memoryCache != null ? List<EmergencyContactModel>.from(_memoryCache!) : [];
  }

  Future<void> _saveLocalContacts(List<EmergencyContactModel> contacts) async {
    _memoryCache = List<EmergencyContactModel>.from(contacts);
    try {
      final jsonList = contacts.map((c) => c.toJson()).toList();
      await _storage.write(key: _contactsCacheKey, value: jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ContactService] Error saving local contacts: $e');
    }
  }

  /// Fetch all emergency contacts for current user (with offline fallback)
  Future<Map<String, dynamic>> fetchContacts() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        final cached = await getLocalContacts();
        if (cached.isNotEmpty) {
          return {'success': true, 'contacts': cached, 'offline': true};
        }
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List rawList = data['contacts'] ?? [];
        final contacts = rawList.map((e) => EmergencyContactModel.fromJson(e)).toList();
        await _saveLocalContacts(contacts);
        return {'success': true, 'contacts': contacts};
      } else {
        final cached = await getLocalContacts();
        if (cached.isNotEmpty) {
          return {'success': true, 'contacts': cached, 'offline': true};
        }
        String msg = data['message'] ?? 'Failed to load emergency contacts.';
        if (data['error'] != null) {
          msg += ' (${data['error']})';
        }
        return {
          'success': false,
          'message': msg,
        };
      }
    } on SocketException {
      final cached = await getLocalContacts();
      if (cached.isNotEmpty) {
        return {'success': true, 'contacts': cached, 'offline': true};
      }
      return {
        'success': false,
        'offline': true,
        'message': 'No internet connection. No cached emergency contacts found.',
      };
    } on TimeoutException {
      final cached = await getLocalContacts();
      if (cached.isNotEmpty) {
        return {'success': true, 'contacts': cached, 'offline': true};
      }
      return {
        'success': false,
        'offline': true,
        'message': 'Request timed out. Please check your network connection.',
      };
    } catch (e) {
      final cached = await getLocalContacts();
      if (cached.isNotEmpty) {
        return {'success': true, 'contacts': cached, 'offline': true};
      }
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server.',
      };
    }
  }

  /// Add a new emergency contact
  Future<Map<String, dynamic>> addContact({
    required String name,
    required String phone,
    String? relationship,
    bool autoAlert = true,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'relationship': relationship ?? '',
          'autoAlert': autoAlert,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final newContact = EmergencyContactModel.fromJson(data['contact']);
        final current = await getLocalContacts();
        current.removeWhere((c) => c.id == newContact.id);
        current.add(newContact);
        await _saveLocalContacts(current);
        return {
          'success': true,
          'contact': newContact,
          'message': data['message'] ?? 'Contact added successfully.',
        };
      } else {
        String errorMsg = data['message'] ?? 'Failed to add contact.';
        if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          errorMsg = (data['errors'] as List).join('\n');
        } else if (data['error'] != null) {
          errorMsg += ' (${data['error']})';
        }
        return {'success': false, 'message': errorMsg};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server.',
      };
    }
  }

  /// Update an existing emergency contact
  Future<Map<String, dynamic>> updateContact(
    String contactId, {
    String? name,
    String? phone,
    String? relationship,
    bool? autoAlert,
  }) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId');
      final bodyMap = <String, dynamic>{};
      if (name != null) bodyMap['name'] = name;
      if (phone != null) bodyMap['phone'] = phone;
      if (relationship != null) bodyMap['relationship'] = relationship;
      if (autoAlert != null) bodyMap['autoAlert'] = autoAlert;

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final updatedContact = EmergencyContactModel.fromJson(data['contact']);
        final current = await getLocalContacts();
        final idx = current.indexWhere((c) => c.id == contactId);
        if (idx != -1) {
          current[idx] = updatedContact;
        } else {
          current.add(updatedContact);
        }
        await _saveLocalContacts(current);
        return {
          'success': true,
          'contact': updatedContact,
          'message': data['message'] ?? 'Contact updated successfully.',
        };
      } else {
        String errorMsg = data['message'] ?? 'Failed to update contact.';
        if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          errorMsg = (data['errors'] as List).join('\n');
        }
        return {'success': false, 'message': errorMsg};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server.',
      };
    }
  }

  /// Delete an emergency contact
  Future<Map<String, dynamic>> deleteContact(String contactId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Not authenticated. Please log in.'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final current = await getLocalContacts();
        current.removeWhere((c) => c.id == contactId);
        await _saveLocalContacts(current);
        return {
          'success': true,
          'id': contactId,
          'message': data['message'] ?? 'Contact deleted successfully.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete contact.',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: Unable to reach backend server.',
      };
    }
  }
}
