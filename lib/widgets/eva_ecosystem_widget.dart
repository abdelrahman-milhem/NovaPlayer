import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EvaEcosystemWidget extends StatelessWidget {
  const EvaEcosystemWidget({super.key});

  Future<void> _launchAppOrStore(
    String customScheme,
    String packageName,
    String storeUrl,
  ) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Using Android Intent to open the app or fallback to the store
        final intentUrl =
            'intent://open#Intent;package=$packageName;scheme=https;end;';
        final Uri intentUri = Uri.parse(intentUrl);

        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final Uri appUri = Uri.parse(customScheme);
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    } catch (e) {
      debugPrint('Could not launch app directly: $e');
    }

    // Fallback to store if the direct app launch fails, or if it's Windows/Web
    try {
      final Uri storeUri = Uri.parse(storeUrl);
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey[800];
    final iconBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[200];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أيضًا من Eva',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8.0,
            runSpacing: 16.0,
            children: [
              _buildAppItem(
                appName: 'Stylora',
                imageAsset: 'assets/eva_apps/stylora.png',
                iconBgColor: iconBgColor,
                textColor: textColor,
                onTap: () => _launchAppOrStore(
                  'stylora://',
                  'com.eva.stylora',
                  'https://play.google.com/store/apps/details?id=com.eva.stylora',
                ),
              ),
              _buildAppItem(
                appName: 'Crypta',
                imageAsset: 'assets/eva_apps/crypta.png',
                iconBgColor: iconBgColor,
                textColor: textColor,
                onTap: () => _launchAppOrStore(
                  'crypta://',
                  'com.eva.crypta',
                  'https://play.google.com/store/apps/details?id=com.eva.crypta',
                ),
              ),
              _buildAppItem(
                appName: 'Waseet',
                imageAsset: 'assets/eva_apps/waseet.png',
                iconBgColor: iconBgColor,
                textColor: textColor,
                onTap: () => _launchAppOrStore(
                  'waseet://',
                  'com.eva.waseet',
                  'https://play.google.com/store/apps/details?id=com.eva.waseet',
                ),
              ),
              _buildAppItem(
                appName: 'NovaPlayer',
                imageAsset: 'assets/eva_apps/zenora.png',
                iconBgColor: iconBgColor,
                textColor: textColor,
                onTap: () => _launchAppOrStore(
                  'novaplayer://',
                  'com.eva.novaplayer',
                  'https://play.google.com/store/apps/details?id=com.eva.novaplayer',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem({
    required String appName,
    required String imageAsset,
    required Color? iconBgColor,
    required Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.apps, color: textColor);
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(appName, style: TextStyle(fontSize: 12, color: textColor)),
          ],
        ),
      ),
    );
  }
}
