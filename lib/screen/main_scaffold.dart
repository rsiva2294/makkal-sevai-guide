import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:makkal_sevai_guide/screen/service_finder.dart';
import 'package:makkal_sevai_guide/widget/app_drawer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

// Main screen that holds the state for language and the scaffold structure.
class MainScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  const MainScreen({super.key, required this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isEnglish = true;
  final String _campaignUrl = 'https://ungaludanstalin.tn.gov.in/camp.php';

  void _toggleLanguage() {
    final String oldLanguage = _isEnglish ? 'English' : 'Tamil';
    setState(() {
      _isEnglish = !_isEnglish;
    });
    final String newLanguage = _isEnglish ? 'English' : 'Tamil';

    // Analytics for Language Switch
    FirebaseAnalytics.instance.logEvent(
      name: 'language_switched',
      parameters: {
        'from_language': oldLanguage,
        'to_language': newLanguage,
      },
    );
  }

  Future<void> _launchURL(String url, String linkName) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish ? 'Could not open the link.' : 'இணைப்பைத் திறக்க முடியவில்லை.'),
          ),
        );
      }
      // Log failure to launch URL
      FirebaseAnalytics.instance.logEvent(
        name: 'url_launch_failed',
        parameters: {
          'url': url,
          'reason': 'could_not_launch',
          'link_name': linkName,
          'language': _isEnglish ? 'English' : 'Tamil',
        },
      );
    } else {
      // Analytics for Successful URL Launch (Camp Schedule)
      FirebaseAnalytics.instance.logEvent(
        name: 'external_link_clicked',
        parameters: {
          'link_name': linkName,
          'url': url,
          'language': _isEnglish ? 'English' : 'Tamil',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEnglish ? 'Makkal Sevai Guide' : 'மக்கள் சேவை வழிகாட்டி'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _toggleLanguage,
              child: Text(
                _isEnglish ? 'தமிழ்' : 'English',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: AppDrawer(
          onThemeChanged: widget.onThemeChanged,
          isEnglish: _isEnglish,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _launchURL(_campaignUrl, 'camp_schedule'), // Pass linkName
          label: Text(_isEnglish ? 'Camp Schedule' : 'முகாம் அட்டவணை'),
          icon: const Icon(Icons.public),
          tooltip: _isEnglish ? 'Visit Ungaludan Stalin Camp Schedule' : 'உங்களுடன் ஸ்டாலின் முகாம் அட்டவணையைப் பார்வையிடவும்',
        ),
        body: ServiceFinderScreen(isEnglish: _isEnglish),
      ),
    );
  }
}