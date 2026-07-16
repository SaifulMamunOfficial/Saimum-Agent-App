import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/app_state.dart';
import '../services/api_service.dart';
import 'collect_screen.dart';

class OfficerScreen extends ConsumerStatefulWidget {
  const OfficerScreen({super.key});

  @override
  ConsumerState<OfficerScreen> createState() => _OfficerScreenState();
}

class _OfficerScreenState extends ConsumerState<OfficerScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _pendingList = [];
  bool _localLoading = false;
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _deptDues = [];
  double _grandTotalDue = 0;
  int _grandPending = 0;
  int _grandApprovedToday = 0;
  bool _deptLoading = false;
  bool _deptExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPendingApprovals();
    _fetchDeptDues();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingApprovals() async {
    setState(() => _localLoading = true);
    try {
      final list = await ref.read(appStateProvider).getPendingApprovals();
      setState(() {
        _pendingList = list;
        _localLoading = false;
      });
    } catch (e) {
      setState(() => _localLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchDeptDues() async {
    setState(() => _deptLoading = true);
    try {
      final data = await ApiService.fetchDepartmentDues();
      setState(() {
        _deptDues = data['departments'] ?? [];
        _grandTotalDue = (data['grand_total_due'] ?? 0).toDouble();
        _grandPending = data['grand_pending'] ?? 0;
        _grandApprovedToday = data['grand_approved_today'] ?? 0;
        _deptLoading = false;
      });
    } catch (e) {
      setState(() => _deptLoading = false);
    }
  }

  Future<void> _handleDirectSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      await ref.read(appStateProvider).searchStudent(query);
      if (mounted) {
        setState(() => _isSearching = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CollectScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _confirmApproval(Map<String, dynamic> payment, {VoidCallback? onSuccess}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text("অনুমোদন নিশ্চিতকরণ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "এজেন্ট '${payment['agent_name']}' কর্তৃক সংগৃহীত\n'${payment['student']['name']}' এর '${payment['label']}' বাবদ ৳${payment['amount']} কালেকশনটি চূড়ান্ত অনুমোদন দেবেন?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleApproval(payment['id'], onSuccess: onSuccess);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("চূড়ান্ত অনুমোদন দিন"),
          ),
        ],
      ),
    );
  }

  void _handleApproval(int paymentId, {VoidCallback? onSuccess}) async {
    setState(() => _localLoading = true);
    try {
      await ref.read(appStateProvider).approvePayment(paymentId);
      await _fetchPendingApprovals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("পেমেন্ট সফলভাবে অনুমোদন দেওয়া হয়েছে।"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchDeptDues();
        setState(() => _localLoading = false);
        if (onSuccess != null) onSuccess();
      }
    } catch (e) {
      setState(() => _localLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmBulkApproval(String agentName, List<Map<String, dynamic>> payments, {VoidCallback? onSuccess}) {
    final totalAmount = payments.fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());
    final paymentIds = payments.map<int>((p) => p['id'] as int).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.done_all_rounded, color: Colors.blue.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text("বাল্ক অনুমোদন",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          "এজেন্ট '$agentName' এর সংগৃহীত ${payments.length}টি পেমেন্ট (মোট ৳${totalAmount.toStringAsFixed(0)}) একসাথে চূড়ান্ত অনুমোদন দেবেন?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _handleBulkApproval(paymentIds, onSuccess: onSuccess);
            },
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: const Text("সব অনুমোদন দিন"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBulkApproval(List<int> paymentIds, {VoidCallback? onSuccess}) async {
    setState(() => _localLoading = true);
    try {
      final response = await ref.read(appStateProvider).bulkApprovePayments(paymentIds);
      await _fetchPendingApprovals();
      if (mounted) {
        final approvedCount = response['approved_count'] ?? 0;
        final skippedCount = response['skipped_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$approvedCountটি পেমেন্ট সফলভাবে অনুমোদন দেওয়া হয়েছে।" + (skippedCount > 0 ? " ($skippedCountটি স্কিপ করা হয়েছে)" : "")),
            backgroundColor: skippedCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        _fetchPendingApprovals();
        _fetchDeptDues();
        if (onSuccess != null) onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Collapsible department summary card with premium light green design
          _buildDeptDuesPanel(),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF751F), // Saimum Brand Orange
              unselectedLabelColor: Colors.grey.shade500,
              indicatorColor: const Color(0xFFFF751F),
              isScrollable: true,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.approval_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text("অনুমোদন বাকি"),
                      if (_pendingList.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_pendingList.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_work_rounded, size: 18),
                      SizedBox(width: 6),
                      Text("এজেন্ট ভিত্তিক"),
                    ],
                  ),
                ),
                const Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_card_rounded, size: 18),
                      SizedBox(width: 6),
                      Text("সরাসরি সংগ্রহ"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Single Pending Approvals
                RefreshIndicator(
                  onRefresh: () async {
                    await _fetchPendingApprovals();
                    await _fetchDeptDues();
                  },
                  color: const Color(0xFFFF751F),
                  child: _localLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF751F)),
                          ),
                        )
                      : _pendingList.isEmpty
                          ? _buildEmptyState()
                          : _buildFlatPendingList(),
                ),

                // Tab 2: Agent-wise Grouped Approvals
                RefreshIndicator(
                  onRefresh: () async {
                    await _fetchPendingApprovals();
                    await _fetchDeptDues();
                  },
                  color: const Color(0xFFFF751F),
                  child: _localLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF751F)),
                          ),
                        )
                      : _pendingList.isEmpty
                          ? _buildEmptyState()
                          : _buildGroupedPendingList(),
                ),

                // Tab 3: Direct Collection
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFF751F), Colors.orange.shade800],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "আপনি সরাসরি শিক্ষার্থীর কাছ থেকে ফি সংগ্রহ করতে পারবেন। এই মোডে সংগ্রহ অনুমোদন ছাড়াই সরাসরি যোগ হবে।",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Search by ID
                      const Text(
                        "শিক্ষার্থীর আইডি দিয়ে খুঁজুন",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _handleDirectSearch(),
                              decoration: InputDecoration(
                                hintText: "রেজিস্ট্রেশন নম্বর বা নাম লিখুন",
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF751F)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFFF751F), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSearching ? null : _handleDirectSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF751F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSearching
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("খুঁজুন",
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // QR Hint
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "QR স্ক্যানার ব্যবহার করুন",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "নিচের কেন্দ্রীয় বাটন চেপে QR কোড স্ক্যান করলেও সরাসরি পেমেন্ট নেওয়া যাবে।",
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (ref.watch(appStateProvider).isLoading)
            const LinearProgressIndicator(
              color: Color(0xFFFF751F),
              backgroundColor: Colors.white,
            ),
        ],
      ),
    );
  }

  void _showFilteredPayments(String title, List<dynamic> Function() getPayments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, bottomSheetSetState) {
            final payments = getPayments();
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
                              return _buildApprovalCard(payments[index], onSuccess: () {
                                bottomSheetSetState(() {});
                              });
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _fetchPendingApprovals();
      _fetchDeptDues();
    });
  }

  Widget _buildDeptDuesPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8), // Adds breathing room before TabBar
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header - Layout fixed to align Amount correctly
          InkWell(
            onTap: () => setState(() => _deptExpanded = !_deptExpanded),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF1B8C4E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "বিভাগ ভিত্তিক বকেয়া",
                          style: TextStyle(
                            color: Color(0xFF2D3436),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "বকেয়া ও সংগ্রহের বিবরণী",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_deptLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Color(0xFF1B8C4E), strokeWidth: 2.5),
                    )
                  else ...[
                    // Custom Bordered Badge for amount
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B8C4E).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1B8C4E).withValues(alpha: 0.3), width: 1.2),
                      ),
                      child: Text(
                        "৳${_grandTotalDue.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Color(0xFF1B8C4E),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible body
          if (_deptExpanded)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 20),
                child: Column(
                  children: [
                    // Overview Chips matching Home screen green/blue theme
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            Icons.people_alt_rounded,
                            "${_deptDues.fold<int>(0, (s, d) => s + (d['student_count'] as int? ?? 0))} জন",
                            "বকেয়া শিক্ষার্থী",
                            Colors.green.shade50,
                            textColor: const Color(0xFF1B8C4E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            Icons.check_circle_rounded,
                            "$_grandApprovedToday জন",
                            "আজ অনুমোদিত",
                            Colors.blue.shade50,
                            textColor: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Department Lists
                    if (_deptDues.isEmpty && !_deptLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text("কোনো বকেয়া পাওয়া যায়নি",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      )
                    else
                      ..._deptDues.map((d) {
                        final double due = (d['total_due'] ?? 0).toDouble();
                        final double ratio = _grandTotalDue > 0 ? due / _grandTotalDue : 0;
                        final int pending = d['pending_approval'] ?? 0;

                        return InkWell(
                          onTap: () {
                            if (pending > 0) {
                              _showFilteredPayments(
                                "${d['name']} এর বকেয়া",
                                () => _pendingList.where((p) => p['department_name'] == d['name']).toList(),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade100, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      d['name'] ?? '',
                                      style: const TextStyle(
                                          color: Color(0xFF2D3436),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (pending > 0)
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.orange.shade100),
                                          ),
                                          child: Text(
                                            "$pending বাকি",
                                            style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      Text(
                                        "৳${due.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            color: Color(0xFF2D3436),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Real dynamic progress bar using LayoutBuilder with premium green gradient
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      Container(
                                        height: 6,
                                        width: constraints.maxWidth * ratio.clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF1B8C4E), Colors.greenAccent],
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ));
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color bgColor, {Color textColor = Colors.black}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: const Color(0xFFFF751F).withValues(alpha: 0.8), size: 56),
              ),
              const SizedBox(height: 16),
              const Text(
                "অনুমোদনের অপেক্ষায় কিছু নেই",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF751F)),
              ),
              const SizedBox(height: 8),
              Text(
                "সব কালেকশন অনুমোদিত হয়েছে",
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlatPendingList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = _pendingList[index];
        return _buildApprovalCard(p);
      },
    );
  }

  Widget _buildGroupedPendingList() {
    // Group payments by agent_name
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in _pendingList) {
      final agentName = (p['agent_name'] ?? 'অজানা এজেন্ট') as String;
      grouped.putIfAbsent(agentName, () => []);
      grouped[agentName]!.add(Map<String, dynamic>.from(p));
    }

    final agentNames = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agentNames.length,
      itemBuilder: (context, groupIndex) {
        final agentName = agentNames[groupIndex];
        final payments = grouped[agentName]!;
        final totalAmount = payments.fold<double>(
          0, (sum, p) => sum + (p['amount'] as num).toDouble(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupIndex > 0) const SizedBox(height: 16),
            // Agent Group Header
            InkWell(
              onTap: () {
                _showFilteredPayments(
                  "$agentName এর সংগ্রহ",
                  () => _pendingList.where((p) => (p['agent_name'] ?? 'অজানা এজেন্ট') == agentName).toList(),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade50.withValues(alpha: 0.3)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_rounded, color: Colors.blue.shade700, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${payments.length}টি পেমেন্ট • মোট ৳${totalAmount.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (payments.length > 1)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmBulkApproval(agentName, payments, onSuccess: () => setState(() {})),
                        icon: const Icon(Icons.done_all_rounded, size: 14),
                        label: const Text("সব অনুমোদন",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> p, {VoidCallback? onSuccess}) {
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
                    p['student']['name'] ?? '',
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
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "আইডি: ${p['student']['student_id']}",
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
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: Colors.grey.shade500),
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
                ElevatedButton.icon(
                  onPressed: () => _confirmApproval(p, onSuccess: onSuccess),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text("অনুমোদন",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF751F),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
