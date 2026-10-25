import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update.dart';
import '../controllers/update_controller.dart';

void showUpdateDialog(BuildContext context, AppUpdate update) {
  showDialog(
    context: context,
    barrierDismissible: !update.isForce,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  update.isForce ? Icons.lock_outline : Icons.system_update_outlined,
                  size: 40,
                  color: update.isForce ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                ),
                const SizedBox(height: 16),
                Text(
                  update.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Version ${update.version}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
                if (update.releaseNotes != null && update.releaseNotes!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "What's new",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      update.releaseNotes!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
                if (update.isForce) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "You need to update to keep using the app.",
                      style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = update.apkUrl;
                      if (url.isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text("No download link available.")),
                          );
                        }
                        return;
                      }
                      try {
                        final uri = Uri.parse(url);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("Error opening link: $e")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: update.isForce ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Update Now", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (!update.isForce) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: TextButton(
                      onPressed: () {
                        UpdateController.instance.markDismissed();
                        Navigator.pop(ctx);
                      },
                      child: Text("Later", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
