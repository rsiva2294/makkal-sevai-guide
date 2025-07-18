import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makkal_sevai_guide/model/service_info.dart';
import 'package:makkal_sevai_guide/widget/service_detail_card.dart';

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
        // If rural loaded, assume urban will too or handle urban separately for loadedFromFirebase
        loadedFromFirebase = true;
      } else {
        debugPrint("Rural data not found on Firebase Storage (bytes were null).");
        loadedFromFirebase = false; // Ensure fallback
      }

      // Fetch Urban data from Firebase - only if rural was successful, or attempt anyway
      // To ensure both must load from Firebase to count as 'loadedFromFirebase':
      if (loadedFromFirebase) { // Only try urban from Firebase if rural succeeded
        final Reference urbanRef = storage.ref(_urbanJsonStoragePath);
        final Uint8List? urbanBytes = await urbanRef.getData();
        if (urbanBytes != null) {
          final String urbanResponse = utf8.decode(urbanBytes);
          final List<dynamic> urbanData = json.decode(urbanResponse);
          _parseAndAddServices(urbanData, 'Urban');
          debugPrint("Successfully loaded Urban data from Firebase.");
          // loadedFromFirebase remains true
        } else {
          debugPrint("Urban data not found on Firebase Storage (bytes were null). Falling back.");
          loadedFromFirebase = false; // If urban failed, entire Firebase load fails
        }
      } else {
        debugPrint("Skipping Urban Firebase load as Rural Firebase load failed.");
      }

      if (loadedFromFirebase) {
        debugPrint("All data loaded successfully from Firebase Storage.");
      }

    } catch (firebaseError) {
      debugPrint("Failed to load data from Firebase Storage: $firebaseError. Falling back to assets.");
      loadedFromFirebase = false; // Explicitly set to false to trigger fallback
      _allServices.clear(); // Clear any partial data loaded from Firebase if an error occurred.
    }

    // --- Fallback to loading from local assets if Firebase load failed ---
    // Or if _allServices is still empty after attempting Firebase (e.g., partial load failed and cleared)
    if (!loadedFromFirebase || _allServices.isEmpty) {
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

        // Analytics: Log that data was loaded from fallback
        FirebaseAnalytics.instance.logEvent(
          name: 'data_load_source',
          parameters: {
            'source': 'local_assets',
            'status': 'success',
          },
        );

      } catch (assetError) {
        debugPrint("Critical Error: Failed to load data from local assets: $assetError");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isEnglish ? 'Failed to load data from any source. Please check your internet or restart the app.' : 'எந்த மூலத்திலிருந்தும் தரவை ஏற்ற முடியவில்லை. உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும் அல்லது பயன்பாட்டை மறுதொடக்கம் செய்யவும்.')),
          );
        }
        // Analytics: Log failure from fallback
        FirebaseAnalytics.instance.logEvent(
          name: 'data_load_source',
          parameters: {
            'source': 'local_assets',
            'status': 'failed',
            'error': assetError.toString(),
          },
        );
      }
    } else {
      // Analytics: Log that data was successfully loaded from Firebase
      FirebaseAnalytics.instance.logEvent(
        name: 'data_load_source',
        parameters: {
          'source': 'firebase_storage',
          'status': 'success',
        },
      );
    }

    if (mounted) {
      setState(() => _isLoading = false); // Update UI state
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

    // Analytics for Search Event
    FirebaseAnalytics.instance.logSearch(searchTerm: query);
  }

  void _onSuggestionTapped(ServiceInfo service) {
    _searchController.text = widget.isEnglish ? service.serviceNameEn : service.serviceName;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedService = service;
      _searchResults = [];
    });

    // Analytics for Service Detail View Event
    FirebaseAnalytics.instance.logEvent(
      name: 'service_details_viewed', // Custom event name
      parameters: {
        'service_name_en': service.serviceNameEn, // English service name
        'service_name_ta': service.serviceName,   // Tamil service name
        'department_name_en': service.departmentNameEn, // English department name
        'department_name_ta': service.departmentName,   // Tamil department name
        'service_type': service.type,                  // Rural/Urban
        'current_language_viewed': widget.isEnglish ? 'English' : 'Tamil', // Language of the app at time of view
      },
    );
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