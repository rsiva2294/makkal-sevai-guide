import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:makkal_sevai_guide/screen/department_overview.dart';
import 'package:url_launcher/url_launcher.dart';

// Navigation Drawer Widget
class AppDrawer extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool isEnglish;

  const AppDrawer({super.key, required this.onThemeChanged, required this.isEnglish});

  // Define the campaign URL here as it's used directly in the drawer
  final String _campaignUrl = 'https://ungaludanstalin.tn.gov.in/camp.php';

  Future<void> _launchURL(String url, String linkName) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Log failure to launch URL
      FirebaseAnalytics.instance.logEvent(
        name: 'url_launch_failed',
        parameters: {
          'url': url,
          'reason': 'could_not_launch',
          'link_name': linkName,
          'language': isEnglish ? 'English' : 'Tamil',
        },
      );
      throw 'Could not launch $url'; // Rethrow to be caught by PlatformDispatcher
    } else {
      // Analytics for Successful URL Launches from Drawer
      FirebaseAnalytics.instance.logEvent(
        name: 'external_link_clicked',
        parameters: {
          'link_name': linkName,
          'url': url,
          'language': isEnglish ? 'English' : 'Tamil',
        },
      );
    }
  }

  void _showDisclaimerDialog(BuildContext context) {
    // Analytics for Disclaimer Dialog Opened
    FirebaseAnalytics.instance.logEvent(
      name: 'disclaimer_dialog_opened',
      parameters: {
        'language': isEnglish ? 'English' : 'Tamil',
      },
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEnglish ? "Disclaimer" : "பொறுப்புத் துறப்பு"),
          content: SingleChildScrollView(
            child: Text(
                isEnglish
                    ? "This is an unofficial application designed to work offline. It acts as a simple guide to the services offered under the 'Ungaludan Stalin' scheme, aiming to improve usability and overcome language barriers.\n\nAll data is sourced from the official 'Ungaludan Stalin' website as of July 18, 2025.\n\nThis app is not affiliated with, endorsed by, or connected to any government entity."
                    : "இது ஒரு அதிகாரப்பூர்வமற்ற, இணைய இணைப்பு இல்லாமலும் செயல்படும் செயலி. 'உங்களுடன் ஸ்டாலின்' திட்டத்தின் கீழ் வழங்கப்படும் சேவைகளுக்கு ஒரு எளிய வழிகாட்டியாக செயல்படும் வகையில், பயன்பாட்டினை எளிதாக்கவும் மற்றும் மொழித் தடைகளை நீக்கவும் இது வடிவமைக்கப்பட்டுள்ளது.\n\nஅனைத்து தரவுகளும் அதிகாரப்பூர்வ 'உங்களுடன் ஸ்டாலின்' இணையதளத்தில் இருந்து ஜூலை 18, 2025 தேதியின்படி பெறப்பட்டவை.\n\nஇந்த செயலி எந்தவொரு அரசாங்க நிறுவனத்துடனும் இணைக்கப்படவில்லை, அங்கீகரிக்கப்படவில்லை அல்லது தொடர்புடையது அல்ல."
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(isEnglish ? "Close" : "மூடுக"),
              onPressed: () {
                Navigator.of(context).pop();
                // Analytics for Disclaimer Dialog Closed
                FirebaseAnalytics.instance.logEvent(
                  name: 'disclaimer_dialog_closed',
                  parameters: {
                    'language': isEnglish ? 'English' : 'Tamil',
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              image: DecorationImage(
                image: const AssetImage('assets/icon/logo.png'),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                opacity: 0.85,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                  BlendMode.modulate,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEnglish ? 'Makkal Sevai Guide' : 'மக்கள் சேவை வழிகாட்டி',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(isEnglish ? 'Dark Mode' : 'இருண்ட பயன்முறை'),
            value: isDark,
            onChanged: (bool value) {
              final String oldTheme = isDark ? 'Dark' : 'Light';
              final String newTheme = value ? 'Dark' : 'Light';
              onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);

              // Analytics for Theme Switch
              FirebaseAnalytics.instance.logEvent(
                name: 'theme_switched',
                parameters: {
                  'from_theme': oldTheme,
                  'to_theme': newTheme,
                  'language': isEnglish ? 'English' : 'Tamil',
                },
              );
            },
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          const Divider(),
          // New: Camp Schedule option in the drawer
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(isEnglish ? 'Camp Schedule' : 'முகாம் அட்டவணை'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              _launchURL(_campaignUrl, 'camp_schedule_drawer'); // Use the same URL as FAB, with a distinct linkName for analytics
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(isEnglish ? 'Open Brochure' : 'வளையலை திறக்க'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DepartmentOverviewScreen(isEnglish: isEnglish),
                ),
              );
              // Analytics for Brochure Screen Access
              FirebaseAnalytics.instance.logEvent(
                name: 'brochure_screen_accessed',
                parameters: {
                  'language': isEnglish ? 'English' : 'Tamil',
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(isEnglish ? 'Disclaimer' : 'பொறுப்புத் துறப்பு'),
            onTap: () {
              Navigator.pop(context);
              _showDisclaimerDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(isEnglish ? 'About the Developer' : 'டெவலப்பர் பற்றி'),
            onTap: () => _launchURL('https://www.linkedin.com/in/sivakaminathan-muthusamy/', 'developer_profile'), // Pass linkName
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(isEnglish ? 'Rate this App' : 'செயலியை மதிப்பிடுக'),
            onTap: () {
              _launchURL('https://play.google.com/store/apps/details?id=in.smstraders.makkalsevaiguide.makkal_sevai_guide', 'rate_app'); // Pass linkName
            },
          ),
        ],
      ),
    );
  }
}