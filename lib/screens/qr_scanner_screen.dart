import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/app_state.dart';
import 'collect_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  final int? initialDepartmentId;

  const QrScannerScreen({super.key, this.initialDepartmentId});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;
  String _scanMode = 'payment'; // 'attendance' or 'payment' — default: payment
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  
  // OSD Overlay States
  bool _showSuccessOverlay = false;
  bool _showErrorOverlay = false;
  String _overlayMessage = '';
  String _studentName = '';
  String _studentIdVal = '';
  String? _studentPhotoUrl;

  @override
  void initState() {
    super.initState();
    // যদি হাজিরা ট্যাব থেকে স্ক্যানার ওপেন হয়, তাহলে attendance মোড সেট করো
    if (widget.initialDepartmentId != null) {
      _scanMode = 'attendance';
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }



  void _showAttendanceSuccessPopup(Map<String, dynamic>? student) {
    setState(() {
      _showSuccessOverlay = true;
      if (student != null) {
        _studentName = student['name'] ?? '';
        _studentIdVal = student['student_id'] ?? '';
        _studentPhotoUrl = student['photo_url'];
      } else {
        _studentName = 'অফলাইন হাজিরা';
        _studentIdVal = _lastScannedCode ?? '';
        _studentPhotoUrl = null;
      }
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccessOverlay = false;
          _isProcessing = false;
        });
        _cameraController.start();
      }
    });
  }

  void _showAttendanceErrorPopup(String message) {
    setState(() {
      _showErrorOverlay = true;
      _overlayMessage = message;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showErrorOverlay = false;
          _isProcessing = false;
        });
        _cameraController.start();
      }
    });
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    // Debouncing: Ignore identical scans within 3 seconds
    final DateTime now = DateTime.now();
    if (_lastScannedCode == code && _lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 3) {
      debugPrint("--- LOG: Duplicate scan ignored for code=$code ---");
      return;
    }
    _lastScannedCode = code;
    _lastScanTime = now;

    setState(() {
      _isProcessing = true;
    });

    // Pause camera scanning during API lookup
    _cameraController.stop();

    if (_scanMode == 'payment') {
      try {
        await ref.read(appStateProvider).searchStudent(code);
        if (mounted) {
          // Direct replace to CollectScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const CollectScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
              _cameraController.start();
            }
          });
        }
      }
    } else {
      // Attendance Scanning Mode
      try {
        int departmentId = 1; // Default fallback to KIDS
        final int? initialDept = widget.initialDepartmentId;
        if (initialDept != null) {
          departmentId = initialDept;
        } else {
          final user = ref.read(appStateProvider).currentUser;
          if (user != null && user['allowed_departments'] != null && user['allowed_departments'].isNotEmpty) {
            departmentId = user['allowed_departments'][0]['id'] as int;
          }
        }

        final response = await ref.read(appStateProvider).submitAttendance(code, departmentId);
        
        // Success haptic feedback
        HapticFeedback.lightImpact();

        if (mounted) {
          _showAttendanceSuccessPopup(response['student']);
        }
      } catch (e) {
        // Error haptic feedback
        HapticFeedback.heavyImpact();

        if (mounted) {
          _showAttendanceErrorPopup(e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR কোড স্ক্যান করুন"),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, _) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  default:
                    return const Icon(Icons.flash_off);
                }
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          
          // Mode Toggle Switcher at the top of the scanner (Hidden for admin/officers)
          if (ref.watch(appStateProvider).currentUser != null &&
              ref.watch(appStateProvider).currentUser!['role'] != 'admin' &&
              ref.watch(appStateProvider).currentUser!['role'] != 'account_officer')
            Positioned(
              top: 20,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _scanMode = 'attendance';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _scanMode == 'attendance' ? const Color(0xFFFF751F) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.assignment_ind_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text("হাজিরা মোড", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _scanMode = 'payment';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _scanMode == 'payment' ? const Color(0xFFFF751F) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.payment_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text("পেমেন্ট মোড", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Scanner Overlay Target Frame
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF751F), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          // Scanner Help Note
          Positioned(
            bottom: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _scanMode == 'attendance'
                    ? "শিক্ষার্থীর আইডি কার্ডের QR কোডটি স্ক্যান করে হাজিরা নিন"
                    : "শিক্ষার্থীর আইডি কার্ডের QR কোডটি স্ক্যান করে পেমেন্টে যান",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          
          if (_isProcessing && !_showSuccessOverlay && !_showErrorOverlay)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF751F))),
                    SizedBox(height: 16),
                    Text(
                      "শিক্ষার্থীর তথ্য লোড হচ্ছে...",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ),

          // Attendance Success OSD Overlay Popup
          if (_showSuccessOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 72),
                          const SizedBox(height: 16),
                          const Text(
                            "হাজিরা গৃহীত হয়েছে",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 16),
                          if (_studentPhotoUrl != null && _studentPhotoUrl!.isNotEmpty)
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(_studentPhotoUrl!),
                            )
                          else
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey.shade100,
                              child: const Icon(Icons.person, size: 40, color: Colors.grey),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _studentName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "আইডি: $_studentIdVal",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Attendance Error OSD Overlay Popup
          if (_showErrorOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_outlined, color: Colors.red.shade600, size: 72),
                          const SizedBox(height: 16),
                          const Text(
                            "হাজিরা ব্যর্থ",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _overlayMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF636E72), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
