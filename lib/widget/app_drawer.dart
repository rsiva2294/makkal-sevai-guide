import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:makkal_sevai_guide/screen/department_overview.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool isEnglish;
  final Future<void> Function(String url, String linkName) onLaunchURL; // New callback

  const AppDrawer({
    super.key,
    required this.onThemeChanged,
    required this.isEnglish,
    required this.onLaunchURL, // Require the new callback
  });

  final String _campaignUrl = 'https://ungaludanstalin.tn.gov.in/camp.php';

  // Remove the _launchURL method from AppDrawer, as it's now passed in.
  // Future<void> _launchURL(String url, String linkName) async { ... }

  void _showDisclaimerDialog(BuildContext context) {
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
            padding: const EdgeInsets.all(16.0),
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
              alignment: Alignment.bottomLeft,
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
          // Camp Schedule option in the drawer
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(isEnglish ? 'Camp Schedule' : 'முகாம் அட்டவணை'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onLaunchURL(_campaignUrl, 'camp_schedule_drawer'); // Use the passed callback
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(isEnglish ? 'Open Brochure' : 'வளையலை திறக்க'),
            onTap: () {
              Navigator.pop(context);
              // For DepartmentOverviewScreen, you might not want the extra confirmation
              // as it's an internal screen that then launches external.
              // If DepartmentOverviewScreen itself launches URLs, it should implement its own _launchURL with confirmation.
              // For now, we'll just navigate directly.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DepartmentOverviewScreen(isEnglish: isEnglish),
                ),
              );
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
            onTap: () => onLaunchURL('https://www.linkedin.com/in/sivakaminathan-muthusamy/', 'developer_profile'), // Use the passed callback
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(isEnglish ? 'Rate this App' : 'செயலியை மதிப்பிடுக'),
            onTap: () {
              onLaunchURL('https://play.google.com/store/apps/details?id=in.smstraders.makkalsevaiguide.makkal_sevai_guide', 'rate_app'); // Use the passed callback
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined), // Or Icons.policy
            title: Text(isEnglish ? 'Privacy Policy' : 'தனியுரிமைக் கொள்கை'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onLaunchURL('https://rsiva2294.github.io/makkal-sevai-guide/', 'privacy_policy'); // Use the passed callback
            },
          ),
        ],
      ),
    );
  }
}