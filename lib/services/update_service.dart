import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  static const String _githubRepo = 'SaifulMamunOfficial/Saimum-Agent-App';
  static const String _apiUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool showNoUpdateMessage = false,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.get(_apiUrl);

      if (response.statusCode == 200) {
        final latestVersionTag = response.data['tag_name'] as String;
        // GitHub tags usually have a 'v' prefix, e.g., 'v1.0.1'
        final latestVersion = latestVersionTag.replaceAll('v', '');

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isUpdateAvailable(currentVersion, latestVersion)) {
          final apkAsset = (response.data['assets'] as List).firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null) {
            final downloadUrl = apkAsset['browser_download_url'];
            final releaseNotes =
                response.data['body'] ?? 'নতুন আপডেট পাওয়া গেছে।';

            if (context.mounted) {
              _showUpdateDialog(
                context,
                latestVersion,
                releaseNotes,
                downloadUrl,
              );
            }
          } else if (showNoUpdateMessage && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('আপনার অ্যাপটি আপ-টু-ডেট আছে।'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (showNoUpdateMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('আপনার অ্যাপটি আপ-টু-ডেট আছে।'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        if (showNoUpdateMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('আপনার অ্যাপটি আপ-টু-ডেট আছে।'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (showNoUpdateMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'আপডেট চেক করতে সমস্যা হয়েছে। ইন্টারনেট কানেকশন চেক করুন।',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('Update check failed: $e');
      }
    } catch (e) {
      if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('আপডেট চেক করতে সমস্যা হয়েছে।'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Update check error: $e');
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    // Strip build numbers if present (e.g., 1.0.0+1 -> 1.0.0)
    String currentClean = current.split('+')[0].trim();
    String latestClean = latest.split('+')[0].trim();

    List<int> currentParts = currentClean.split('.').map(int.parse).toList();
    List<int> latestParts = latestClean.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String releaseNotes,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'নতুন আপডেট! (v$version)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'অ্যাপের একটি নতুন ভার্সন পাওয়া গেছে। অনুগ্রহ করে আপডেট করুন।',
                ),
                const SizedBox(height: 12),
                Text(
                  'রিলিজ নোট:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(releaseNotes, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('পরে', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF751F),
              ),
              onPressed: () {
                Navigator.pop(context);
                _downloadAndInstallUpdate(context, downloadUrl, version);
              },
              child: const Text(
                'আপডেট করুন',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstallUpdate(
    BuildContext context,
    String url,
    String version,
  ) async {
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('স্টোরেজ পারমিশন দেওয়া হয়নি!')),
        );
      }
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DownloadProgressDialog(),
    );

    try {
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir?.path}/update_v$version.apk';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _DownloadProgressDialog.progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // close dialog
      }

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ইন্সটল করতে ব্যর্থ: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ডাউনলোড ব্যর্থ: $e')));
      }
    }
  }

  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      final installStatus = await Permission.requestInstallPackages.request();
      return status.isGranted || installStatus.isGranted;
    }
    return true;
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  static final ValueNotifier<double> progressNotifier = ValueNotifier<double>(
    0.0,
  );

  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ডাউনলোড হচ্ছে...'),
      content: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFFFF751F),
              ),
              const SizedBox(height: 10),
              Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          );
        },
      ),
    );
  }
}
