import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/app_state.dart';

class CollectScreen extends ConsumerStatefulWidget {
  const CollectScreen({super.key});

  @override
  ConsumerState<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends ConsumerState<CollectScreen> {
  
  void _confirmCollection(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Styled visual top icon inside dialog
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF751F).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFFF751F),
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "পেমেন্ট নিশ্চিতকরণ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF636E72)),
                children: [
                  const TextSpan(text: "আপনি কি নিশ্চিত যে "),
                  TextSpan(
                    text: "'${ref.read(appStateProvider).activeStudent?['name']}'",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const TextSpan(text: " এর থেকে "),
                  TextSpan(
                    text: "'${payment['label']}'",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF751F)),
                  ),
                  const TextSpan(text: " বাবদ "),
                  TextSpan(
                    text: "৳${payment['amount']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 16),
                  ),
                  const TextSpan(text: " নগদ বুঝে পেয়েছেন?"),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    "বাতিল",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleCollection(payment['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF751F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "হ্যাঁ, পেয়েছি",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCollection(int paymentId) async {
    try {
      await ref.read(appStateProvider).collectCash(paymentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("পেমেন্ট সফলভাবে গ্রহণ করা হয়েছে!"), backgroundColor: Colors.green),
        );
        // Go back if no more active payments
        if (ref.read(appStateProvider).activePayments.isEmpty) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("ত্রুটি", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ঠিক আছে"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final student = appState.activeStudent;
    final payments = appState.activePayments;
    final paidPayments = appState.paidPayments;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("পেমেন্ট সংগ্রহ"),
        backgroundColor: const Color(0xFFFF751F), // App Branding Color
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            ref.read(appStateProvider).clearActiveStudent();
            Navigator.pop(context);
          },
        ),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (student == null) {
            return const Center(child: Text("কোনো শিক্ষার্থীর ডেটা সিলেক্ট করা নেই।"));
          }

          final String initialLetter = (student['name'] as String).isNotEmpty ? (student['name'] as String).substring(0, 1) : '?';
          final String? photoUrl = student['avatar'] ?? student['profile_photo_url'];

          return Column(
            children: [
              // Premium Student Profile Card Block (Clean Light Redesigned Layout)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Photo with loading & fallback gradient
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF751F), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(initialLetter),
                                  )
                                : _buildAvatarFallback(initialLetter),
                          ),
                        ),
                        const SizedBox(width: 14),
                        
                        // Metadata aligned
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? '',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF751F),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "আইডি: ${student['student_id']}",
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.class_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "বিভাগ: ${student['department']}",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    student['mobile'] ?? 'নির্ধারিত নয়',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 12),

                    // Inlined Parent Info Tags
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.family_restroom_rounded, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "পিতা: ${student['father_name'] ?? '—'}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "মাতা: ${student['mother_name'] ?? '—'}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Dues & Paid Payments Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pending Dues List Section
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
                                SizedBox(height: 12),
                                Text(
                                  "কোনো বকেয়া বিল পাওয়া যায়নি!",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              child: Text(
                                "বকেয়া পরিশোধের তালিকা",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                              itemCount: payments.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final p = payments[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade200.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['label'] ?? '',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      p['type'] == 'monthly' ? 'মাসিক ফি' : p['type'] == 'admission' ? 'ভর্তি ফি' : 'অন্যান্য',
                                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  if (p['period'] != null) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "সময়কাল: " + p['period'].toString(),
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "৳" + p['amount'].toString(),
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton(
                                              onPressed: () => _confirmCollection(p),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF751F),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                minimumSize: Size.zero,
                                                elevation: 0,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text("সংগ্রহ করুন", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                      // Paid Payments Section
                      if (paidPayments.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 14.0),
                              child: Text(
                                "পরিশোধিত পেমেন্টসমূহ",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                              itemCount: paidPayments.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final p = paidPayments[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p['label'] ?? '',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      p['type'] == 'monthly' ? 'মাসিক ফি' : p['type'] == 'admission' ? 'ভর্তি ফি' : 'অন্যান্য',
                                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  if (p['period'] != null) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "সময়কাল: " + p['period'].toString(),
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "৳" + p['amount'].toString(),
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              p['paid_at'] != null ? "পরিশোধ: " + p['paid_at'].toString() : "পরিশোধিত",
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              if (appState.isLoading)
                const LinearProgressIndicator(color: Color(0xFFFF751F)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF751F), Color(0xFFFF9F43)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
