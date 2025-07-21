// lib/screen/main_scaffold.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:makkal_sevai_guide/screen/service_finder.dart';
import 'package:makkal_sevai_guide/widget/app_drawer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

// Main screen that holds the state for language and the scaffold structure.
class MainScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool hasSeenInitialDisclaimer; // New property
  const MainScreen({
    super.key,
    required this.onThemeChanged,
    required this.hasSeenInitialDisclaimer, // Require new property
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isEnglish = true;
  final String _campaignUrl = 'https://ungaludanstalin.tn.gov.in/camp.php';

  @override
  void initState() {
    super.initState();
    // Show disclaimer if not seen, after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.hasSeenInitialDisclaimer) {
        _showInitialDisclaimerDialog(context);
      }
    });
  }

  void _toggleLanguage() {
    final String oldLanguage = _isEnglish ? 'English' : 'Tamil';
    setState(() {
      _isEnglish = !_isEnglish;
    });
    final String newLanguage = _isEnglish ? 'English' : 'Tamil';

    FirebaseAnalytics.instance.logEvent(
      name: 'language_switched',
      parameters: {
        'from_language': oldLanguage,
        'to_language': newLanguage,
      },
    );
  }

  // Full-screen disclaimer dialog for initial launch (moved here)
  void _showInitialDisclaimerDialog(BuildContext context) {
    FirebaseAnalytics.instance.logEvent(
      name: 'initial_disclaimer_opened',
      parameters: {
        'language': Localizations.localeOf(context).languageCode == 'ta' ? 'Tamil' : 'English',
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false, // User must acknowledge
      builder: (BuildContext dialogContext) {
        return PopScope( // Prevent back button dismissal
          canPop: false,
          child: AlertDialog(
            title: Text(
              Localizations.localeOf(context).languageCode == 'ta' ? "முக்கிய அறிவிப்பு" : "Important Disclaimer",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Localizations.localeOf(context).languageCode == 'ta'
                        ? "இது ஒரு அதிகாரப்பூர்வமற்ற செயலி. இது அரசு சேவைகளை மக்கள் எளிதாகப் புரிந்துகொள்ள உதவும் நோக்கில் உருவாக்கப்பட்டது. இது தமிழ்நாடு அரசு அல்லது எந்த அரசு நிறுவனத்துடனும் இணைக்கப்படவில்லை, அங்கீகரிக்கப்படவில்லை அல்லது தொடர்புடையது அல்ல."
                        : "This is an UNOFFICIAL APPLICATION developed to help citizens navigate government services. It is NOT AFFILIATED WITH, ENDORSED BY, OR CONNECTED TO THE GOVERNMENT OF TAMIL NADU OR ANY GOVERNMENT ENTITY.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Localizations.localeOf(context).languageCode == 'ta'
                        ? "அனைத்து தகவல்களும் அதிகாரப்பூர்வ 'உங்களுடன் ஸ்டாலின்' இணையதளத்தில் (ungaludanstalin.tn.gov.in) இருந்து பெறப்பட்டவை. தகவல்களை அதிகாரப்பூர்வ மூலங்களுடன் சரிபார்க்குமாறு கேட்டுக்கொள்கிறோம்."
                        : "All information is sourced from the official 'Ungaludan Stalin' website (ungaludanstalin.tn.gov.in). We strongly encourage you to verify details with official government sources.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ta' ? "புரிந்துகொண்டேன்" : "I Understand",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenDisclaimer', true);
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    // Analytics for Initial Disclaimer Dialog Closed
                    FirebaseAnalytics.instance.logEvent(
                      name: 'initial_disclaimer_closed',
                      parameters: {
                        'language': Localizations.localeOf(context).languageCode == 'ta' ? 'Tamil' : 'English',
                      },
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String url, String linkName) async {
    bool? confirmLaunch = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _isEnglish ? "Leaving App" : "பயன்பாட்டிலிருந்து வெளியேறுகிறது",
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEnglish
                      ? "You are about to leave the Makkal Sevai Guide app and will be directed to an external website:"
                      : "நீங்கள் மக்கள் சேவை வழிகாட்டி பயன்பாட்டிலிருந்து வெளியேற உள்ளீர்கள், மேலும் ஒரு வெளிப்புற இணையதளத்திற்குத் திருப்பி விடப்படுவீர்கள்:",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  _isEnglish
                      ? "Please be aware that this external site is not controlled by Makkal Sevai Guide, and its privacy policy may differ."
                      : "இந்த வெளிப்புற தளம் மக்கள் சேவை வழிகாட்டியால் கட்டுப்படுத்தப்படவில்லை என்பதையும், அதன் தனியுரிமைக் கொள்கை வேறுபடலாம் என்பதையும் கவனத்தில் கொள்ளவும்.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 0.9 * Theme.of(context).textTheme.bodyMedium!.fontSize!),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(_isEnglish ? "Cancel" : "ரத்துசெய்"),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
                FirebaseAnalytics.instance.logEvent(
                  name: 'external_link_launch_cancelled',
                  parameters: {
                    'link_name': linkName,
                    'url': url,
                    'language': _isEnglish ? 'English' : 'Tamil',
                  },
                );
              },
            ),
            TextButton(
              child: Text(_isEnglish ? "Proceed" : "தொடரவும்"),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmLaunch == true) {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEnglish ? 'Could not open the link.' : 'இணைப்பைத் திறக்க முடியவில்லை.'),
            ),
          );
        }
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
          onLaunchURL: _launchURL, // Pass the _launchURL function
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _launchURL(_campaignUrl, 'camp_schedule_fab'),
          label: Text(_isEnglish ? 'Camp Schedule' : 'முகாம் அட்டவணை'),
          icon: const Icon(Icons.public),
          tooltip: _isEnglish ? 'Visit Ungaludan Stalin Camp Schedule' : 'உங்களுடன் ஸ்டாலின் முகாம் அட்டவணையைப் பார்வையிடவும்',
        ),
        body: ServiceFinderScreen(isEnglish: _isEnglish),
      ),
    );
  }
}