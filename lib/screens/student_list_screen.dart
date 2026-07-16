import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/app_state.dart';
import 'collect_screen.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  final String status; // 'all', 'paid', 'due'
  final String title;
  final bool showAppBar;
  final String search; // Global search query passed from parent

  const StudentListScreen({
    super.key,
    required this.status,
    required this.title,
    this.showAppBar = true,
    this.search = "",
  });

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _students = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  bool _isLoadingInitial = true;
  String _currentSearch = "";

  @override
  void initState() {
    super.initState();
    _currentSearch = widget.search;
    _fetchStudents(initial: true);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didUpdateWidget(covariant StudentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the global search query from parent changes, reload lists
    if (oldWidget.search != widget.search) {
      _currentSearch = widget.search;
      _fetchStudents(initial: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasNextPage) {
        _fetchStudents(initial: false);
      }
    }
  }

  Future<void> _fetchStudents({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoadingInitial = true;
        _currentPage = 1;
        _hasNextPage = true;
        _students = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ref.read(appStateProvider).fetchAgentStudents(
        status: widget.status,
        page: _currentPage,
        search: _currentSearch,
      );

      final List<dynamic> fetchedList = response['data'] ?? [];
      final String? nextPageUrl = response['next_page_url'];

      setState(() {
        _currentPage++;
        _students.addAll(fetchedList);
        _hasNextPage = nextPageUrl != null;
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ডাটা লোড করতে ব্যর্থ: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: widget.showAppBar 
          ? AppBar(
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              backgroundColor: const Color(0xFF1A1A2E), 
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _fetchStudents(initial: true),
        color: const Color(0xFFFF751F),
        child: _buildListContent(),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF751F)),
      );
    }

    if (_students.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      itemCount: _students.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _students.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF751F)),
              ),
            ),
          );
        }

        final student = _students[index];
        final num rawDue = student['total_due'] ?? 0;
        final double dueAmount = rawDue.toDouble();
        final bool isPaid = dueAmount <= 0.0;
        
        final String studentName = student['name'] ?? 'শিক্ষার্থী';
        final String initialLetter = studentName.isNotEmpty ? studentName.substring(0, 1) : '?';
        final String? photoUrl = student['profile_photo_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openStudentDetails(student),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    // Premium Avatar with Network Image / Gradient Fallback support
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(initialLetter),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF751F)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _buildAvatarFallback(initialLetter),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info stacked metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600, 
                              fontSize: 15, 
                              color: Color(0xFF2C3E50), 
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "আইডি: ${student['student_id'] ?? '-'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11, 
                              color: Colors.grey.shade500, 
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Horizontal Inline visual Due/Paid Amount or Status Label
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  "পরিশোধিত",
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "৳${dueAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  "বকেয়া",
                                  style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_alt_outlined, size: 54, color: Colors.orange.shade300),
              ),
              const SizedBox(height: 18),
              const Text(
                "কোনো শিক্ষার্থী পাওয়া যায়নি",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 8),
              Text(
                "আপনার অনুমোদিত বিভাগ বা ক্যাটাগরির জন্য এই মুহূর্তে তথ্য খালি রয়েছে।",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudentDetails(dynamic student) async {
    ref.read(appStateProvider).clearActiveStudent();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF751F)),
        ),
      );
      
      await ref.read(appStateProvider).searchStudent(student['student_id']);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CollectScreen(),
          ),
        ).then((_) {
          _fetchStudents(initial: true);
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("পেমেন্ট তথ্য ওপেন করতে ব্যর্থ: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
