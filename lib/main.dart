import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makkal_sevai_guide/firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

// Entry point of the Flutter application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ServiceFinderApp());
}

// A helper class to hold flattened, searchable information about a service.
class ServiceInfo {
  final String departmentName;
  final String departmentNameEn;
  final String serviceName;
  final String serviceNameEn;
  final List<String> eligibility;
  final List<String> eligibilityEn;
  final List<String> documents;
  final List<String> documentsEn;
  final String type; // "Rural" or "Urban"

  ServiceInfo({
    required this.departmentName,
    required this.departmentNameEn,
    required this.serviceName,
    required this.serviceNameEn,
    required this.eligibility,
    required this.eligibilityEn,
    required this.documents,
    required this.documentsEn,
    required this.type,
  });

  // Factory constructor to create a ServiceInfo instance from JSON data.
  factory ServiceInfo.fromJson(Map<String, dynamic> departmentJson, Map<String, dynamic> serviceJson, String type) {
    List<String> parseStringOrList(dynamic field) {
      if (field == null) return [];
      if (field is String && field.isNotEmpty) return [field];
      if (field is List) return field.map((e) => e.toString()).toList();
      return [];
    }

    List<String> safeCast(List<dynamic> list) {
      return list.map((e) => e.toString()).toList();
    }

    return ServiceInfo(
      departmentName: departmentJson['department'] ?? 'N/A',
      departmentNameEn: departmentJson['department_en'] ?? 'N/A',
      serviceName: serviceJson['name'] ?? 'N/A',
      serviceNameEn: serviceJson['name_en'] ?? 'N/A',
      eligibility: parseStringOrList(serviceJson['eligibility']),
      eligibilityEn: parseStringOrList(serviceJson['eligibility_en']),
      documents: serviceJson['documents'] != null ? safeCast(serviceJson['documents']) : [],
      documentsEn: serviceJson['documents_en'] != null ? safeCast(serviceJson['documents_en']) : [],
      type: type,
    );
  }
}

// The root widget of the application, managing the theme.
class ServiceFinderApp extends StatefulWidget {
  const ServiceFinderApp({super.key});

  @override
  State<ServiceFinderApp> createState() => _ServiceFinderAppState();
}

class _ServiceFinderAppState extends State<ServiceFinderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makkal Sevai Guide',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueGrey,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
      ),
      themeMode: _themeMode,
      home: MainScreen(
        onThemeChanged: _toggleTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
    setState(() {
      _isEnglish = !_isEnglish;
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish ? 'Could not open the link.' : 'இணைப்பைத் திறக்க முடியவில்லை.'),
          ),
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
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _launchURL(_campaignUrl),
          label: Text(_isEnglish ? 'Camp Schedule' : 'முகாம் அட்டவணை'),
          icon: const Icon(Icons.public),
          tooltip: _isEnglish ? 'Visit Ungaludan Stalin Camp Schedule' : 'உங்களுடன் ஸ்டாலின் முகாம் அட்டவணையைப் பார்வையிடவும்',
        ),
        body: ServiceFinderScreen(isEnglish: _isEnglish),
      ),
    );
  }
}

// Screen for searching services
class ServiceFinderScreen extends StatefulWidget {
  final bool isEnglish;
  const ServiceFinderScreen({super.key, required this.isEnglish});

  @override
  State<ServiceFinderScreen> createState() => _ServiceFinderScreenState();
}

class _ServiceFinderScreenState extends State<ServiceFinderScreen> {
  bool _isLoading = true;
  final List<ServiceInfo> _allServices = [];
  List<ServiceInfo> _searchResults = [];
  ServiceInfo? _selectedService;
  final TextEditingController _searchController = TextEditingController();

  // Define Firebase Storage paths for your JSON files
  final String _ruralJsonStoragePath = 'json/rural.json';
  final String _urbanJsonStoragePath = 'json/urban.json';

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(() {
      _performSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServiceFinderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnglish != oldWidget.isEnglish) {
      if (_selectedService != null) {
        _searchController.text = widget.isEnglish ? _selectedService!.serviceNameEn : _selectedService!.serviceName;
      }
    }
  }

  Future<void> _loadAllData() async {
    // Set loading state and clear any previous data
    if (mounted) setState(() => _isLoading = true);
    _allServices.clear();

    bool loadedFromFirebase = false;

    // --- Attempt to load from Firebase Storage first ---
    try {
      debugPrint("Attempting to load data from Firebase Storage...");
      final FirebaseStorage storage = FirebaseStorage.instance;

      // Fetch Rural data from Firebase
      final Reference ruralRef = storage.ref(_ruralJsonStoragePath);
      final Uint8List? ruralBytes = await ruralRef.getData(); // Get data as bytes
      if (ruralBytes != null) {
        final String ruralResponse = utf8.decode(ruralBytes); // Decode bytes to string
        final List<dynamic> ruralData = json.decode(ruralResponse); // Parse JSON
        _parseAndAddServices(ruralData, 'Rural');
        debugPrint("Successfully loaded Rural data from Firebase.");
        loadedFromFirebase = true;
      } else {
        debugPrint("Rural data not found on Firebase Storage (bytes were null).");
        loadedFromFirebase = false; // Ensure fallback
      }

      // Fetch Urban data from Firebase
      final Reference urbanRef = storage.ref(_urbanJsonStoragePath);
      final Uint8List? urbanBytes = await urbanRef.getData(); // Get data as bytes
      if (urbanBytes != null) {
        final String urbanResponse = utf8.decode(urbanBytes); // Decode bytes to string
        final List<dynamic> urbanData = json.decode(urbanResponse); // Parse JSON
        _parseAndAddServices(urbanData, 'Urban');
        debugPrint("Successfully loaded Urban data from Firebase.");
        loadedFromFirebase = true; // Still true if rural was successful and urban too
      } else {
        debugPrint("Urban data not found on Firebase Storage (bytes were null).");
        loadedFromFirebase = false; // Ensure fallback if urban fails even if rural succeeded
      }

      if (loadedFromFirebase) {
        // If we reached here and loaded both, then Firebase load was successful.
        debugPrint("All data loaded successfully from Firebase Storage.");
      }

    } catch (firebaseError) {
      debugPrint("Failed to load data from Firebase Storage: $firebaseError. Falling back to assets.");
      loadedFromFirebase = false; // Explicitly set to false to trigger fallback
      _allServices.clear(); // Clear any partial data loaded from Firebase if an error occurred.
    }

    // --- Fallback to loading from local assets if Firebase load failed ---
    if (!loadedFromFirebase || _allServices.isEmpty) { // Check _allServices.isEmpty in case partial load failed gracefully
      try {
        debugPrint("Loading data from local assets (fallback)...");
        final String ruralResponse = await rootBundle.loadString('assets/rural.json');
        final List<dynamic> ruralData = json.decode(ruralResponse);
        _parseAndAddServices(ruralData, 'Rural');
        debugPrint("Successfully loaded Rural data from assets.");

        final String urbanResponse = await rootBundle.loadString('assets/urban.json');
        final List<dynamic> urbanData = json.decode(urbanResponse);
        _parseAndAddServices(urbanData, 'Urban');
        debugPrint("Successfully loaded Urban data from assets.");

      } catch (assetError) {
        debugPrint("Critical Error: Failed to load data from local assets: $assetError");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isEnglish ? 'Failed to load data from any source. Please check your internet or restart the app.' : 'எந்த மூலத்திலிருந்தும் தரவை ஏற்ற முடியவில்லை. உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும் அல்லது பயன்பாட்டை மறுதொடக்கம் செய்யவும்.')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false); // Update UI state
      // Perform an initial search if the search controller has text (e.g., after hot reload)
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }


  void _parseAndAddServices(List<dynamic> data, String type) {
    for (var department in data) {
      if (department['services'] != null) {
        for (var service in department['services']) {
          _allServices.add(ServiceInfo.fromJson(department, service, type));
        }
      }
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = _allServices.where((service) {
      final queryLower = query.toLowerCase();
      return service.serviceName.toLowerCase().contains(queryLower) ||
          service.serviceNameEn.toLowerCase().contains(queryLower);
    }).toList();
    setState(() => _searchResults = results);
  }

  void _onSuggestionTapped(ServiceInfo service) {
    _searchController.text = widget.isEnglish ? service.serviceNameEn : service.serviceName;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedService = service;
      _searchResults = [];
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _selectedService = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruralColor = isDark ? Colors.green.shade800 : Colors.green.shade100;
    final urbanColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: widget.isEnglish ? 'Search for a service' : 'ஒரு சேவையைத் தேடுங்கள்',
                    hintText: widget.isEnglish ? 'e.g., Water Connection' : 'எ.கா., குடிநீர் இணைப்பு',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    children: [
                      if (_selectedService != null && _searchResults.isEmpty)
                        SingleChildScrollView(
                          child: ServiceDetailCard(
                            service: _selectedService!,
                            isEnglish: widget.isEnglish,
                          ),
                        ),
                      if (_searchResults.isNotEmpty)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final service = _searchResults[index];
                              return ListTile(
                                title: Text(widget.isEnglish ? service.serviceNameEn : service.serviceName),
                                subtitle: Text(widget.isEnglish ? service.serviceName : service.serviceNameEn),
                                trailing: Chip(
                                  label: Text(service.type),
                                  backgroundColor: service.type == 'Rural' ? ruralColor : urbanColor,
                                ),
                                onTap: () => _onSuggestionTapped(service),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Navigation Drawer Widget (no changes needed here related to data loading)
class AppDrawer extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool isEnglish;

  const AppDrawer({super.key, required this.onThemeChanged, required this.isEnglish});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _showDisclaimerDialog(BuildContext context) {
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
              onPressed: () => Navigator.of(context).pop(),
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
            ),
            child: Text(
              isEnglish ? 'Makkal Sevai Guide' : 'மக்கள் சேவை வழிகாட்டி',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 24,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(isEnglish ? 'Dark Mode' : 'இருண்ட பயன்முறை'),
            value: isDark,
            onChanged: (bool value) {
              onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);
            },
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          const Divider(),
          // This ListTile opens the DepartmentOverviewScreen (for brochure images)
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
            onTap: () => _launchURL('https://www.linkedin.com/in/sivakaminathan-muthusamy/'),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(isEnglish ? 'Rate this App' : 'செயலியை மதிப்பிடுக'),
            onTap: () {
              _launchURL('https://play.google.com/store/apps/details?id=in.smstraders.makkalsevaiguide');
            },
          ),
        ],
      ),
    );
  }
}

// A widget to display the details of a selected service in a card format.
class ServiceDetailCard extends StatelessWidget {
  final ServiceInfo service;
  final bool isEnglish;

  const ServiceDetailCard({
    super.key,
    required this.service,
    required this.isEnglish,
  });

  List<String> _getDisplayList({
    required List<String> englishList,
    required List<String> tamilList,
    required String noDataEnglish,
    required String noDataTamil,
  }) {
    if (isEnglish) {
      return englishList.isNotEmpty ? englishList : [noDataEnglish];
    } else {
      return tamilList.isNotEmpty ? tamilList : [noDataTamil];
    }
  }

  void _copyToClipboard(BuildContext context) {
    final eligibilityList = _getDisplayList(
      englishList: service.eligibilityEn,
      tamilList: service.eligibility,
      noDataEnglish: 'No specific eligibility criteria listed.',
      noDataTamil: 'குறிப்பிட்ட தகுதி வரம்புகள் எதுவும் பட்டியலிடப்படவில்லை.',
    );

    final documentsList = _getDisplayList(
      englishList: service.documentsEn,
      tamilList: service.documents,
      noDataEnglish: 'No specific documents listed.',
      noDataTamil: 'குறிப்பிட்ட ஆவணங்கள் எதுவும் பட்டியலிடப்படவில்லை.',
    );

    final String textToCopy = """
${isEnglish ? 'Service' : 'சேவை'}: ${isEnglish ? service.serviceNameEn : service.serviceName}
${isEnglish ? 'Department' : 'துறை'}: ${isEnglish ? service.departmentNameEn : service.departmentName}
--------------------
${isEnglish ? 'Eligibility' : 'தகுதி'}:
${eligibilityList.map((e) => '- $e').join('\n')}
--------------------
${isEnglish ? 'Documents Required' : 'தேவையான ஆவணங்கள்'}:
${documentsList.map((e) => '- $e').join('\n')}
""";

    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Copied to clipboard!' : 'கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruralColor = isDark ? Colors.green.shade800 : Colors.green.shade100;
    final urbanColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? service.serviceNameEn : service.serviceName,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isEnglish ? service.serviceName : service.serviceNameEn,
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Copy Details',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(service.type),
              backgroundColor: service.type == 'Rural' ? ruralColor : urbanColor,
              avatar: Icon(service.type == 'Rural' ? Icons.grass : Icons.location_city),
            ),
            const Divider(height: 24),

            _buildDetailSection(
              context,
              icon: Icons.account_balance,
              title: isEnglish ? 'Department' : 'துறை',
              content: [isEnglish ? service.departmentNameEn : service.departmentName],
            ),

            _buildDetailSection(
              context,
              icon: Icons.check_circle_outline,
              title: isEnglish ? 'Eligibility' : 'தகுதி',
              content: _getDisplayList(
                englishList: service.eligibilityEn,
                tamilList: service.eligibility,
                noDataEnglish: 'No specific eligibility criteria listed.',
                noDataTamil: 'குறிப்பிட்ட தகுதி வரம்புகள் எதுவும் பட்டியலிடப்படவில்லை.',
              ),
            ),

            _buildDetailSection(
              context,
              icon: Icons.description_outlined,
              title: isEnglish ? 'Documents Required' : 'தேவையான ஆவணங்கள்',
              content: _getDisplayList(
                englishList: service.documentsEn,
                tamilList: service.documents,
                noDataEnglish: 'No specific documents listed.',
                noDataTamil: 'குறிப்பிட்ட ஆவணங்கள் எதுவும் பட்டியலிடப்படவில்லை.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, {required IconData icon, required String title, required List<String> content}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...content.map((item) => Padding(
            padding: const EdgeInsets.only(left: 28.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(item, style: textTheme.bodyMedium)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class DepartmentOverviewScreen extends StatefulWidget {
  final bool isEnglish;
  const DepartmentOverviewScreen({super.key, required this.isEnglish});

  @override
  State<DepartmentOverviewScreen> createState() => _DepartmentOverviewScreenState();
}

class _DepartmentOverviewScreenState extends State<DepartmentOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _ruralDownloadUrl;
  String? _urbanDownloadUrl;
  bool _isLoadingUrls = true;

  // Define paths to your images in Firebase Storage
  final String _ruralStoragePath = 'brochure/rural.jpg'; // *** Adjust this path ***
  final String _urbanStoragePath = 'brochure/urban.jpg'; // *** Adjust this path ***

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDownloadUrls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadUrls() async {
    try {
      final ruralRef = FirebaseStorage.instance.ref(_ruralStoragePath);
      final urbanRef = FirebaseStorage.instance.ref(_urbanStoragePath);

      _ruralDownloadUrl = await ruralRef.getDownloadURL();
      _urbanDownloadUrl = await urbanRef.getDownloadURL();

      debugPrint("Rural URL: $_ruralDownloadUrl");
      debugPrint("Urban URL: $_urbanDownloadUrl");
    } catch (e) {
      debugPrint("Error loading download URLs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Failed to load brochure images.' : 'பிரசுரப் படங்களை ஏற்ற முடியவில்லை.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUrls = false;
        });
      }
    }
  }

  // New function to launch the URL
  Future<void> _launchImageUrl(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { // Use externalApplication
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Could not open the brochure.' : 'வளையலை திறக்க முடியவில்லை.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEnglish ? 'Download Brochure' : 'வளையலை பதிவிறக்கவும்'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: widget.isEnglish ? 'Rural' : 'கிராமப்புறம்'),
            Tab(text: widget.isEnglish ? 'Urban' : 'நகர்ப்புறம்'),
          ],
        ),
      ),
      body: _isLoadingUrls
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildBrochureView(_ruralDownloadUrl),
          _buildBrochureView(_urbanDownloadUrl),
        ],
      ),
    );
  }

  Widget _buildBrochureView(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Text(
          widget.isEnglish ? 'Brochure not available.' : 'வளையலை கிடைக்கவில்லை.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display the image (optional, you could just have a button)
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    widget.isEnglish ? 'Error loading image preview.' : 'பட முன்னோட்டத்தை ஏற்றும் பிழை.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _launchImageUrl(imageUrl), // Launch URL on button press
              icon: const Icon(Icons.open_in_new), // Changed icon to indicate opening
              label: Text(widget.isEnglish ? 'Open Brochure' : 'வளையலை திறக்க'), // Changed text
            ),
            const SizedBox(height: 10),
            Text(
              widget.isEnglish
                  ? 'Tap "Open Brochure" to view it in your default browser or image viewer.'
                  : 'உங்கள் இயல்புநிலை உலாவி அல்லது பட வியூவரில் காண "வளையலை திறக்க" என்பதைத் தட்டவும்.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}