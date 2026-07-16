import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  // static String _serverUrl = "http://192.168.0.170:8000/api"; // Local test URL
  static String _serverUrl = "https://academy.saimum.org/api"; // Default Live Production URL
  static String? _token;
  static VoidCallback? onUnauthorized;
  static const _secureStorage = FlutterSecureStorage();

  static String get baseUrl => _serverUrl;

  // Initialize service, load stored URL and Token
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load stored URL or fallback to Live Production URL
    // _serverUrl = "http://192.168.0.170:8000/api"; // Force local IP for now
    _serverUrl = prefs.getString("server_url") ?? "https://academy.saimum.org/api";
    
    _token = await _secureStorage.read(key: "auth_token");
  }

  // Update base server URL dynamically
  static Future<void> setServerUrl(String url) async {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (!_serverUrl.contains('/api')) {
      _serverUrl = "$_serverUrl/api";
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("server_url", _serverUrl);
  }

  // Save auth token
  static Future<void> setToken(String? token) async {
    if (token == null) {
      await _secureStorage.delete(key: "auth_token");
    } else {
      await _secureStorage.write(key: "auth_token", value: token);
    }
    _token = token;
  }

  static String? get token => _token;
  static bool get isAuthenticated => _token != null;

  // Generate headers
  static Map<String, String> _getHeaders() {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (_token != null) {
      headers["Authorization"] = "Bearer $_token";
    }
    return headers;
  }

  // Global response handler (handles status codes, returns decoded JSON)
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body;
    Map<String, dynamic> jsonResponse = {};
    
    try {
      jsonResponse = jsonDecode(body);
    } catch (_) {
      // Return raw string or generic map if not JSON
      jsonResponse = {"message": body.isNotEmpty ? body : "সিস্টেম ত্রুটি হয়েছে।"};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonResponse;
    } else if (response.statusCode == 401) {
      // Unauthenticated, trigger logout if needed
      setToken(null);
      onUnauthorized?.call();
      throw ApiException(jsonResponse["message"] ?? "সেশন শেষ হয়ে গেছে, আবার লগইন করুন।", response.statusCode);
    } else if (response.statusCode == 403) {
      throw ApiException(jsonResponse["message"] ?? "আপনার এই কাজটি করার অনুমতি নেই।", response.statusCode);
    } else if (response.statusCode == 404) {
      throw ApiException(jsonResponse["message"] ?? "খুঁজে পাওয়া যায়নি।", response.statusCode);
    } else {
      throw ApiException(jsonResponse["message"] ?? "সার্ভারে সমস্যা হয়েছে (কোড: ${response.statusCode})।", response.statusCode);
    }
  }

  // GET Request
  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http.get(
        Uri.parse("$_serverUrl$path"),
        headers: _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("সার্ভারের সাথে সংযোগ স্থাপন করা যাচ্ছে না। আপনার ইন্টারনেট কানেকশন বা সার্ভার ইউআরএল চেক করুন।", 0);
    }
  }

  // POST Request
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$_serverUrl$path"),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("সার্ভারের সাথে সংযোগ স্থাপন করা যাচ্ছে না। আপনার ইন্টারনেট কানেকশন বা সার্ভার ইউআরএল চেক করুন।", 0);
    }
  }

  // PUT Request
  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse("$_serverUrl$path"),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("সার্ভারের সাথে যোগাযোগ করা যাচ্ছে না। দয়া করে আপনার ইন্টারনেট কানেকশন চেক করুন।", 0);
    }
  }

  // Multipart POST Request for File Uploads
  static Future<Map<String, dynamic>> multipartPost(String path, String filePath) async {
    try {
      final request = http.MultipartRequest("POST", Uri.parse("$_serverUrl$path"));
      
      // Add Headers
      if (_token != null) {
        request.headers["Authorization"] = "Bearer $_token";
      }
      request.headers["Accept"] = "application/json";

      // Attach file
      request.files.add(await http.MultipartFile.fromPath("avatar", filePath));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("ফাইল আপলোডে সমস্যা হয়েছে। ইন্টারনেট কানেকশন চেক করুন।", 0);
    }
  }

  // Get students list for attendance
  static Future<List<dynamic>> fetchStudentsForAttendance(String department) async {
    try {
      final response = await get('/agent/students?status=all&department=${Uri.encodeComponent(department)}');
      return response['data'] ?? response['students'] ?? [];
    } catch (e) {
      rethrow;
    }
  }

  // Submit single student attendance
  static Future<Map<String, dynamic>> submitAttendance(String studentId, int departmentId) async {
    try {
      final response = await post('/attendance/scan', {
        'student_id': studentId,
        'department_id': departmentId,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Fetch department-wise due summary for officer
  static Future<Map<String, dynamic>> fetchDepartmentDues() async {
    return await get('/officer/department-dues');
  }
}


class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
