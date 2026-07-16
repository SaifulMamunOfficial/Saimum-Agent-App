import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/app_state.dart';
import '../services/update_service.dart';
import 'qr_scanner_screen.dart';
import 'collect_screen.dart';
import 'officer_screen.dart';
import 'student_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  final _studentSearchController = TextEditingController();
  bool _showDue = false;
  String _studentSearchQuery = "";

  // Track checked attendance students locally
  final Map<String, bool> _attendanceState = {};
  String? _selectedAttendanceDeptName;
  int? _selectedAttendanceDeptId;
  List<Map<String, dynamic>> _allowedDeptsList = [];
  bool _isSyncingAttendance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // অটো আপডেট চেক
      UpdateService.checkForUpdate(context);

      final appState = ref.read(appStateProvider);
      await appState.fetchDailySummary();
      
      // Parse allowed departments
      final user = appState.currentUser;
      if (user != null && user['allowed_departments'] != null) {
        final List<dynamic> depts = user['allowed_departments'];
        _allowedDeptsList = depts.map((d) => d as Map<String, dynamic>).toList();
      }
      
      if (_allowedDeptsList.isNotEmpty) {
        setState(() {
          _selectedAttendanceDeptName = _allowedDeptsList.first['name'] as String;
          _selectedAttendanceDeptId = _allowedDeptsList.first['id'] as int;
        });
        _loadAttendanceStudents();
      }
    });
  }

  void _loadAttendanceStudents() async {
    if (_selectedAttendanceDeptName != null) {
      final appState = ref.read(appStateProvider);
      await appState.fetchAttendanceStudents(department: _selectedAttendanceDeptName!);
      if (mounted) {
        setState(() {
          for (var student in appState.attendanceStudents) {
            final String studentIdStr = student['reg_id'] ?? student['student_id'] ?? '';
            final bool isPresent = student['is_present'] ?? false;
            _attendanceState[studentIdStr] = isPresent;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      await ref.read(appStateProvider).searchStudent(query);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CollectScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context, e.toString());
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info_outline_rounded, color: Colors.red.shade400, size: 36),
        ),
        title: const Text(
          "ভিন্ন বিভাগের শিক্ষার্থী",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF636E72)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF751F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("বুঝেছি", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    bool localLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("পাসওয়ার্ড পরিবর্তন", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "বর্তমান পাসওয়ার্ড",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "বর্তমান পাসওয়ার্ড দিন।";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "নতুন পাসওয়ার্ড",
                        prefixIcon: Icon(Icons.lock_reset),
                        helperText: "কমপক্ষে ৬ অক্ষরের হতে হবে",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "নতুন পাসওয়ার্ড দিন।";
                        if (value.length < 6) return "কমপক্ষে ৬ অক্ষরের হতে হবে।";
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: localLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("বাতিল"),
                ),
                ElevatedButton(
                  onPressed: localLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => localLoading = true);
                          try {
                            await ref.read(appStateProvider).changePassword(
                              currentPasswordController.text,
                              newPasswordController.text,
                            );
                            navigator.pop();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text("পাসওয়ার্ড সফলভাবে পরিবর্তন করা হয়েছে।"), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            setDialogState(() => localLoading = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF751F),
                    foregroundColor: Colors.white,
                  ),
                  child: localLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text("সংরক্ষণ করুন"),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
    });
  }

  // Build Tab 1: Dashboard View
  Widget _buildDashboardTab(bool isOfficer, dynamic summary) {
    return RefreshIndicator(
      onRefresh: () => ref.read(appStateProvider).fetchDailySummary(),
      color: const Color(0xFFFF751F),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "আজকের কার্যক্রমের সারাংশ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
            ),
            const SizedBox(height: 12),

            // Statistics Summary Cards
            if (isOfficer) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildStatCard("আজকের কালেকশন", "৳${summary?['collected_today'] ?? 0.0}", Icons.payments, Colors.blue, onTap: () {
                      _showStaticPaymentsModal(context, "আজকের কালেকশন", summary?['collected_list'] ?? []);
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("আজ অনুমোদিত", "৳${summary?['approved_today'] ?? 0.0}", Icons.verified, Colors.green, onTap: () {
                      _showStaticPaymentsModal(context, "আজ অনুমোদিত", summary?['approved_list'] ?? []);
                    })),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                "অনুমোদনের অপেক্ষায়",
                "${summary?['pending_approval_count'] ?? 0} টি পেমেন্ট",
                Icons.hourglass_empty,
                Colors.orange,
                fullWidth: true,
              ),
            ] else ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildStatCard("আজকের সংগ্রহ", "৳${summary?['collected_today'] ?? 0.0}", Icons.monetization_on, Colors.green, onTap: () {
                      _showStaticPaymentsModal(context, "আজকের সংগ্রহ", summary?['collected_list'] ?? []);
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("অপেক্ষমান", "${summary?['pending_approval_count'] ?? 0} টি", Icons.hourglass_top, Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Collapsible Due card
              GestureDetector(
                onTap: () => setState(() => _showDue = !_showDue),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "অনুমোদিত বিভাগের মোট বকেয়া",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              AnimatedCrossFade(
                                firstChild: const Text(
                                  "ট্যাপ করে দেখুন",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF636E72)),
                                ),
                                secondChild: Text(
                                  "৳${summary?['total_dept_due'] ?? 0.0}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                crossFadeState: _showDue ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 300),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showDue ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "আজকের হাজিরার চিত্র",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAttendanceStatItem("মোট শিক্ষার্থী", "${summary?['attendance_total'] ?? 0}", Colors.blue),
                      _buildAttendanceStatItem("উপস্থিত", "${summary?['attendance_present'] ?? 0}", Colors.green),
                      _buildAttendanceStatItem("অনুপস্থিত", "${summary?['attendance_absent'] ?? 0}", Colors.red),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Search Student Section
            if (!isOfficer) ...[
              const Text(
                "শিক্ষার্থী খুঁজুন",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: "আইডি বা রেজিঃ দিন...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _handleSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF751F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("খুঁজুন", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              const Text("পরিচালনা কার্যক্রম", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = 3; // 'অনুমোদন' ট্যাব
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 30, color: Colors.white),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          "কালেকশন অনুমোদন করুন",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build Tab 2: Students Tab
  Widget _buildStudentsTab() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // Unified Global Search Bar Header (10 Years UX Expert standard Layout)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _studentSearchController,
                        decoration: InputDecoration(
                          hintText: "শিক্ষার্থীর নাম বা আইডি দিয়ে খুঁজুন...",
                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                          suffixIcon: _studentSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _studentSearchController.clear();
                                    setState(() {
                                      _studentSearchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            _studentSearchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _studentSearchQuery = _studentSearchController.text.trim();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF751F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text("খুঁজুন", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            // Sub Header TabBar navigation
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFFFF751F),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFFFF751F),
                indicatorWeight: 3.0,
                tabs: [
                  Tab(text: "সকল শিক্ষার্থী"),
                  Tab(text: "বকেয়া তালিকা"),
                  Tab(text: "পরিশোধিত"),
                ],
              ),
            ),
            
            // Inner Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  StudentListScreen(
                    status: 'all', 
                    title: 'সকল শিক্ষার্থী', 
                    showAppBar: false,
                    search: _studentSearchQuery,
                  ),
                  StudentListScreen(
                    status: 'due', 
                    title: 'বকেয়া তালিকা', 
                    showAppBar: false,
                    search: _studentSearchQuery,
                  ),
                  StudentListScreen(
                    status: 'paid', 
                    title: 'পরিশোধিত তালিকা', 
                    showAppBar: false,
                    search: _studentSearchQuery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStudentAttendance(String studentId, bool status) async {
    if (_isSyncingAttendance) return;
    
    setState(() {
      _isSyncingAttendance = true;
    });

    try {
      int departmentId = _selectedAttendanceDeptId ?? 1;
      await ref.read(appStateProvider).submitAttendance(studentId, departmentId);
      
      setState(() {
        _attendanceState[studentId] = status;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("হাজিরা সফলভাবে সংরক্ষণ করা হয়েছে।"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingAttendance = false;
        });
      }
    }
  }

  // Build Tab 3: Dynamic Attendance UI Screen
  Widget _buildAttendanceTab() {
    final appState = ref.watch(appStateProvider);
    final today = DateTime.now();
    final formattedDate = "${today.day}/${today.month}/${today.year}";
    final students = appState.attendanceStudents;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header info banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "আজকের হাজিরা শীট",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "তারিখ: $formattedDate",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                // Allowed Departments Dropdown Selection
                if (_allowedDeptsList.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF751F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedAttendanceDeptId,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF751F), size: 20),
                          style: const TextStyle(color: Color(0xFFFF751F), fontWeight: FontWeight.bold, fontSize: 12),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              final dept = _allowedDeptsList.firstWhere((d) => d['id'] == newValue);
                              setState(() {
                                _selectedAttendanceDeptId = newValue;
                                _selectedAttendanceDeptName = dept['name'] as String;
                              });
                              _loadAttendanceStudents();
                            }
                          },
                          items: _allowedDeptsList.map<DropdownMenuItem<int>>((Map<String, dynamic> dept) {
                            return DropdownMenuItem<int>(
                              value: dept['id'] as int,
                              child: Text(
                                dept['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "কোনো অনুমোদিত বিভাগ নেই",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: appState.isLoading && students.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF751F)),
                    ),
                  )
                : students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "এই বিভাগে কোনো শিক্ষার্থী পাওয়া যায়নি।",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadAttendanceStudents(),
                        color: const Color(0xFFFF751F),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14.0),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final String studentIdStr = student['reg_id'] ?? student['student_id'] ?? '';
                            final bool isPresent = _attendanceState[studentIdStr] ?? false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10.0),
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade100),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: (isPresent ? Colors.green : Colors.grey.shade100),
                                      radius: 20,
                                      child: Icon(
                                        isPresent ? Icons.check : Icons.person_outline,
                                        color: isPresent ? Colors.white : Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['name'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3436)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "আইডি: $studentIdStr",
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),

                                    InkWell(
                                      onTap: null, // ম্যানুয়াল হাজিরা বন্ধ করা হয়েছে, শুধুমাত্র স্ক্যান করে হাজিরা নেওয়া যাবে
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isPresent ? "উপস্থিত" : "অনুপস্থিত",
                                          style: TextStyle(
                                            color: isPresent ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Build Tab 5: Profile View (Luxury Redesigned)
  Widget _buildProfileTab(Map<String, dynamic>? user, bool isOfficer, List<String> allowedDepts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Details Card with modern styling
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Header Gradient Banner inside card
                Container(
                  height: 100,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                
                // Avatar positioned slightly overlapping
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFFF751F).withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: Color(0xFFFF751F), size: 44),
                    ),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Text(
                          user?['name'] ?? 'ব্যবহারকারী',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF751F).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOfficer ? "প্রধান অ্যাকাউন্টস অফিসার" : "সংগ্রহকারী এজেন্ট",
                            style: const TextStyle(color: Color(0xFFFF751F), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        
                        // Email/Phone details if available
                        if (user?['email'] != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                user!['email'].toString(),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                        
                        // Allowed departments tags
                        if (!isOfficer && allowedDepts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            "অনুমোদিত বিভাগসমূহ",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: allowedDepts.map((d) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                d, 
                                style: const TextStyle(fontSize: 10, color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Security Actions list (Clean Material design)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFFFF751F)),
                  title: const Text("পাসওয়ার্ড পরিবর্তন", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red.shade400),
                  title: Text("লগআউট", style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red, size: 20),
                  onTap: () => ref.read(appStateProvider).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final user = appState.currentUser;
    final summary = appState.dailySummary;
    final isOfficer = user != null && (user['role'] == 'admin' || user['role'] == 'account_officer');
    
    final dynamic deptData = user?['allowed_departments'] ?? user?['agent_allowed_departments'];
    List<String> allowedDepts = [];
    if (deptData is List) {
      allowedDepts = deptData.map((e) => e is Map ? (e['name']?.toString() ?? e.toString()) : e.toString()).toList();
    } else if (deptData is String && deptData.isNotEmpty) {
      allowedDepts = deptData.split(',').map((e) => e.trim()).toList();
    }

    // Tab indexing mapping
    // Index 0: Dashboard
    // Index 1: Students
    // Index 2: Scanner placeholder
    // Index 3: Attendance (Agent) / Pending Approvals (Officer)
    // Index 4: Profile
    final List<Widget> tabs = [
      _buildDashboardTab(isOfficer, summary),
      _buildStudentsTab(),
      const SizedBox.shrink(),
      isOfficer ? const OfficerScreen() : _buildAttendanceTab(),
      _buildProfileTab(user, isOfficer, allowedDepts),
    ];

    final List<String> titles = [
      isOfficer ? "অফিসার ড্যাশবোর্ড" : "এজেন্ট ড্যাশবোর্ড",
      "শিক্ষার্থী তালিকা",
      "QR কোড স্ক্যানার",
      isOfficer ? "অনুমোদন বাকি" : "শিক্ষার্থী হাজিরা",
      isOfficer ? "অফিসার প্রোফাইল" : "এজেন্ট প্রোফাইল",
    ];

    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        backgroundColor: const Color(0xFFFF751F), // Saimum Brand Orange Color
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!isOfficer && _currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'অফলাইন ডেটা সিঙ্ক করুন',
              onPressed: () {
                ref.read(appStateProvider).syncOfflineData(context);
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),

      // Docked highlighted floating Action Button in the middle (FAB)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isKeyboardVisible
          ? null
          : FloatingActionButton(
              onPressed: () {
                // Officer সবসময় payment mode এ স্ক্যান করবে
                // Agent হাজিরা ট্যাব থেকে স্ক্যান করলে attendance mode
                final initDept = (!isOfficer && _currentIndex == 3)
                    ? _selectedAttendanceDeptId
                    : null;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QrScannerScreen(
                      initialDepartmentId: initDept,
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFFFF751F),
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: Colors.white),
            ),

      // Premium BottomAppBar with center notch configuration
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white, // Reverted to premium white
        elevation: 8,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left Navigation Buttons
              _buildBottomNavItem(0, Icons.dashboard_rounded, "ড্যাশবোর্ড"),
              _buildBottomNavItem(1, Icons.people_rounded, "শিক্ষার্থী"),
              
              // Spacing helper for the central docked floating button
              const SizedBox(width: 48),

              // Right Navigation Buttons (role-based)
              isOfficer
                  ? _buildBottomNavItem(3, Icons.approval_rounded, "অনুমোদন")
                  : _buildBottomNavItem(3, Icons.how_to_reg_rounded, "হাজিরা"),
              _buildBottomNavItem(4, Icons.person_rounded, "প্রোফাইল"),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Navigation Item Builder with active color feedback
  Widget _buildBottomNavItem(int targetIndex, IconData icon, String label) {
    final bool isActive = _currentIndex == targetIndex;
    final Color itemColor = isActive ? const Color(0xFFFF751F) : Colors.grey.shade500;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = targetIndex;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaticPaymentsModal(BuildContext context, String title, List<dynamic> payments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: payments.isEmpty
                    ? const Center(child: Text("কোনো পেমেন্ট নেই", style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['student']?['name'] ?? '',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "৳${p['amount']}",
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "আইডি: ${p['student']?['student_id'] ?? ''}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "বিল: ${p['label']}",
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    p['agent_name'] ?? '',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: p['status'] == 2 ? Colors.green.shade50 : Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          p['status'] == 2 ? 'অনুমোদিত' : 'অপেক্ষমান',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: p['status'] == 2 ? Colors.green.shade700 : Colors.blue.shade700
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08), // Tinted premium color background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: fullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: fullWidth ? TextAlign.start : TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: fullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildAttendanceStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
