import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/db_helper.dart';

class AppState extends ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _activeStudent;
  List<dynamic> _activePayments = [];
  List<dynamic> _paidPayments = [];
  Map<String, dynamic>? _dailySummary;
  List<dynamic> _attendanceStudents = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get activeStudent => _activeStudent;
  List<dynamic> get activePayments => _activePayments;
  List<dynamic> get paidPayments => _paidPayments;
  Map<String, dynamic>? get dailySummary => _dailySummary;
  List<dynamic> get attendanceStudents => _attendanceStudents;

  final _secureStorage = const FlutterSecureStorage();

  // Initialize and check auto-login session
  Future<void> init() async {
    _setLoading(true);
    await ApiService.init();
    
    // Register unauthorized listener to force logout on 401 response
    ApiService.onUnauthorized = () {
      logout();
    };
    
    if (ApiService.isAuthenticated) {
      final userJson = await _secureStorage.read(key: "user_info");
      if (userJson != null) {
        try {
          _currentUser = jsonDecode(userJson);
        } catch (_) {
          await logout();
        }
      } else {
        await logout();
      }
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Handle Log In
  Future<bool> login(String loginInput, String password, String serverUrl) async {
    _setLoading(true);
    try {
      await ApiService.setServerUrl(serverUrl);
      final response = await ApiService.post('/login', {
        'login': loginInput,
        'password': password,
      });

      final token = response['token'];
      final user = response['user'];

      await ApiService.setToken(token);
      _currentUser = user;

      _currentUser = user;

      // Persist user info
      await _secureStorage.write(key: "user_info", value: jsonEncode(user));
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Handle Log Out
  Future<void> logout() async {
    _setLoading(true);
    try {
      if (ApiService.isAuthenticated) {
        await ApiService.post('/logout', {});
      }
    } catch (_) {
      // Ignore API logout error, proceed to clear local data
    } finally {
      await ApiService.setToken(null);
      _currentUser = null;
      _activeStudent = null;
      _activePayments = [];
      _paidPayments = [];
      _dailySummary = null;
      
      await _secureStorage.delete(key: "user_info");
      _setLoading(false);
    }
  }

  // Search/Scan Student
  Future<void> searchStudent(String query) async {
    _setLoading(true);
    _activeStudent = null;
    _activePayments = [];
    _paidPayments = [];
    try {
      final response = await ApiService.get('/student/search?q=$query');
      _activeStudent = response['student'];
      _activePayments = response['payments'] ?? [];
      _paidPayments = response['paid_payments'] ?? [];
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Collect cash payment
  Future<void> collectCash(int paymentId) async {
    _setLoading(true);
    try {
      await ApiService.post('/payment/collect/$paymentId', {});
      
      // Remove payment from active list
      _activePayments.removeWhere((p) => p['id'] == paymentId);
      
      // Refresh daily summary
      await fetchDailySummary();
      
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Fetch daily summaries for dashboard
  Future<void> fetchDailySummary() async {
    if (!ApiService.isAuthenticated) return;
    try {
      final response = await ApiService.get('/summary/daily');
      _dailySummary = response['summary'];
      notifyListeners();
    } catch (e) {
      debugPrint("--- ERROR: fetchDailySummary failed: $e ---");
    }
  }

  // List pending approvals (Officer only)
  Future<List<dynamic>> getPendingApprovals() async {
    try {
      final response = await ApiService.get('/officer/pending');
      return response['payments'] ?? [];
    } catch (e) {
      rethrow;
    }
  }

  // Approve payment (Officer only)
  Future<void> approvePayment(int paymentId) async {
    _setLoading(true);
    try {
      await ApiService.post('/payment/approve/$paymentId', {});
      await fetchDailySummary();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Bulk approve multiple payments (Officer only)
  Future<Map<String, dynamic>> bulkApprovePayments(List<int> paymentIds) async {
    _setLoading(true);
    try {
      final response = await ApiService.post('/payment/bulk-approve', {
        'payment_ids': paymentIds,
      });
      await fetchDailySummary();
      _setLoading(false);
      return response;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  void clearActiveStudent() {
    _activeStudent = null;
    _activePayments = [];
    _paidPayments = [];
    notifyListeners();
  }

  // Change password method
  Future<void> changePassword(String currentPassword, String newPassword) async {
    _setLoading(true);
    try {
      await ApiService.post('/password/change', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Get paginated and filtered agent students list
  Future<Map<String, dynamic>> fetchAgentStudents({required String status, required int page, String search = ""}) async {
    try {
      final response = await ApiService.get('/agent/students?status=$status&page=$page&search=${Uri.encodeComponent(search)}');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Get students list for attendance
  Future<void> fetchAttendanceStudents({String department = ""}) async {
    _setLoading(true);
    try {
      _attendanceStudents = await ApiService.fetchStudentsForAttendance(department);
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Submit attendance for a single student
  Future<Map<String, dynamic>> submitAttendance(String studentId, int departmentId) async {
    _setLoading(true);
    try {
      final response = await ApiService.submitAttendance(studentId, departmentId);
      _setLoading(false);
      return response;
    } catch (e) {
      // If network fails, save offline
      await DatabaseHelper.instance.insertAttendance(studentId, departmentId);
      _setLoading(false);
      return {'status': 'offline', 'message': 'অফলাইনে হাজিরা সেভ করা হয়েছে। ইন্টারনেট পেলে সিঙ্ক করুন।'};
    }
  }

  // Sync offline data
  Future<void> syncOfflineData(BuildContext context) async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedAttendance();
    if (unsynced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("সিঙ্ক করার মতো কোনো ডেটা নেই!")));
      return;
    }

    _setLoading(true);
    int syncedCount = 0;
    
    for (var record in unsynced) {
      try {
        await ApiService.submitAttendance(record['student_id'], record['department_id'] as int);
        await DatabaseHelper.instance.deleteAttendance(record['id'] as int);
        syncedCount++;
      } catch (e) {
        // Continue to next record if one fails
      }
    }
    _setLoading(false);
    
    if (syncedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$syncedCount টি হাজিরা সফলভাবে সিঙ্ক হয়েছে!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("সিঙ্ক ব্যর্থ হয়েছে। ইন্টারনেট চেক করুন।"), backgroundColor: Colors.red));
    }
  }
}

final appStateProvider = ChangeNotifierProvider<AppState>((ref) => AppState());
